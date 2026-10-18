<?php
declare(strict_types=1);
require_once __DIR__ . '/../src/Allocator.php';
function ok(bool $condition, string $message): void { if (!$condition) { fwrite(STDERR, "FAIL: {$message}\n"); exit(1); } echo "PASS: {$message}\n"; }
function byteEvidence(string $label, string $blob): void {
    $path = getenv('SMART64_BYTE_LEDGER');
    if ($path === false || $path === '') return;
    $hex = strtoupper(bin2hex($blob));
    $byteList = implode(' ', array_map(static fn($b) => sprintf('%02X', $b), array_values(unpack('C*', $blob) ?: [])));
    $fields = 'not_decoded';
    $decimal = strlen($blob) === 8 ? SmartId::toDecimal($blob) : 'not_8_bytes';
    try {
        $decoded = SmartId::decode($blob);
        $fields = sprintf('class=%d;engine=%d;local=%d;role=%d;reserved=%d;revision=%d;version=%d', $decoded['class'], $decoded['engine'], $decoded['local'], $decoded['role'], $decoded['reserved'], $decoded['revision'], $decoded['version']);
        $decimal = $decoded['decimal'];
    } catch (Throwable $e) { $fields = 'rejected:' . str_replace(["\t", "\n", "\r"], ' ', $e->getMessage()); }
    file_put_contents($path, implode("\t", [$label, strlen($blob), $hex, $byteList, $decimal, $fields]) . "\n", FILE_APPEND | LOCK_EX);
}
function noByteEvidence(string $label, string $reason): void {
    $path = getenv('SMART64_BYTE_LEDGER');
    if ($path === false || $path === '') return;
    file_put_contents($path, implode("\t", [$label, 'NO_ID_BYTES', '-', '-', '-', $reason]) . "\n", FILE_APPEND | LOCK_EX);
}
function rejects(callable $fn, string $message): void { try { $fn(); } catch (Throwable $e) { echo "PASS: {$message}\n"; return; } fwrite(STDERR, "FAIL: expected rejection: {$message}\n"); exit(1); }
// Pure format tests run even when this machine lacks the PDO SQLite extension.
$sample = SmartId::encode(1, 0, 0, 1);
byteEvidence('format.sample.class1.engine0.local0.role1', $sample);
$decoded = SmartId::decode($sample);
ok($decoded['class'] === 1 && $decoded['engine'] === 0 && $decoded['local'] === 0 && $decoded['role'] === 1, 'field encode/decode round-trip');
ok($decoded['reserved'] === 0 && $decoded['revision'] === 1 && $decoded['version'] === 0, 'v1.41 profile and reserved bits');
ok(strlen($sample) === 8, 'canonical representation is exactly 8 bytes');
$badReserved = hex2bin('0100000000000000');
byteEvidence('invalid_input.nonzero_reserved_bits', $badReserved);
rejects(fn() => SmartId::decode($badReserved), 'nonzero Reserved bits rejected');
$badRevision = hex2bin('1000000000000000');
byteEvidence('invalid_input.unsupported_profile', $badRevision);
rejects(fn() => SmartId::decode($badRevision), 'unsupported profile rejected');
if (!in_array('sqlite', PDO::getAvailableDrivers(), true)) { echo "SKIP: SQLite allocator integration tests (PDO SQLite driver is not installed in this environment).\n"; exit(0); }
$path = sys_get_temp_dir() . '/smart64-test-' . bin2hex(random_bytes(5)) . '.sqlite';
try {
    $a = new Allocator($path); $a->registerEngine(0); $a->registerEngine(1);
    $one = $a->allocate(0, 1, 1); $two = $a->allocate(0, 1, 1); $other = $a->allocate(1, 1, 1);
    foreach ([['allocator.engine0.local0', $one], ['allocator.engine0.local1', $two], ['allocator.engine1.local0', $other]] as [$label, $row]) byteEvidence($label, hex2bin($row['id_hex']));
    ok($one['local'] === 0, 'Local 0 is a valid first allocation');
    ok($two['local'] === 1, 'Local allocation increases monotonically');
    ok($one['id_hex'] !== $two['id_hex'], 'same engine receives distinct IDs');
    ok($one['engine'] === 0 && $other['engine'] === 1 && $one['local'] === $other['local'], 'different engine namespaces may use same Local value');
    ok($one['reserved'] === 0 && $one['version'] === 0 && $one['revision'] === 1, 'profile bits and Reserved bits conform');
    ok(strlen(hex2bin($one['id_hex'])) === 8, 'canonical binary serialization is 8 bytes');
    ok($one['id_decimal'] === SmartId::toDecimal(hex2bin($one['id_hex'])), 'unsigned decimal conversion round-trips from bytes');
    noByteEvidence('rejected_encode.class0', 'Rejected before ID generation: Class 0');
    rejects(fn() => SmartId::encode(0, 0, 0, 1), 'Class 0 rejected');
    noByteEvidence('rejected_encode.class9', 'Rejected before ID generation: reserved future Class');
    rejects(fn() => SmartId::encode(9, 0, 0, 1), 'reserved future Class rejected by this initial profile UI');
    noByteEvidence('rejected_encode.engine_overflow', 'Rejected before ID generation: Engine overflow');
    rejects(fn() => SmartId::encode(1, 2097152, 0, 1), 'Engine overflow rejected');
    noByteEvidence('rejected_encode.local_overflow', 'Rejected before ID generation: Local overflow');
    rejects(fn() => SmartId::encode(1, 0, 536870912, 1), 'Local overflow rejected');
    unset($a); $b = new Allocator($path); $again = $b->allocate(0, 1, 1);
    byteEvidence('allocator.reopened.engine0.local2', hex2bin($again['id_hex']));
    ok($again['local'] === 2, 'Local counter persists after reopening database');
    echo "All tests passed.\n";
} finally { foreach ([$path, $path . '-wal', $path . '-shm'] as $f) if (file_exists($f)) unlink($f); }
