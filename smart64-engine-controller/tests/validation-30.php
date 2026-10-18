<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/Allocator.php';

$base = sys_get_temp_dir() . '/smart64-v30-' . bin2hex(random_bytes(6));
if (!mkdir($base, 0700, true)) {
    fwrite(STDERR, "Cannot create temporary test directory\n");
    exit(2);
}

$passed = 0;
$failed = 0;
$caseNo = 0;

function check(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
}

function fixture(): array {
    global $base;
    static $n = 0;
    $dir = $base . '/case-' . (++$n);
    if (!mkdir($dir, 0700)) throw new RuntimeException('Cannot create fixture.');
    return [
        'dir' => $dir,
        'db' => $dir . '/test.sqlite',
        'journal' => $dir . '/test.jsonl'
    ];
}

function rejects(callable $fn, string $message): void {
    try { $fn(); }
    catch (Throwable $e) { return; }
    throw new RuntimeException($message);
}

function scenario(string $name, callable $fn): void {
    global $passed, $failed, $caseNo;
    $caseNo++;
    try {
        $fn();
        $passed++;
        echo sprintf("%02d PASS  %s\n", $caseNo, $name);
    } catch (Throwable $e) {
        $failed++;
        echo sprintf("%02d FAIL  %s — %s\n", $caseNo, $name, $e->getMessage());
    }
}

/* 01 */
scenario('Canonical ID is exactly eight bytes', function () {
    check(strlen(SmartId::encode(1, 0, 0, 0)) === 8, 'Length is not 8.');
});

/* 02 */
scenario('Canonical network byte order matches fixed vector', function () {
    check(strtoupper(bin2hex(SmartId::encode(1, 0, 0, 0))) === '0804000000000000',
        'Fixed vector mismatch.');
});

/* 03 */
scenario('Local zero is valid and round-trips', function () {
    $d = SmartId::decode(SmartId::encode(1, 0, 0, 0));
    check($d['local'] === 0, 'Local zero did not round-trip.');
});

/* 04 */
scenario('Engine zero is valid and round-trips', function () {
    $d = SmartId::decode(SmartId::encode(1, 0, 0, 0));
    check($d['engine'] === 0, 'Engine zero did not round-trip.');
});

/* 05 */
scenario('Maximum Engine and Local values round-trip', function () {
    $d = SmartId::decode(SmartId::encode(8, SmartId::MAX_ENGINE, SmartId::MAX_LOCAL, 1));
    check($d['engine'] === SmartId::MAX_ENGINE, 'Maximum Engine mismatch.');
    check($d['local'] === SmartId::MAX_LOCAL, 'Maximum Local mismatch.');
    check($d['class'] === 8 && $d['role'] === 1, 'Other fields mismatch.');
});

/* 06 */
scenario('All eight currently supported classes round-trip', function () {
    for ($c = 1; $c <= 8; $c++) {
        check(SmartId::decode(SmartId::encode($c, 3, 7, 0))['class'] === $c,
            "Class $c mismatch.");
    }
});

/* 07 */
scenario('Both Role values round-trip', function () {
    foreach ([0, 1] as $r) {
        check(SmartId::decode(SmartId::encode(1, 2, 3, $r))['role'] === $r,
            "Role $r mismatch.");
    }
});

/* 08 */
scenario('Class zero is rejected', function () {
    rejects(fn() => SmartId::encode(0, 0, 0, 0), 'Class zero accepted.');
});

/* 09 */
scenario('Reserved Class nine is rejected', function () {
    rejects(fn() => SmartId::encode(9, 0, 0, 0), 'Class nine accepted.');
});

/* 10 */
scenario('Negative Engine is rejected', function () {
    rejects(fn() => SmartId::encode(1, -1, 0, 0), 'Negative Engine accepted.');
});

/* 11 */
scenario('Engine above maximum is rejected', function () {
    rejects(fn() => SmartId::encode(1, SmartId::MAX_ENGINE + 1, 0, 0), 'Engine overflow accepted.');
});

/* 12 */
scenario('Negative Local is rejected', function () {
    rejects(fn() => SmartId::encode(1, 0, -1, 0), 'Negative Local accepted.');
});

/* 13 */
scenario('Local above maximum is rejected', function () {
    rejects(fn() => SmartId::encode(1, 0, SmartId::MAX_LOCAL + 1, 0), 'Local overflow accepted.');
});

/* 14 */
scenario('Invalid Role is rejected', function () {
    rejects(fn() => SmartId::encode(1, 0, 0, 2), 'Role two accepted.');
});

/* 15 */
scenario('Short binary ID is rejected', function () {
    rejects(fn() => SmartId::decode('short'), 'Short ID accepted.');
});

/* 16 */
scenario('Long binary ID is rejected', function () {
    rejects(fn() => SmartId::decode(str_repeat("\0", 9)), 'Long ID accepted.');
});

