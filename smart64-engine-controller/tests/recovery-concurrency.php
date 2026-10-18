<?php
declare(strict_types=1);

/*
 * Process-level SQLite regression tests.
 * Uses a unique temporary database and removes its own test artifacts.
 * Does not modify the application's configured database or byte ledger.
 */

require_once __DIR__ . '/../src/Allocator.php';

function verify(bool $condition, string $message): void {
    if (!$condition) {
        throw new RuntimeException("FAIL: " . $message);
    }
    echo "PASS: " . $message . PHP_EOL;
}

function removeArtifacts(string $base): void {
    foreach (glob($base . '*') ?: [] as $file) {
        if (is_file($file)) {
            @unlink($file);
        }
    }
}

if (!extension_loaded('pcntl') || !extension_loaded('posix')) {
    fwrite(STDERR, "SKIP: pcntl and posix are required.\n");
    exit(2);
}

$base = sys_get_temp_dir() . '/smart64-regression-' . bin2hex(random_bytes(6));
$dbPath = $base . '.sqlite';
$marker = $base . '.marker';
$workerCount = 4;
$perWorker = 50;
$children = [];

try {
    // Create a fresh test database.
    $allocator = new Allocator($dbPath);
    $allocator->registerEngine(7);
    unset($allocator);

    // Crash recovery: kill a process with an uncommitted counter update.
    $pid = pcntl_fork();
    if ($pid === -1) {
        throw new RuntimeException('Could not start crash-recovery child.');
    }

    if ($pid === 0) {
        try {
            $pdo = new PDO('sqlite:' . $dbPath, null, null, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
            ]);
            $pdo->exec('PRAGMA busy_timeout = 5000');
            $pdo->exec('PRAGMA journal_mode = WAL');
            $pdo->exec('PRAGMA synchronous = FULL');
            $pdo->exec('BEGIN IMMEDIATE');
            $pdo->exec('UPDATE engines SET next_local = 777 WHERE engine_no = 7');
            file_put_contents($marker, 'ready');
            while (true) {
                usleep(10000);
            }
        } catch (Throwable $e) {
            fwrite(STDERR, $e->getMessage() . PHP_EOL);
            exit(3);
        }
    }

    $deadline = microtime(true) + 10;
    while (!file_exists($marker) && microtime(true) < $deadline) {
        usleep(10000);
    }

    if (!file_exists($marker)) {
        posix_kill($pid, SIGKILL);
        pcntl_waitpid($pid, $status);
        throw new RuntimeException('Crash child did not reach its transaction.');
    }

    posix_kill($pid, SIGKILL);
    pcntl_waitpid($pid, $status);

    $allocator = new Allocator($dbPath);
    $first = $allocator->allocate(7, 1, 1);
    verify(
        $first['local'] === 0,
        'Uncommitted counter update is rolled back after process termination'
    );
    unset($allocator);

    // Four independent workers allocate against the same Engine.
    for ($w = 0; $w < $workerCount; $w++) {
        $out = $base . '.worker' . $w;
        $pid = pcntl_fork();

        if ($pid === -1) {
            throw new RuntimeException('Could not start allocation worker.');
        }

        if ($pid === 0) {
            try {
                $worker = new Allocator($dbPath);
                $locals = [];

                for ($i = 0; $i < $perWorker; $i++) {
                    $row = $worker->allocate(7, 1, 1);
                    $locals[] = $row['local'];
                }

                file_put_contents($out, implode("\n", $locals) . "\n");
                exit(0);
            } catch (Throwable $e) {
                file_put_contents($out . '.error', $e->__toString());
                exit(4);
            }
        }

        $children[] = [$pid, $out];
    }

    $workersOk = true;

    foreach ($children as [$pid, $out]) {
        pcntl_waitpid($pid, $status);

        if (!pcntl_wifexited($status) || pcntl_wexitstatus($status) !== 0) {
            $workersOk = false;
            if (file_exists($out . '.error')) {
                fwrite(STDERR, file_get_contents($out . '.error') . PHP_EOL);
            }
        }
    }

    verify($workersOk, 'All concurrent allocation workers completed');

    $locals = [];

    foreach ($children as [$pid, $out]) {
        if (!is_file($out)) {
            throw new RuntimeException("Missing worker result: $out");
        }

        foreach (file($out, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            if (!ctype_digit($line)) {
                throw new RuntimeException('Worker returned an invalid Local value.');
            }
            $locals[] = (int)$line;
        }
    }

    $expectedCount = $workerCount * $perWorker;

    verify(
        count($locals) === $expectedCount,
        "All $expectedCount concurrent allocations were recorded"
    );

    verify(
        count(array_unique($locals)) === $expectedCount,
        'Concurrent allocations contain no duplicate Local values'
    );

    sort($locals, SORT_NUMERIC);
    verify(
        $locals === range(1, $expectedCount),
        'Concurrent Local values are complete and consecutive'
    );

    $final = new Allocator($dbPath);
    $engineRow = null;

    foreach ($final->listEngines() as $row) {
        if ((int)$row['engine_no'] === 7) {
            $engineRow = $row;
            break;
        }
    }

    verify($engineRow !== null, 'Engine registration persists');

    verify(
        (int)$engineRow['next_local'] === $expectedCount + 1,
        'Persisted counter matches all committed allocations'
    );

    unset($final);

    echo PHP_EOL . "RESULT: All recovery/concurrency regression tests passed.\n";
    echo "LIMITATION: This does not test stale-backup restoration or distributed fencing.\n";

} catch (Throwable $e) {
    fwrite(STDERR, "ERROR: " . $e->getMessage() . PHP_EOL);
    exit(1);
} finally {
    foreach ($children as [$pid, $out]) {
        @posix_kill($pid, SIGKILL);
        @pcntl_waitpid($pid, $status, WNOHANG);
    }
    removeArtifacts($base);
}
