<?php
declare(strict_types=1);

/*
 * SMART64 SQLite 10,000-allocation acceptance test with byte evidence.
 *
 * Run from the project root:
 *   /opt/lampp/bin/php tests/stress-allocation-10k-evidence.php
 *
 * Test design:
 *   - 10,000 allocations, in waves of up to 100 PHP subprocesses
 *   - 30-second timeout per allocation subprocess
 *   - Isolated temporary SQLite database and journal
 *   - Persistent raw stdout/stderr for every worker
 *   - Per-allocation 8-byte ID evidence and SHA-256 hashes
 *   - Source hashes, environment metadata, result summary and manifest
 *
 * Evidence is retained outside the temporary database directory.
 * This is a local SQLite test, not a distributed-safety test.
 */

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';
require_once __DIR__ . '/../src/Allocator.php';

const CONCURRENCY = 100;
const TOTAL_ALLOCATIONS = 10000;
const PROCESS_TIMEOUT = 30.0;
const ENGINE = 424242;
const CLASS_ID = 1;
const ROLE = 0;

function allocateOnce(string $db, string $journal): array
{
    $allocator = new Allocator($db, $journal, false);
    $result = $allocator->allocate(ENGINE, CLASS_ID, ROLE);

    return [
        'local' => $result['local'],
        'id_hex' => strtoupper((string) $result['id_hex']),
    ];
}

/*
 * Child mode must exit before creating any parent evidence directories.
 */
if (($argv[1] ?? '') === '--single') {
    if (count($argv) !== 4) {
        fwrite(STDERR, "Usage: --single DB JOURNAL\n");
        exit(2);
    }

    try {
        echo json_encode(
            allocateOnce($argv[2], $argv[3]),
            JSON_THROW_ON_ERROR
        ), "\n";
        exit(0);
    } catch (Throwable $e) {
        fwrite(STDERR, (string) $e . "\n");
        exit(1);
    }
}

function stopTest(string $message): never
{
    fwrite(STDERR, "FATAL: {$message}\n");
    exit(1);
}

function sha256File(string $path): string
{
    $hash = hash_file('sha256', $path);
    return $hash === false ? 'UNAVAILABLE' : $hash;
}

function writeJson(string $path, array $data): void
{
    $json = json_encode(
        $data,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
    );
    if (file_put_contents($path, $json . "\n", LOCK_EX) === false) {
        throw new RuntimeException("Cannot write {$path}");
    }
}

function launchWorker(
    string $db,
    string $journal,
    string $workerDir,
    int $index
): array {
    $prefix = $workerDir . '/worker-' . sprintf('%05d', $index);
    $stdout = $prefix . '.stdout.bin';
    $stderr = $prefix . '.stderr.bin';

    $proc = proc_open(
        [PHP_BINARY, __FILE__, '--single', $db, $journal],
        [
            0 => ['file', '/dev/null', 'r'],
            1 => ['file', $stdout, 'w'],
            2 => ['file', $stderr, 'w'],
        ],
        $pipes
    );

    if (!is_resource($proc)) {
        throw new RuntimeException("Cannot launch worker {$index}");
    }

    return [
        'proc' => $proc,
        'index' => $index,
        'started' => microtime(true),
        'stdout' => $stdout,
        'stderr' => $stderr,
        'done' => false,
        'timed_out' => false,
        'exit_code' => null,
    ];
}

/* ---------- Persistent evidence setup ---------- */

$home = getenv('HOME') ?: sys_get_temp_dir();
$evidenceParent = rtrim($home, DIRECTORY_SEPARATOR)
    . '/Desktop/SMART64-evidence';

if (!is_dir($evidenceParent)
    && !mkdir($evidenceParent, 0700, true)
    && !is_dir($evidenceParent)) {
    stopTest("Cannot create evidence parent directory: {$evidenceParent}");
}

$evidenceDir = $evidenceParent . '/10k-primary-'
    . gmdate('Ymd\THis\Z') . '-' . bin2hex(random_bytes(4));

