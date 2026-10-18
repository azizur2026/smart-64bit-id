<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/Allocator.php';

$base = sys_get_temp_dir() . '/smart64-meta-' . bin2hex(random_bytes(4));
$db = $base . '.sqlite';
$journal = $base . '.jsonl';

try {
    $a = new Allocator($db, $journal);
    $a->registerEngine(7);
    $id = $a->allocate(7, 1, 0);

    unset($a);

    $pdo = new PDO('sqlite:' . $db);
    $q = $pdo->prepare(
        'UPDATE allocations SET class_id = 2 WHERE engine_no = 7 AND local_id = 0'
    );
    $q->execute();
    unset($pdo);

    try {
        new Allocator($db, $journal);
        echo "FAIL: corrupted metadata was accepted\n";
        exit(1);
    } catch (RuntimeException $e) {
        echo "PASS: corrupted metadata rejected: " . $e->getMessage() . "\n";
    }
} finally {
    foreach ([$db, $db . '-wal', $db . '-shm', $journal] as $file) {
        if (is_file($file)) unlink($file);
    }
}