/* 17 */
scenario('Unsupported revision is rejected', function () {
    $b = SmartId::encode(1, 0, 0, 0);
    $b[0] = chr(ord($b[0]) | 0x10);
    rejects(fn() => SmartId::decode($b), 'Unsupported revision accepted.');
});

/* 18 */
scenario('Version bit for v2+ is rejected by v1.41 decoder', function () {
    $b = SmartId::encode(1, 0, 0, 0);
    $b[0] = chr(ord($b[0]) | 0x80);
    rejects(fn() => SmartId::decode($b), 'Version 1 accepted.');
});

/* 19 */
scenario('Nonzero reserved bit is rejected', function () {
    $b = SmartId::encode(1, 0, 0, 0);
    $b[1] = chr(ord($b[1]) | 0x40);
    rejects(fn() => SmartId::decode($b), 'Reserved bit accepted.');
});

/* 20 */
scenario('Unsigned decimal conversion handles all 64 one-bits', function () {
    check(SmartId::toDecimal(str_repeat("\xFF", 8)) === '18446744073709551615',
        'Unsigned maximum decimal mismatch.');
});

/* 21 */
scenario('Same fields always produce the same bytes', function () {
    $a = SmartId::encode(4, 123, 456, 1);
    $b = SmartId::encode(4, 123, 456, 1);
    check(hash_equals($a, $b), 'Encoding is not deterministic.');
});

/* 22 */
scenario('Registering an Engine twice is idempotent', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(0);
    $a->registerEngine(0);
    check(count(array_filter($a->listEngines(),
        fn($e) => (int)$e['engine_no'] === 0)) === 1, 'Duplicate Engine row.');
});

/* 23 */
scenario('Allocation from an unregistered Engine is rejected', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    rejects(fn() => $a->allocate(7, 1, 0), 'Unregistered Engine allocated.');
});

/* 24 */
scenario('First allocation for a registered Engine uses Local zero', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(0);
    check($a->allocate(0, 1, 0)['local'] === 0, 'First Local was not zero.');
});

/* 25 */
scenario('Sequential allocations increment Local exactly once', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(4);
    for ($i = 0; $i < 20; $i++) {
        check($a->allocate(4, 1, 0)['local'] === $i, "Wrong Local at $i.");
    }
});

/* 26 */
scenario('Different Engines have independent Local counters', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(1);
    $a->registerEngine(2);
    $x = $a->allocate(1, 1, 0);
    $y = $a->allocate(2, 1, 0);
    check($x['local'] === 0 && $y['local'] === 0, 'Counters are not independent.');
    check($x['id_hex'] !== $y['id_hex'], 'Encoded IDs unexpectedly match.');
});

/* 27 */
scenario('Same Engine+Local cannot be reserved again under another Class', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(9);
    $a->allocate(9, 1, 0);

    $duplicateIdHex = strtoupper(bin2hex(SmartId::encode(2, 9, 0, 0)));
    rejects(
        fn() => (new AllocationJournal($f['journal']))
            ->reserve(9, 0, 2, 0, $duplicateIdHex),
        'Duplicate Engine+Local coordinate was accepted.'
    );
});

/* 28 */
scenario('Allocation counter survives reopening the database', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(0);
    $a->allocate(0, 1, 0);
    unset($a);
    $b = new Allocator($f['db'], $f['journal']);
    check($b->allocate(0, 1, 0)['local'] === 1, 'Counter did not persist.');
});

/* 29 */
scenario('Journal record alteration is detected', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(0);
    $a->allocate(0, 1, 0);
    unset($a);
    $raw = file_get_contents($f['journal']);
    if ($raw === false) throw new RuntimeException('Cannot read test journal.');
    $changed = str_replace('"class":1', '"class":2', $raw, $count);
    check($count > 0, 'Expected journal field not found for alteration.');
    file_put_contents($f['journal'], $changed);
    rejects(fn() => (new AllocationJournal($f['journal']))->state(),
        'Altered journal was accepted.');
});

/* 30 */
scenario('Incomplete final journal record is rejected', function () {
    $f = fixture();
    $a = new Allocator($f['db'], $f['journal']);
    $a->registerEngine(0);
    $a->allocate(0, 1, 0);
    unset($a);
    file_put_contents($f['journal'], '{', FILE_APPEND);
    rejects(fn() => (new AllocationJournal($f['journal']))->state(),
        'Incomplete journal record was accepted.');
});

echo "\n30-SCENARIO SUMMARY\n";
echo "Passed: $passed\nFailed: $failed\n";
echo "Scope: executable checks above only; see existing regression batch for recovery/concurrency tests.\n";

/* Clean only this script's temporary fixtures. */
$it = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS),
    RecursiveIteratorIterator::CHILD_FIRST
);
foreach ($it as $item) {
    if ($item->isDir()) @rmdir($item->getPathname());
    else @unlink($item->getPathname());
}
@rmdir($base);

exit($failed === 0 && $caseNo === 30 ? 0 : 1);