if (!mkdir($evidenceDir, 0700)) {
    stopTest("Cannot create evidence directory: {$evidenceDir}");
}
@chmod($evidenceDir, 0700);

$workerDir = $evidenceDir . '/workers';
if (!mkdir($workerDir, 0700)) {
    stopTest('Cannot create worker evidence directory');
}

$scriptPath = realpath(__FILE__) ?: __FILE__;
$scriptHash = sha256File($scriptPath);
$startedUtc = gmdate('Y-m-d\TH:i:s\Z');

$sourceFiles = [
    __DIR__ . '/../src/SmartId.php',
    __DIR__ . '/../src/AllocationJournal.php',
    __DIR__ . '/../src/Allocator.php',
];

$sourceHashes = [];
foreach ($sourceFiles as $source) {
    $real = realpath($source);
    $sourceHashes[$source] = ($real !== false && is_file($real))
        ? sha256File($real)
        : 'MISSING';
}

$sqliteVersion = 'UNAVAILABLE';
if (extension_loaded('pdo_sqlite')) {
    try {
        $pdo = new PDO('sqlite::memory:');
        $sqliteVersion = (string) $pdo->query(
            'SELECT sqlite_version()'
        )->fetchColumn();
        unset($pdo);
    } catch (Throwable $e) {
        $sqliteVersion = 'ERROR: ' . $e->getMessage();
    }
}

$metadata = [
    'test' => 'SMART64 SQLite 10,000-allocation acceptance test',
    'evidence_role' => 'PRIMARY_CONTEMPORANEOUS_TEST_EVIDENCE',
    'started_utc' => $startedUtc,
    'script_path' => $scriptPath,
    'script_sha256' => $scriptHash,
    'php_binary' => PHP_BINARY,
    'php_version' => PHP_VERSION,
    'php_sapi' => PHP_SAPI,
    'os' => php_uname(),
    'pdo_sqlite_loaded' => extension_loaded('pdo_sqlite'),
    'sqlite_version' => $sqliteVersion,
    'concurrency' => CONCURRENCY,
    'requested_allocations' => TOTAL_ALLOCATIONS,
    'per_worker_timeout_seconds' => PROCESS_TIMEOUT,
    'global_deadline' => 'none',
    'engine' => ENGINE,
    'class_id' => CLASS_ID,
    'role' => ROLE,
    'source_sha256' => $sourceHashes,
    'evidence_directory' => $evidenceDir,
];

try {
    writeJson($evidenceDir . '/metadata.json', $metadata);
    if (!copy($scriptPath, $evidenceDir . '/executed-test.php')) {
        throw new RuntimeException('Could not preserve executed PHP source');
    }

    $ledgerPath = $evidenceDir . '/allocation-byte-ledger.tsv';
    $ledger = fopen($ledgerPath, 'xb');
    if ($ledger === false) {
        throw new RuntimeException('Cannot create byte evidence ledger');
    }
    fwrite(
        $ledger,
        "worker_index\tlocal\tid_hex\tid_raw_bytes_hex\t"
        . "byte_length\tid_bytes_sha256\tstdout_sha256\tstderr_sha256\n"
    );
    fclose($ledger);
} catch (Throwable $e) {
    stopTest($e->getMessage());
}

/* ---------- Isolated database setup ---------- */

$tempDir = sys_get_temp_dir() . '/smart64-evidence-test-'
    . bin2hex(random_bytes(8));

if (!mkdir($tempDir, 0700)) {
    stopTest('Cannot create isolated database directory');
}

$db = $tempDir . '/stress.sqlite';
$journal = $tempDir . '/allocation.journal';

$rows = [];
$failures = [];
$timeouts = 0;
$startedAt = microtime(true);
$nextLocal = null;
$reopenError = null;
$fatalError = null;
$passed = false;

