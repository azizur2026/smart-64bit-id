<?php
declare(strict_types=1);

/*
 * SMART64 SQLite high-concurrency acceptance test.
 *
 * Parent launches up to 100 single-allocation PHP subprocesses concurrently.
 * Each allocation subprocess has its own 30-second timeout; the complete test
 * has no 30-second global deadline.
 *
 * This test uses only a fresh temporary database and journal.
 */

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';
require_once __DIR__ . '/../src/Allocator.php';

const CONCURRENCY = 100;
const TOTAL_ALLOCATIONS = 10000;
const PER_PROCESS_TIMEOUT_SECONDS = 30.0;
const ENGINE = 424242;
const CLASS_ID = 1;
const ROLE = 0;

function failTest(string $message): never {
    fwrite(STDERR, "FAIL: {$message}\n");
    exit(1);
}

/** @return array{local:int|string,id_hex:string} */
function allocateOnce(string $db, string $journal): array {
    $allocator = new Allocator($db, $journal, false);
    $result = $allocator->allocate(ENGINE, CLASS_ID, ROLE);
    return [
        'local' => $result['local'],
        'id_hex' => strtoupper((string)$result['id_hex']),
    ];
}

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
        fwrite(STDERR, (string)$e . "\n");
        exit(1);
    }
}

function launchAllocation(string $db, string $journal, string $dir, int $index): array {
    $stdoutPath = $dir . '/worker-' . $index . '.out';
    $stderrPath = $dir . '/worker-' . $index . '.err';
    $command = [PHP_BINARY, __FILE__, '--single', $db, $journal];

    $proc = proc_open(
        $command,
        [
            0 => ['file', '/dev/null', 'r'],
            1 => ['file', $stdoutPath, 'w'],
            2 => ['file', $stderrPath, 'w'],
        ],
        $pipes
    );

    if (!is_resource($proc)) {
        throw new RuntimeException("Could not launch allocation subprocess {$index}");
    }

    return [
        'proc' => $proc,
        'index' => $index,
        'started' => microtime(true),
        'stdout' => $stdoutPath,
        'stderr' => $stderrPath,
        'done' => false,
        'exit_code' => null,
        'timed_out' => false,
    ];
}

$dir = sys_get_temp_dir() . '/smart64-10k-' . bin2hex(random_bytes(8));
if (!mkdir($dir, 0700)) {
    failTest('Could not create isolated temporary directory.');
}

$db = $dir . '/stress.sqlite';
$journal = $dir . '/allocation.journal';
$allRows = [];
$failures = [];
$timeouts = 0;
$completed = 0;
$startedAt = microtime(true);

