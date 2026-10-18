#!/usr/bin/env bash
# SMART 64-Bit ID v1.41 test runner for Linux/macOS shells.
# Safe by design: allocator integration tests use temporary databases, not data/smart64.sqlite.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 2

if [[ -n "${SMART64_PHP:-}" ]]; then
  PHP_BIN="$SMART64_PHP"
elif [[ -x /opt/lampp/bin/php ]]; then
  PHP_BIN=/opt/lampp/bin/php
elif command -v php >/dev/null 2>&1; then
  PHP_BIN="$(command -v php)"
else
  echo "ERROR: PHP CLI not found. Set SMART64_PHP to your PHP executable." >&2
  exit 2
fi

mkdir -p reports || { echo "ERROR: Cannot create reports directory." >&2; exit 2; }
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$ROOT/reports/smart64-test-$STAMP.txt"
BYTE_LEDGER="$ROOT/reports/smart64-byte-evidence-$STAMP.tsv"
printf 'test_label\tbyte_length\thex_big_endian\tbytes_spaced\tunsigned_decimal\tdecoded_fields_or_rejection\n' > "$BYTE_LEDGER"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/smart64-test.XXXXXX")" || exit 2
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

{
  echo "SMART 64-Bit ID v1.41 — Test Report"
  echo "Started: $(date -Is 2>/dev/null || date)"
  echo "Project: $ROOT"
  echo "PHP executable: $PHP_BIN"
  echo "Byte evidence ledger: $BYTE_LEDGER"
  echo
} | tee "$REPORT"

run_check() {
  local name="$1"; shift
  local out="$TMP_DIR/check.out"
  echo "===== $name =====" | tee -a "$REPORT"
  "$@" >"$out" 2>&1
  local rc=$?
  cat "$out" | tee -a "$REPORT"
  if [[ $rc -eq 0 ]]; then
    echo "RESULT: PASS — $name" | tee -a "$REPORT"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "RESULT: FAIL (exit $rc) — $name" | tee -a "$REPORT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo | tee -a "$REPORT"
}

run_skip() {
  echo "RESULT: SKIP — $1" | tee -a "$REPORT"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo | tee -a "$REPORT"
}

run_check "PHP CLI version" "$PHP_BIN" -v

required_files=("index.php" "src/SmartId.php" "src/Allocator.php" "tests/run.php" "README.md" "data/.htaccess" ".htaccess")
missing=0
for file in "${required_files[@]}"; do
  if [[ -f "$file" ]]; then echo "FOUND: $file"; else echo "MISSING: $file"; missing=1; fi
done
if [[ $missing -eq 0 ]]; then
  echo "RESULT: PASS — required project files" | tee -a "$REPORT"; PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "RESULT: FAIL — required project files" | tee -a "$REPORT"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo | tee -a "$REPORT"

# Lint every PHP source file in the project, without changing any files.
if find . -type f -name '*.php' -not -path './reports/*' -print -quit | grep -q .; then
  lint_failed=0
  while IFS= read -r -d '' file; do
    output=$("$PHP_BIN" -l "$file" 2>&1) || lint_failed=1
    echo "$output"
  done < <(find . -type f -name '*.php' -not -path './reports/*' -print0 | sort -z) > "$TMP_DIR/lint.out"
  cat "$TMP_DIR/lint.out" | tee -a "$REPORT"
  if [[ $lint_failed -eq 0 ]]; then
    echo "RESULT: PASS — PHP syntax check" | tee -a "$REPORT"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "RESULT: FAIL — PHP syntax check" | tee -a "$REPORT"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo "RESULT: FAIL — no PHP files found" | tee -a "$REPORT"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo | tee -a "$REPORT"

if "$PHP_BIN" -r 'exit(in_array("sqlite", PDO::getAvailableDrivers(), true) ? 0 : 1);'; then
  echo "PDO SQLite driver: available" | tee -a "$REPORT"
else
  echo "PDO SQLite driver: unavailable" | tee -a "$REPORT"
fi
if "$PHP_BIN" -r 'exit(in_array("sqlite", PDO::getAvailableDrivers(), true) ? 0 : 1);'; then
  SMART64_BYTE_LEDGER="$BYTE_LEDGER" run_check "Existing project tests (tests/run.php)" "$PHP_BIN" tests/run.php

  # Extra independent tests: bit boundaries, malformed input, and 10 engines × 100 IDs.
  cat > "$TMP_DIR/extra-tests.php" <<'PHP'
