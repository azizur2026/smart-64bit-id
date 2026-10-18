<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/SmartId.php';
require_once __DIR__ . '/../src/AllocationJournal.php';

$path = sys_get_temp_dir() . '/smart64-mismatch-' . bin2hex(random_bytes(6)) . '.jsonl';

try {
    $journal = new AllocationJournal($path);

    // ID encodes Engine 7, Local 0, Class 1, Role 0.
    $id = SmartId::encode(1, 7, 0, 0);
    $hex = strtoupper(bin2hex($id));

    try {
        // Deliberately claim Engine 8 instead of Engine 7.
        $journal->reserve(8, 0, 1, 0, $hex);
        fwrite(STDERR, "FAIL: mismatched Engine was accepted\n");
        exit(1);
    } catch (RuntimeException $e) {
        echo "PASS: mismatched Engine rejected\n";
    }

    // Rejection must not have consumed Local 0.
    $state = $journal->state();
    if (($state['next'][7] ?? 0) !== 0 || ($state['next'][8] ?? 0) !== 0) {
        fwrite(STDERR, "FAIL: rejected reservation changed journal state\n");
        exit(1);
    }

    echo "PASS: rejected reservation did not alter journal state\n";
} finally {
    if (is_file($path)) unlink($path);
}