try {
    echo "SMART64 SQLite high-concurrency acceptance test\n";
    echo "Concurrent allocation subprocesses: " . CONCURRENCY . "\n";
    echo "Total allocations requested: " . TOTAL_ALLOCATIONS . "\n";
    echo "Timeout per allocation subprocess: " . PER_PROCESS_TIMEOUT_SECONDS . " seconds\n";
    echo "Global test deadline: none\n";
    echo "Storage: isolated temporary directory\n";
    echo "Fresh database before initialization: " . (!file_exists($db) ? 'yes' : 'no') . "\n\n";

    $initializer = new Allocator($db, $journal);
    $initializer->registerEngine(ENGINE);
    unset($initializer);

    // Run in waves to cap simultaneous child processes at exactly 100.
    for ($base = 0; $base < TOTAL_ALLOCATIONS; $base += CONCURRENCY) {
        $batchSize = min(CONCURRENCY, TOTAL_ALLOCATIONS - $base);
        $batch = [];

        for ($offset = 0; $offset < $batchSize; $offset++) {
            $index = $base + $offset;
            $batch[] = launchAllocation($db, $journal, $dir, $index);
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

                if (microtime(true) - $worker['started'] >= PER_PROCESS_TIMEOUT_SECONDS) {
                    $worker['timed_out'] = true;
                    $worker['done'] = true;
                    $worker['exit_code'] = null;
                    @proc_terminate($worker['proc'], 15);
                    usleep(100000);
                    $statusAfterTerm = proc_get_status($worker['proc']);
                    if ($statusAfterTerm['running']) {
                        @proc_terminate($worker['proc'], 9);
                    }
                    $pending--;
                    $timeouts++;
                }
            }
            unset($worker);

            if ($pending > 0) {
                usleep(10000);
            }
        }

        foreach ($batch as $worker) {
            // Reap each process. proc_close may return -1 after proc_get_status
            // has already collected the exit code, so prefer the captured code.
            $closeCode = proc_close($worker['proc']);
            $exitCode = $worker['exit_code'];
            if ($exitCode === null && !$worker['timed_out']) {
                $exitCode = $closeCode;
            }

            $stdout = is_file($worker['stdout']) ? trim((string)file_get_contents($worker['stdout'])) : '';
            $stderr = is_file($worker['stderr']) ? trim((string)file_get_contents($worker['stderr'])) : '';

            if ($worker['timed_out']) {
                $failures[] = "Allocation {$worker['index']} timed out after " .
                    PER_PROCESS_TIMEOUT_SECONDS . " seconds. stderr=" . $stderr;
                continue;
            }

            if ($exitCode !== 0) {
                $failures[] = "Allocation {$worker['index']} exited with code " .
                    var_export($exitCode, true) . ". stderr=" . $stderr . "; stdout=" . $stdout;
                continue;
            }

            try {
                $row = json_decode($stdout, true, 512, JSON_THROW_ON_ERROR);
            } catch (Throwable $e) {
                $failures[] = "Allocation {$worker['index']} returned invalid JSON: " .
                    substr($stdout, 0, 500);
                continue;
            }

            if (!is_array($row) || !array_key_exists('local', $row) || !isset($row['id_hex'])) {
                $failures[] = "Allocation {$worker['index']} returned malformed output.";
                continue;
            }

            $allRows[] = $row;
            $completed++;
        }

        if ((($base / CONCURRENCY) + 1) % 10 === 0 || $base + $batchSize === TOTAL_ALLOCATIONS) {
            printf(
                "Progress: %d/%d subprocesses completed; failures=%d; timeouts=%d\n",
                min($base + $batchSize, TOTAL_ALLOCATIONS),
                TOTAL_ALLOCATIONS,
                count($failures),
                $timeouts
            );
        }
    }

    $ids = [];
    $locals = [];
    $duplicateIds = 0;
    $duplicateLocals = 0;
    $formatErrors = 0;
    $decodeErrors = 0;

    foreach ($allRows as $row) {
        $local = (string)$row['local'];
        $id = strtoupper((string)$row['id_hex']);

        if (isset($locals[$local])) {
            $duplicateLocals++;
        }
        $locals[$local] = true;

        if (isset($ids[$id])) {
            $duplicateIds++;
        }
        $ids[$id] = true;

        if (!preg_match('/^[0-9A-F]{16}$/', $id)) {
            $formatErrors++;
            continue;
        }

        $binary = hex2bin($id);
        if ($binary === false) {
            $decodeErrors++;
            continue;
        }

        try {
            $decoded = SmartId::decode($binary);
            if (($decoded['engine'] ?? null) !== ENGINE ||
                ($decoded['local'] ?? null) !== (int)$local ||
                ($decoded['class'] ?? null) !== CLASS_ID ||
                ($decoded['role'] ?? null) !== ROLE) {
                $decodeErrors++;
            }
        } catch (Throwable $e) {
            $decodeErrors++;
        }
    }

    $missingLocals = 0;
    for ($i = 0; $i < TOTAL_ALLOCATIONS; $i++) {
        if (!isset($locals[(string)$i])) {
            $missingLocals++;
        }
    }

    $nextLocal = null;
    $reopenError = null;
    try {
        $reopened = new Allocator($db, $journal);
        $next = $reopened->allocate(ENGINE, CLASS_ID, ROLE);
        $nextLocal = (int)$next['local'];
    } catch (Throwable $e) {
        $reopenError = $e->getMessage();
    }

    $duration = microtime(true) - $startedAt;
    $uniqueIds = count($ids);
    $expectedNext = TOTAL_ALLOCATIONS;

    echo "\n=== FINAL 10K TEST RESULTS ===\n";
    echo "Requested allocations: " . TOTAL_ALLOCATIONS . "\n";
    echo "Successful subprocesses: {$completed}\n";
    echo "Valid allocation records: " . count($allRows) . "\n";
    echo "Unique encoded IDs: {$uniqueIds}\n";
    echo "Duplicate encoded IDs: {$duplicateIds}\n";
    echo "Duplicate Engine+Local coordinates: {$duplicateLocals}\n";
    echo "Malformed ID formats: {$formatErrors}\n";
    echo "Decoded-field mismatches/errors: {$decodeErrors}\n";
    echo "Missing Local values in 0.." . (TOTAL_ALLOCATIONS - 1) . ": {$missingLocals}\n";
    echo "Subprocess timeouts: {$timeouts}\n";
    echo "Failed allocations: " . count($failures) . "\n";
    echo "Next Local after reopening: " . ($nextLocal === null ? 'unavailable' : $nextLocal) . "\n";
    if ($reopenError !== null) {
        echo "Reopen error: {$reopenError}\n";
    }
    echo "Duration: " . round($duration, 2) . " seconds\n";
    echo "Successful allocation throughput: " . round($completed / max($duration, 0.001), 2) . " allocations/sec\n";

    if ($failures !== []) {
        echo "\n=== FIRST FAILURE DETAILS (up to 20) ===\n";
        foreach (array_slice($failures, 0, 20) as $failure) {
            echo "FAILURE: {$failure}\n";
        }
    }

    $passed = (
        $completed === TOTAL_ALLOCATIONS &&
        count($allRows) === TOTAL_ALLOCATIONS &&
        $uniqueIds === TOTAL_ALLOCATIONS &&
        $duplicateIds === 0 &&
        $duplicateLocals === 0 &&
        $formatErrors === 0 &&
        $decodeErrors === 0 &&
        $missingLocals === 0 &&
        $timeouts === 0 &&
        $failures === [] &&
        $nextLocal === $expectedNext
    );

    echo "\nTest database was isolated and will be removed after this run.\n";
    echo "RESULT: " . ($passed ? 'PASS' : 'FAIL') . "\n";

    if (!$passed) {
        exit(1);
    }
} catch (Throwable $e) {
    fwrite(STDERR, "FAIL: " . $e->getMessage() . "\n");
    exit(1);
} finally {
    // Remove only this script's isolated temporary files.
    foreach (glob($dir . '/*') ?: [] as $file) {
        if (is_file($file) || is_link($file)) {
            @unlink($file);
        }
    }
    @rmdir($dir);
}