<?php
declare(strict_types=1);
require_once getenv('SMART64_PROJECT_ROOT') . '/src/Allocator.php';
function test(bool $ok, string $label): void { if (!$ok) { fwrite(STDERR, "FAIL: $label\n"); exit(1); } echo "PASS: $label\n"; }
function evidence(string $label, string $blob): void {
  $path = getenv('SMART64_BYTE_LEDGER'); if ($path === false || $path === '') return;
  $hex = strtoupper(bin2hex($blob));
  $bytes = implode(' ', array_map(static fn($b) => sprintf('%02X', $b), array_values(unpack('C*', $blob) ?: [])));
  $decimal = strlen($blob) === 8 ? SmartId::toDecimal($blob) : 'not_8_bytes';
  $fields = 'not_decoded';
  try { $d = SmartId::decode($blob); $decimal = $d['decimal']; $fields = sprintf('class=%d;engine=%d;local=%d;role=%d;reserved=%d;revision=%d;version=%d', $d['class'], $d['engine'], $d['local'], $d['role'], $d['reserved'], $d['revision'], $d['version']); }
  catch (Throwable $e) { $fields = 'rejected:' . str_replace(["\t", "\n", "\r"], ' ', $e->getMessage()); }
  file_put_contents($path, implode("\t", [$label, strlen($blob), $hex, $bytes, $decimal, $fields]) . "\n", FILE_APPEND | LOCK_EX);
}
function noEvidence(string $label, string $reason): void { $path = getenv('SMART64_BYTE_LEDGER'); if ($path !== false && $path !== '') file_put_contents($path, implode("\t", [$label, 'NO_ID_BYTES', '-', '-', '-', $reason]) . "\n", FILE_APPEND | LOCK_EX); }
function mustReject(callable $f, string $label): void { try { $f(); } catch (Throwable $e) { echo "PASS: $label\n"; return; } fwrite(STDERR, "FAIL: expected rejection: $label\n"); exit(1); }
$maxBlob = SmartId::encode(8, SmartId::MAX_ENGINE, SmartId::MAX_LOCAL, 1);
evidence('boundary.maximum_class8_engine_local_role1', $maxBlob);
$max = SmartId::decode($maxBlob);
evidence('invalid_input.short_binary', 'short');
evidence('invalid_input.long_binary', str_repeat("\0", 9));
test($max['class'] === 8 && $max['engine'] === SmartId::MAX_ENGINE && $max['local'] === SmartId::MAX_LOCAL && $max['role'] === 1, 'maximum Engine/Local boundary round-trip');
mustReject(fn() => SmartId::decode("short"), 'binary ID shorter than 8 bytes rejected');
mustReject(fn() => SmartId::decode(str_repeat("\0", 9)), 'binary ID longer than 8 bytes rejected');
noEvidence('rejected_encode.invalid_role2', 'Rejected before ID generation: Role must be 0 or 1');
mustReject(fn() => SmartId::encode(1, 0, 0, 2), 'invalid Role rejected');
$path = sys_get_temp_dir() . '/smart64-stress-' . bin2hex(random_bytes(6)) . '.sqlite';
try {
  $allocator = new Allocator($path);
  for ($e = 0; $e < 10; $e++) $allocator->registerEngine($e);
  $ids = []; $seenLocal = [];
  for ($e = 0; $e < 10; $e++) {
    for ($i = 0; $i < 100; $i++) {
      $row = $allocator->allocate($e, 1, $i % 2);
      if ($row['engine'] !== $e || $row['local'] !== $i) {
        fwrite(STDERR, "FAIL: engine $e expected Local $i; got engine {$row['engine']} Local {$row['local']}\n"); exit(1);
      }
      evidence(sprintf('stress.engine%d.local%d.role%d', $e, $i, $i % 2), hex2bin($row['id_hex']));
      $key = $row['id_hex'];
      if (isset($ids[$key])) { fwrite(STDERR, "FAIL: duplicate ID $key\n"); exit(1); }
      $ids[$key] = true;
      $seenLocal[$e][] = $row['local'];
    }
    test(count($seenLocal[$e]) === 100 && $seenLocal[$e][0] === 0 && $seenLocal[$e][99] === 99, "engine $e allocates Local values 0..99 in order");
  }
  test(count($ids) === 1000, '1,000 allocations have globally unique encoded IDs');
  unset($allocator);
  $reopened = new Allocator($path);
  $next = $reopened->allocate(0, 1, 0);
  evidence('persistence.reopened.engine0.local100.role0', hex2bin($next['id_hex']));
  test($next['local'] === 100, 'allocation counter persists after reopening database');
  unset($reopened);
} finally {
  foreach ([$path, $path . '-wal', $path . '-shm'] as $f) if (is_file($f)) @unlink($f);
}
PHP
  SMART64_PROJECT_ROOT="$ROOT" SMART64_BYTE_LEDGER="$BYTE_LEDGER" run_check "Additional boundary and 1,000-allocation tests" "$PHP_BIN" "$TMP_DIR/extra-tests.php"
  run_check "SQLite metadata integrity and journal recovery" "$PHP_BIN" tests/metadata-integrity.php
  run_check "Allocation journal tests" "$PHP_BIN" tests/journal.php
  run_check "Journal reservation mismatch rejection" "$PHP_BIN" tests/journal-mismatch.php
  run_check "Journal tampering and truncation rejection" "$PHP_BIN" tests/journal-tamper.php
  run_check "SQLite backup-restore recovery" "$PHP_BIN" tests/stale-backup-restore-demo.php
  run_check "Recovery and concurrency tests" "$PHP_BIN" tests/recovery-concurrency.php
else
  run_skip "SQLite-dependent tests (PDO SQLite driver is unavailable)"
fi

# Basic writable-directory check only; no database is created in the app data directory.
if [[ -d data && -w data ]]; then
  echo "RESULT: PASS — data directory exists and is writable (no app database modified)" | tee -a "$REPORT"; PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "RESULT: FAIL — data directory missing or not writable" | tee -a "$REPORT"; FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo | tee -a "$REPORT"

{
  echo "===== SUMMARY ====="
  echo "Passed checks: $PASS_COUNT"
  echo "Failed checks: $FAIL_COUNT"
  echo "Skipped checks: $SKIP_COUNT"
  echo "Finished: $(date -Is 2>/dev/null || date)"
  echo "Report file: $REPORT"
  echo "Byte evidence ledger: $BYTE_LEDGER"
  echo "Byte evidence SHA-256: $(sha256sum "$BYTE_LEDGER" | awk '{print $1}')"
  if [[ $FAIL_COUNT -eq 0 ]]; then echo "Overall: PASS (within the checks actually executed)"; else echo "Overall: FAIL — inspect failures above"; fi
} | tee -a "$REPORT"

echo "Byte evidence ledger: $BYTE_LEDGER"
echo "Byte evidence SHA-256: $(sha256sum "$BYTE_LEDGER" | awk '{print $1}')"

if [[ $FAIL_COUNT -gt 0 ]]; then exit 1; fi
exit 0