echo "SMART64 SQLite 10,000-allocation byte-evidence test\n";
echo "Concurrency: " . CONCURRENCY . "\n";
echo "Allocations: " . TOTAL_ALLOCATIONS . "\n";
echo "Timeout per worker: " . PROCESS_TIMEOUT . " seconds\n";
echo "Evidence directory: {$evidenceDir}\n";
echo "Script SHA-256: {$scriptHash}\n";
echo "SQLite version: {$sqliteVersion}\n\n";

try {
    if (!extension_loaded('pdo_sqlite')) {
        throw new RuntimeException('PDO SQLite extension is unavailable');
    }

    $initializer = new Allocator($db, $journal);
    $initializer->registerEngine(ENGINE);
    unset($initializer);

    /*
     * Keep at most CONCURRENCY subprocesses active.
     * No total-test deadline is imposed.
     */
    for ($base = 0; $base < TOTAL_ALLOCATIONS; $base += CONCURRENCY) {
        $batchSize = min(CONCURRENCY, TOTAL_ALLOCATIONS - $base);
        $batch = [];

        for ($offset = 0; $offset < $batchSize; $offset++) {
            $index = $base + $offset;
            $batch[] = launchWorker($db, $journal, $workerDir, $index);
        }

        $pending = count($batch);

        while ($pending > 0) {
            foreach ($batch as &$worker) {
                if ($worker['done']) {
                    continue;
                }

                $status = proc_get_status($worker['proc']);

                if (!$status['running']) {
                    $worker['done'] = true;
                    $worker['exit_code'] = $status['exitcode'];
                    $pending--;
                    continue;
                }

                if (microtime(true) - $worker['started'] >= PROCESS_TIMEOUT) {
                    $worker['timed_out'] = true;
                    $worker['done'] = true;
                    $worker['exit_code'] = null;

                    @proc_terminate($worker['proc'], 15);
                    usleep(100000);

                    $after = proc_get_status($worker['proc']);
                    if ($after['running']) {
                        @proc_terminate($worker['proc'], 9);
                    }

                    $timeouts++;
                    $pending--;
                }
            }
            unset($worker);

            if ($pending > 0) {
                usleep(10000);
            }
        }

        foreach ($batch as $worker) {
            $closeCode = proc_close($worker['proc']);
            $exitCode = $worker['exit_code'];

            if ($exitCode === null && !$worker['timed_out']) {
                $exitCode = $closeCode;
            }

            $stdout = is_file($worker['stdout'])
                ? (string) file_get_contents($worker['stdout']) : '';
            $stderr = is_file($worker['stderr'])
                ? (string) file_get_contents($worker['stderr']) : '';

            if ($worker['timed_out']) {
                $failures[] = [
                    'worker' => $worker['index'],
                    'reason' => 'TIMEOUT',
                    'stderr' => trim($stderr),
                ];
                continue;
            }

            if ($exitCode !== 0) {
                $failures[] = [
                    'worker' => $worker['index'],
                    'reason' => 'NONZERO_EXIT',
                    'exit_code' => $exitCode,
                    'stdout' => trim($stdout),
                    'stderr' => trim($stderr),
                ];
                continue;
            }

            try {
                $row = json_decode(
                    trim($stdout),
                    true,
                    512,
                    JSON_THROW_ON_ERROR
                );
            } catch (Throwable $e) {
                $failures[] = [
                    'worker' => $worker['index'],
                    'reason' => 'INVALID_JSON',
                    'stdout' => trim($stdout),
                    'stderr' => trim($stderr),
                ];
                continue;
            }

            if (!is_array($row)
                || !array_key_exists('local', $row)
                || !isset($row['id_hex'])) {
                $failures[] = [
                    'worker' => $worker['index'],
                    'reason' => 'MALFORMED_OUTPUT',
                    'stdout' => trim($stdout),
                    'stderr' => trim($stderr),
                ];
                continue;
            }

            $row['_worker_index'] = $worker['index'];
            $row['_stdout_path'] = $worker['stdout'];
            $row['_stderr_path'] = $worker['stderr'];
            $rows[] = $row;
        }

        if ((($base / CONCURRENCY) + 1) % 10 === 0
            || $base + $batchSize === TOTAL_ALLOCATIONS) {
            printf(
                "Progress: %d/%d; valid records=%d; failures=%d; timeouts=%d\n",
                min($base + $batchSize, TOTAL_ALLOCATIONS),
                TOTAL_ALLOCATIONS,
                count($rows),
                count($failures),
                $timeouts
            );
        }
    }

    /* ---------- Validate IDs and build byte ledger ---------- */

    $ids = [];
    $locals = [];
    $duplicateIds = 0;
    $duplicateLocals = 0;
    $formatErrors = 0;
    $decodeErrors = 0;

    $ledger = fopen($ledgerPath, 'ab');
    if ($ledger === false) {
        throw new RuntimeException('Cannot append byte evidence ledger');
    }

    foreach ($rows as $row) {
        $local = (string) $row['local'];
        $idHex = strtoupper((string) $row['id_hex']);

        if (isset($locals[$local])) {
            $duplicateLocals++;
        }
        $locals[$local] = true;

        if (isset($ids[$idHex])) {
            $duplicateIds++;
        }
        $ids[$idHex] = true;

        $rawBytes = false;
        if (preg_match('/^[0-9A-F]{16}$/', $idHex)) {
            $rawBytes = hex2bin($idHex);
        } else {
            $formatErrors++;
        }

        if ($rawBytes === false || strlen($rawBytes) !== 8) {
            $formatErrors++;
            $rawBytes = false;
        } else {
            try {
                $decoded = SmartId::decode($rawBytes);

                if (($decoded['engine'] ?? null) !== ENGINE
                    || ($decoded['local'] ?? null) !== (int) $local
                    || ($decoded['class'] ?? null) !== CLASS_ID
                    || ($decoded['role'] ?? null) !== ROLE) {
                    $decodeErrors++;
                }
            } catch (Throwable $e) {
                $decodeErrors++;
            }
        }

        $stdoutPath = (string) $row['_stdout_path'];
        $stderrPath = (string) $row['_stderr_path'];

        $rawHex = $rawBytes === false ? '' : strtoupper(bin2hex($rawBytes));
        $byteLength = $rawBytes === false ? 0 : strlen($rawBytes);
        $byteHash = $rawBytes === false ? '' : hash('sha256', $rawBytes);

        $record = [
            (string) $row['_worker_index'],
            $local,
            $idHex,
            $rawHex,
            (string) $byteLength,
            $byteHash,
            sha256File($stdoutPath),
            sha256File($stderrPath),
        ];

        fwrite(
            $ledger,
            implode("\t", $record) . "\n"
        );
    }

    fflush($ledger);
    fclose($ledger);

    $missingLocals = 0;
    for ($i = 0; $i < TOTAL_ALLOCATIONS; $i++) {
        if (!isset($locals[(string) $i])) {
            $missingLocals++;
        }
    }

    /* Verify persisted state after reopening the database. */
    try {
        $reopened = new Allocator($db, $journal);
        $next = $reopened->allocate(ENGINE, CLASS_ID, ROLE);
        $nextLocal = (int) $next['local'];
        unset($reopened);
    } catch (Throwable $e) {
        $reopenError = $e->getMessage();
    }

    $duration = microtime(true) - $startedAt;
    $uniqueIds = count($ids);

    $passed = (
        count($rows) === TOTAL_ALLOCATIONS
        && $uniqueIds === TOTAL_ALLOCATIONS
        && $duplicateIds === 0
        && $duplicateLocals === 0
        && $formatErrors === 0
        && $decodeErrors === 0
        && $missingLocals === 0
        && $timeouts === 0
        && $failures === []
        && $nextLocal === TOTAL_ALLOCATIONS
        && $reopenError === null
    );
} catch (Throwable $e) {
    $fatalError = get_class($e) . ': ' . $e->getMessage();
    $passed = false;
}

