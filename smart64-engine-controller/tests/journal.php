<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';

function check(bool $ok, string $message): void {
    if (!$ok) { fwrite(STDERR, "FAIL: $message\n"); exit(1); }
    echo "PASS: $message\n";
}

$dir = sys_get_temp_dir() . '/smart64-journal-test-' . bin2hex(random_bytes(5));
$path = $dir . '/journal.jsonl';

try {
    $j = new AllocationJournal($path);
    $hex = strtoupper(bin2hex(SmartId::encode(1, 0, 0, 1)));
    $j->reserve(0, 0, 1, 1, $hex);
    check(($j->state()['next'][0] ?? null) === 1, 'reservation persists high-water mark');

    unset($j);
    $j = new AllocationJournal($path);
    check(($j->state()['records']['0:0'] ?? null) === $hex, 'journal survives reopening');

    file_put_contents($path, "corrupt\n", FILE_APPEND);
    try {
        $j->state();
        check(false, 'corrupt journal must fail closed');
    } catch (RuntimeException $e) {
        check(true, 'corrupt journal fails closed');
    }
} finally {
    foreach (glob($dir . '/*') ?: [] as $file) unlink($file);
    if (is_dir($dir)) rmdir($dir);
}
