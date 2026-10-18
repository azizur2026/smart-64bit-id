<?php
declare(strict_types=1);

/*
 * SMART64 SQLite 100-worker concurrency acceptance test.
 *
 * Usage:
 *   php tests/stress-allocation-100.php
 *
 * Runs against a fresh temporary SQLite database and journal only.
 * No application database is opened or modified.
 *
 * Acceptance criteria:
 *   - 100 worker processes are ready before the start barrier opens.
 *   - 20 allocations per worker (2,000 total).
 *   - The entire test has a hard 30-second deadline.
 *   - No duplicate Engine+Local coordinates or encoded IDs.
 *   - All Local values 0..1999 exist with no gaps.
 *   - Reopening storage continues at Local 2000.
 */

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';
require_once __DIR__ . '/../src/Allocator.php';

const WORKERS = 100;
const PER_WORKER = 20;
const ENGINE = 424243;
const CLASS_ID = 1;
const ROLE = 0;
const DEADLINE_SECONDS = 30;

function failTest(string $message): never
{
    fwrite(STDERR, "FAIL: {$message}\n");
    exit(1);
}

function elapsed(float $started): float
{
    return microtime(true) - $started;
}

function workerMain(array $argv): never
{
    if (count($argv) !== 7) {
        fwrite(STDERR, "Worker argument count invalid.\n");
        exit(2);
    }

    [, , $db, $journal, $startFile, $readyFile, $count] = $argv;
    $workerStarted = microtime(true);

    try {
        // Signal readiness only after the worker has loaded the allocator code.
        if (file_put_contents($readyFile, (string)getmypid(), LOCK_EX) === false) {
            throw new RuntimeException('Could not write worker ready marker.');
        }

        // All workers wait at the same barrier; parent opens it after all are ready.
        while (!is_file($startFile)) {
            if (elapsed($workerStarted) >= DEADLINE_SECONDS) {
                throw new RuntimeException('Timed out waiting at start barrier.');
            }
            usleep(10000);
        }

        $allocator = new Allocator($db, $journal, false);
        $rows = [];

        for ($i = 0; $i < (int)$count; $i++) {
            $result = $allocator->allocate(ENGINE, CLASS_ID, ROLE);
            $rows[] = [
                'local' => $result['local'],
                'id_hex' => $result['id_hex'],
            ];
        }

        echo json_encode($rows, JSON_THROW_ON_ERROR), "\n";
        exit(0);
    } catch (Throwable $e) {
        fwrite(STDERR, (string)$e . "\n");
        exit(1);
    }
}

if (($argv[1] ?? '') === '--worker') {
    workerMain($argv);
}

if (!function_exists('proc_open') || !function_exists('proc_terminate')) {
    failTest('proc_open/proc_terminate are required.');
}

$root = sys_get_temp_dir() . '/smart64-stress100-' . bin2hex(random_bytes(8));
if (!mkdir($root, 0700)) {
    failTest('Could not create isolated temporary directory.');
}

$db = $root . '/stress.sqlite';
$journal = $root . '/allocation.journal';
$startFile = $root . '/START';
$processes = [];
$started = microtime(true);
$overallOk = false;