/* ---------- Persist final primary evidence ---------- */

$duration = microtime(true) - $startedAt;
$summary = [
    'test' => 'SMART64 SQLite 10,000-allocation acceptance test',
    'evidence_role' => 'PRIMARY_CONTEMPORANEOUS_TEST_EVIDENCE',
    'started_utc' => $startedUtc,
    'completed_utc' => gmdate('Y-m-d\TH:i:s\Z'),
    'result' => $passed ? 'PASS' : 'FAIL',
    'requested_allocations' => TOTAL_ALLOCATIONS,
    'concurrency_limit' => CONCURRENCY,
    'per_worker_timeout_seconds' => PROCESS_TIMEOUT,
    'valid_allocation_records' => count($rows),
    'unique_encoded_ids' => isset($uniqueIds) ? $uniqueIds : 0,
    'duplicate_encoded_ids' => $duplicateIds ?? 0,
    'duplicate_engine_local_coordinates' => $duplicateLocals ?? 0,
    'malformed_id_formats' => $formatErrors ?? 0,
    'decoded_field_errors' => $decodeErrors ?? 0,
    'missing_local_values' => $missingLocals ?? TOTAL_ALLOCATIONS,
    'timeouts' => $timeouts,
    'failed_allocations' => count($failures),
    'next_local_after_reopen' => $nextLocal,
    'reopen_error' => $reopenError,
    'fatal_error' => $fatalError,
    'duration_seconds' => round($duration, 2),
    'script_sha256' => $scriptHash,
    'byte_ledger_file' => 'allocation-byte-ledger.tsv',
    'worker_raw_output_directory' => 'workers/',
    'failure_details' => $failures,
    'interpretation' => 'This result applies only to the checks executed here. SHA-256 manifests detect later changes but do not establish an independent trusted timestamp.',
];

