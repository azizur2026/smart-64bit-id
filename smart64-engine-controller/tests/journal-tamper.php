<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';

function checkTamper(bool $ok, string $message): void {
    if (!$ok) {
        fwrite(STDERR, "FAIL: $message\n");
        exit(1);
    }
    echo "PASS: $message\n";
}

$dir = sys_get_temp_dir() . '/smart64-tamper-' . bin2hex(random_bytes(5));

try {
    if (!mkdir($dir, 0700)) {
        throw new RuntimeException('Cannot create test directory.');
    }

    // Case 1: Modify a valid record.
    $path = $dir . '/modified.jsonl';
    $j = new AllocationJournal($path);
    $hex = strtoupper(bin2hex(SmartId::encode(1, 3, 0, 0)));
    $j->reserve(3, 0, 1, 0, $hex);
    unset($j);

    $raw = file_get_contents($path);
    if ($raw === false) throw new RuntimeException('Cannot read test journal.');
    $raw[10] = $raw[10] === 'a' ? 'b' : 'a';
    file_put_contents($path, $raw);

    $j = new AllocationJournal($path);
    try {
        $j->state();
        checkTamper(false, 'modified journal must be rejected');
    } catch (RuntimeException $e) {
        checkTamper(true, 'modified journal rejected');
    }
    unset($j);

    // Case 2: Remove the final newline, simulating a partial final record.
    $path = $dir . '/truncated.jsonl';
    $j = new AllocationJournal($path);
    $j->reserve(4, 0, 1, 0, strtoupper(bin2hex(SmartId::encode(1, 4, 0, 0))));
    unset($j);

    $raw = file_get_contents($path);
    if ($raw === false || $raw === '') throw new RuntimeException('Missing test record.');
    file_put_contents($path, rtrim($raw, "\n"));

    $j = new AllocationJournal($path);
    try {
        $j->state();
        checkTamper(false, 'incomplete final record must be rejected');
    } catch (RuntimeException $e) {
        checkTamper(true, 'incomplete final record rejected');
    }
    unset($j);
} finally {
    foreach (glob($dir . '/*') ?: [] as $file) {
        if (is_file($file)) unlink($file);
    }
    if (is_dir($dir)) rmdir($dir);
}
