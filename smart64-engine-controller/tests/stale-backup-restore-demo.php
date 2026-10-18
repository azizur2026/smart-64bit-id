<?php
declare(strict_types=1);

/*
 * Demonstrates the known SQLite stale-backup limitation.
 * Uses only temporary files; never opens the application's database.
 *
 * This is a limitation demonstration, NOT a passing safety guarantee.
 */

require_once __DIR__ . '/../src/Allocator.php';

$base = sys_get_temp_dir() . '/smart64-restore-' . bin2hex(random_bytes(6));
$db = $base . '.sqlite';
$backup = $base . '.backup.sqlite';
$journal = $db . '.journal';

function removeTestDb(string $path): void
{
    foreach ([$path, $path . '-wal', $path . '-shm'] as $file) {
        if (file_exists($file)) {
            @unlink($file);
        }
    }
}

try {
    $allocator = new Allocator($db);
    $allocator->registerEngine(7);
    $first = $allocator->allocate(7, 1, 1);
    unset($allocator);

    // Snapshot the database after Local 0 has been allocated.
    $pdo = new PDO('sqlite:' . $db, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    $pdo->exec('VACUUM INTO ' . $pdo->quote($backup));
    unset($pdo);

    // Allocate Local 1 after the snapshot.
    $allocator = new Allocator($db);
    $second = $allocator->allocate(7, 1, 1);
    unset($allocator);

    // Simulate restoring the older snapshot with no open connections.
    removeTestDb($db);
    if (!copy($backup, $db)) {
        throw new RuntimeException('Failed to restore temporary backup.');
    }

    $allocator = new Allocator($db);
    $afterRestore = $allocator->allocate(7, 1, 1);
    unset($allocator);

    echo "Initial allocation: Local {$first['local']}" . PHP_EOL;
    echo "Allocation after backup: Local {$second['local']}" . PHP_EOL;
    echo "Allocation after restoring backup: Local {$afterRestore['local']}"
        . PHP_EOL;

    if ($afterRestore['local'] === $second['local'] + 1) {
        echo "PASS: journal recovery prevented Local ID reuse after SQLite restore." . PHP_EOL;
    } else {
        echo "FAIL: unexpected Local value after restore." . PHP_EOL;
        exit(1);
    }
} finally {
    removeTestDb($db);
    removeTestDb($backup);
    removeTestDb($journal);
}