try {
    echo "SMART64 SQLite 100-worker concurrency acceptance test\n";
    echo "Workers: " . WORKERS . "\n";
    echo "Allocations per worker: " . PER_WORKER . "\n";
    echo "Expected allocations: " . (WORKERS * PER_WORKER) . "\n";
    echo "Hard overall deadline: " . DEADLINE_SECONDS . " seconds\n";
    echo "Storage: isolated temporary directory\n\n";

    $allocator = new Allocator($db, $journal);
    $allocator->registerEngine(ENGINE);
    unset($allocator);

    // Start every worker and redirect output to files so pipes cannot deadlock.
    for ($i = 0; $i < WORKERS; $i++) {
        if (elapsed($started) >= DEADLINE_SECONDS) {
            throw new RuntimeException('30-second deadline exceeded while launching workers.');
        }

        $readyFile = $root . '/ready-' . $i;
        $stdoutFile = $root . '/stdout-' . $i;
        $stderrFile = $root . '/stderr-' . $i;
        $command = [
            PHP_BINARY,
            __FILE__,
            '--worker',
            $db,
            $journal,
            $startFile,
            $readyFile,
            (string)PER_WORKER,
        ];

        $pipes = [];
        $proc = proc_open(
            $command,
            [
                0 => ['file', '/dev/null', 'r'],
                1 => ['file', $stdoutFile, 'w'],
                2 => ['file', $stderrFile, 'w'],
            ],
            $pipes,
            __DIR__ . '/..'
        );

        if (!is_resource($proc)) {
            throw new RuntimeException("Could not start worker {$i}.");
        }

        $processes[] = [
            'proc' => $proc,
            'ready' => $readyFile,
            'stdout' => $stdoutFile,
            'stderr' => $stderrFile,
            'index' => $i,
            'exit' => null,
        ];
    }

    // Barrier: verify all 100 processes reached readiness before allowing allocations.
    while (true) {
        $readyCount = 0;
        foreach ($processes as $p) {
            if (is_file($p['ready'])) {
                $readyCount++;
            }
        }

        if ($readyCount === WORKERS) {
            break;
        }

        if (elapsed($started) >= DEADLINE_SECONDS) {
            throw new RuntimeException(
                "30-second deadline exceeded waiting for workers; ready={$readyCount}/" . WORKERS
            );
        }

        usleep(10000);
    }

    echo "PASS: all " . WORKERS . " workers reached the start barrier.\n";

    if (elapsed($started) >= DEADLINE_SECONDS) {
        throw new RuntimeException('30-second deadline exceeded before releasing start barrier.');
    }
    if (file_put_contents($startFile, "go\n", LOCK_EX) === false) {
        throw new RuntimeException('Could not release start barrier.');
    }

    // Poll every process without blocking past the global deadline.
    $remaining = WORKERS;
    while ($remaining > 0) {
        foreach ($processes as $index => $p) {
            if ($processes[$index]['exit'] !== null) {
                continue;
            }

            $status = proc_get_status($p['proc']);
            if (!$status['running']) {
                $processes[$index]['exit'] = (int)$status['exitcode'];
                $remaining--;
            }
        }

        if ($remaining === 0) {
            break;
        }

        if (elapsed($started) >= DEADLINE_SECONDS) {
            throw new RuntimeException(
                "30-second hard deadline exceeded; {$remaining} worker(s) still running."
            );
        }

        usleep(10000);
    }

    foreach ($processes as $p) {
        $exit = $p['exit'];
        // Close/reap process. proc_get_status already recorded the exit status.
        proc_close($p['proc']);

        if ($exit !== 0) {
            $stderr = is_file($p['stderr']) ? trim((string)file_get_contents($p['stderr'])) : '';
            throw new RuntimeException(
                "Worker {$p['index']} failed (exit " . var_export($exit, true) . "): {$stderr}"
            );
        }
    }

    $all = [];
    foreach ($processes as $p) {
        $stdout = is_file($p['stdout']) ? (string)file_get_contents($p['stdout']) : '';
        try {
            $rows = json_decode(trim($stdout), true, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable $e) {
            throw new RuntimeException("Worker {$p['index']} produced invalid JSON output.");
        }

        if (!is_array($rows) || count($rows) !== PER_WORKER) {
            throw new RuntimeException("Worker {$p['index']} returned an unexpected allocation count.");
        }

        foreach ($rows as $row) {
            $all[] = $row;
        }
    }

    $expected = WORKERS * PER_WORKER;
    if (count($all) !== $expected) {
        throw new RuntimeException('Total allocation count mismatch.');
    }

    $locals = [];
    $ids = [];
    foreach ($all as $row) {
        if (!isset($row['local'], $row['id_hex'])) {
            throw new RuntimeException('Allocation result missing Local or ID.');
        }

        $local = (string)$row['local'];
        $id = strtoupper((string)$row['id_hex']);

        if (isset($locals[$local])) {
            throw new RuntimeException("Duplicate Engine+Local coordinate: {$local}");
        }
        if (isset($ids[$id])) {
            throw new RuntimeException("Duplicate encoded ID: {$id}");
        }
        if (!preg_match('/^[0-9A-F]{16}$/', $id)) {
            throw new RuntimeException('Encoded ID is not 16 uppercase hexadecimal characters.');
        }

        $decoded = SmartId::decode(hex2bin($id));
        if ($decoded['engine'] !== ENGINE ||
            $decoded['local'] !== (int)$local ||
            $decoded['class'] !== CLASS_ID ||
            $decoded['role'] !== ROLE) {
            throw new RuntimeException('Encoded fields do not match the allocation record.');
        }

        $locals[$local] = true;
        $ids[$id] = true;
    }

    for ($i = 0; $i < $expected; $i++) {
        if (!isset($locals[(string)$i])) {
            throw new RuntimeException("Missing Local value {$i}; allocation sequence has a gap.");
        }
    }

    echo "PASS: all {$expected} allocations returned.\n";
    echo "PASS: no duplicate Engine+Local coordinates.\n";
    echo "PASS: no duplicate encoded IDs.\n";
    echo "PASS: encoded fields match allocation records.\n";
    echo "PASS: Local values 0.." . ($expected - 1) . " are complete and consecutive.\n";

    $reopened = new Allocator($db, $journal);
    $next = $reopened->allocate(ENGINE, CLASS_ID, ROLE);
    unset($reopened);

    if ($next['local'] !== $expected) {
        throw new RuntimeException('Counter did not persist correctly after reopening.');
    }

    $duration = elapsed($started);
    if ($duration > DEADLINE_SECONDS) {
        throw new RuntimeException('Test exceeded the 30-second deadline.');
    }

    echo "PASS: reopening continued at Local {$expected}.\n";
    echo "Elapsed seconds: " . number_format($duration, 3, '.', '') . "\n";
    echo "OVERALL: PASS\n";
    $overallOk = true;
} catch (Throwable $e) {
    fwrite(STDERR, "FAIL: " . $e->getMessage() . "\n");
} finally {
    // Stop any workers still running if setup or the hard deadline failed.
    foreach ($processes as $p) {
        if (is_resource($p['proc'])) {
            $status = proc_get_status($p['proc']);
            if ($status['running']) {
                @proc_terminate($p['proc'], 15);
            }
        }
    }

    // Reap workers after termination.
    foreach ($processes as $p) {
        if (is_resource($p['proc'])) {
            @proc_close($p['proc']);
        }
    }

    foreach (glob($root . '/*') ?: [] as $file) {
        if (is_file($file) || is_link($file)) {
            @unlink($file);
        }
    }
    @rmdir($root);
}

exit($overallOk ? 0 : 1);
