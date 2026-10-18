<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';
require_once __DIR__ . '/../src/Allocator.php';

const WORKERS = 8;
const PER_WORKER = 250;
const ENGINE = 424242;
const CLASS_ID = 1;
const ROLE = 0;

function failTest(string $message): never {
    fwrite(STDERR, "FAIL: {$message}\n");
    exit(1);
}

function makeAllocator(string $db, string $journal): Allocator {
    return new Allocator($db, $journal);
}

if (($argv[1] ?? '') === '--worker') {
    [, , $db, $journal, $count] = $argv;

    try {
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

$dir = sys_get_temp_dir() . '/smart64-stress-' . bin2hex(random_bytes(8));

if (!mkdir($dir, 0700)) {
    failTest('Could not create isolated temporary directory.');
}

$db = $dir . '/stress.sqlite';
$journal = $dir . '/allocation.journal';
$processes = [];
$failed = false;

try {
    echo "SMART64 multi-process allocation stress test\n";
    echo "Workers: " . WORKERS . "\n";
    echo "Allocations per worker: " . PER_WORKER . "\n";
    echo "Expected allocations: " . (WORKERS * PER_WORKER) . "\n";
    echo "Storage: isolated temporary directory\n\n";

    // Initialize the temporary database and register the test Engine.
    $allocator = makeAllocator($db, $journal);
    $allocator->registerEngine(ENGINE);
    unset($allocator);

    // Start all workers before collecting results.
    for ($i = 0; $i < WORKERS; $i++) {
        $command = [
            PHP_BINARY,
            __FILE__,
            '--worker',
            $db,
            $journal,
            (string)PER_WORKER,
        ];

        $pipes = [];
        $proc = proc_open(
            $command,
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes
        );

        if (!is_resource($proc)) {
            failTest("Could not start worker {$i}.");
        }

        fclose($pipes[0]);
        $processes[] = [
            'proc' => $proc,
            'stdout' => $pipes[1],
            'stderr' => $pipes[2],
            'index' => $i,
        ];
    }

    $all = [];
    foreach ($processes as $worker) {
        $stdout = stream_get_contents($worker['stdout']);
        $stderr = stream_get_contents($worker['stderr']);
        fclose($worker['stdout']);
        fclose($worker['stderr']);
        $exitCode = proc_close($worker['proc']);

        if ($exitCode !== 0) {
            $failed = true;
            fwrite(
                STDERR,
                "Worker {$worker['index']} failed (exit {$exitCode}): {$stderr}\n"
            );
            continue;
        }

        try {
            $rows = json_decode($stdout, true, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable $e) {
            $failed = true;
            fwrite(STDERR, "Worker output was invalid JSON.\n");
            continue;
        }

        if (!is_array($rows) || count($rows) !== PER_WORKER) {
            $failed = true;
            fwrite(STDERR, "Worker returned an unexpected allocation count.\n");
            continue;
        }

        foreach ($rows as $row) {
            $all[] = $row;
        }
    }

    if ($failed) {
        failTest('One or more worker processes failed.');
    }

    $expected = WORKERS * PER_WORKER;
    if (count($all) !== $expected) {
        failTest('Total allocation count mismatch.');
    }

    $locals = [];
    $ids = [];

    foreach ($all as $row) {
        if (!isset($row['local'], $row['id_hex'])) {
            failTest('Allocation result is missing Local or ID.');
        }

        $local = (string)$row['local'];
        $id = strtoupper((string)$row['id_hex']);

        if (isset($locals[$local])) {
            failTest("Duplicate Engine+Local coordinate: " . $local);
        }
        if (isset($ids[$id])) {
            failTest("Duplicate encoded ID: " . $id);
        }
        if (!preg_match('/^[0-9A-F]{16}$/', $id)) {
            failTest('Encoded ID is not 16 uppercase hexadecimal characters.');
        }

        $decoded = SmartId::decode(hex2bin($id));
        if ($decoded['engine'] !== ENGINE ||
            $decoded['local'] !== (int)$local ||
            $decoded['class'] !== CLASS_ID ||
            $decoded['role'] !== ROLE) {
            failTest('Encoded ID fields do not match the allocation result.');
        }

        $locals[$local] = true;
        $ids[$id] = true;
    }

    for ($i = 0; $i < $expected; $i++) {
        if (!isset($locals[(string)$i])) {
            failTest("Missing Local value {$i}; allocation sequence has a gap.");
        }
    }

    echo "PASS: all {$expected} allocations returned\n";
    echo "PASS: no duplicate Engine+Local coordinates\n";
    echo "PASS: no duplicate encoded IDs\n";
    echo "PASS: all encoded fields match their allocation records\n";
    echo "PASS: Local values are complete and consecutive\n";

    // Reopen storage and confirm the next committed allocation continues.
    $reopened = makeAllocator($db, $journal);
    $next = $reopened->allocate(ENGINE, CLASS_ID, ROLE);

    if ($next['local'] !== $expected) {
        failTest('Counter did not persist correctly after reopening.');
    }

    echo "PASS: reopening storage continued at Local {$expected}\n";
    echo "\nOVERALL: PASS\n";
} catch (Throwable $e) {
    fwrite(STDERR, "FAIL: " . $e->getMessage() . "\n");
    exit(1);
} finally {
    // Only remove this test's isolated temporary files.
    foreach (glob($dir . '/*') ?: [] as $file) {
        if (is_file($file) || is_link($file)) {
            @unlink($file);
        }
    }
    @rmdir($dir);
}