try {
    writeJson($evidenceDir . '/final-result.json', $summary);

    $manifestPath = $evidenceDir . '/SHA256SUMS.txt';
    $files = [];

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(
            $evidenceDir,
            FilesystemIterator::SKIP_DOTS
        )
    );

    foreach ($iterator as $info) {
        if (!$info->isFile()) {
            continue;
        }

        $path = $info->getPathname();
        if ($path === $manifestPath
            || $path === $evidenceDir . '/SHA256SUMS.txt.sha256') {
            continue;
        }

        $files[] = $path;
    }

    sort($files, SORT_STRING);
    $manifestLines = [];

    foreach ($files as $path) {
        $manifestLines[] = sha256File($path) . '  '
            . substr($path, strlen($evidenceDir) + 1);
    }

    file_put_contents(
        $manifestPath,
        implode("\n", $manifestLines) . "\n",
        LOCK_EX
    );

    $manifestHash = sha256File($manifestPath);

    file_put_contents(
        $evidenceDir . '/SHA256SUMS.txt.sha256',
        $manifestHash . "  SHA256SUMS.txt\n",
        LOCK_EX
    );
} catch (Throwable $e) {
    $manifestHash = 'MANIFEST_ERROR: ' . $e->getMessage();
    $passed = false;
}

/* Remove only this run's isolated DB and journal, never its evidence. */
foreach (glob($tempDir . '/*') ?: [] as $path) {
    if (is_file($path) || is_link($path)) {
        @unlink($path);
    }
}
@rmdir($tempDir);

echo "\n========== FINAL RESULTS ==========\n";
echo "Result: " . ($passed ? 'PASS' : 'FAIL') . "\n";
echo "Valid allocation records: " . count($rows) . "\n";
echo "Failures: " . count($failures) . "\n";
echo "Timeouts: {$timeouts}\n";
echo "Duration: " . round($duration, 2) . " seconds\n";
echo "Byte ledger: {$ledgerPath}\n";
echo "Evidence directory: {$evidenceDir}\n";
echo "Script SHA-256: {$scriptHash}\n";
echo "Manifest SHA-256: {$manifestHash}\n";
echo "Evidence retained; temporary database removed.\n";

if ($fatalError !== null) {
    echo "Fatal error: {$fatalError}\n";
}
exit($passed ? 0 : 1);
