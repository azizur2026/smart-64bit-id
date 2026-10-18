#!/usr/bin/env bash
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
  echo "ERROR: PHP CLI not found." >&2
  exit 2
fi

mkdir -p reports || exit 2
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$ROOT/reports/smart64-validation-30-$STAMP.txt"
MANIFEST="$ROOT/reports/smart64-validation-30-manifest-$STAMP.txt"

{
  echo "SMART64 — 30-scenario validation batch"
  echo "Started: $(date -Is 2>/dev/null || date)"
  echo "Project: $ROOT"
  echo "PHP: $PHP_BIN"
  echo
  echo "===== NEW 30-SCENARIO SUITE ====="
  "$PHP_BIN" tests/validation-30.php
  SUITE_RC=$?
  echo
  echo "===== EXISTING REGRESSION SUITE ====="
  ./smart64-engine-controller-test-all.sh
  REGRESSION_RC=$?
  echo
  echo "===== BATCH SUMMARY ====="
  echo "30-scenario suite exit code: $SUITE_RC"
  echo "Existing regression suite exit code: $REGRESSION_RC"
  echo "Finished: $(date -Is 2>/dev/null || date)"
  if [[ $SUITE_RC -eq 0 && $REGRESSION_RC -eq 0 ]]; then
    echo "Overall: PASS — all invoked suites exited successfully."
    BATCH_RC=0
  else
    echo "Overall: FAIL — inspect the output above."
    BATCH_RC=1
  fi
  exit "$BATCH_RC"
} 2>&1 | tee "$REPORT"

REPORT_RC=${PIPESTATUS[0]}
sha256sum "$REPORT" > "$MANIFEST"
sha256sum tests/validation-30.php smart64-validation-30-batch.sh >> "$MANIFEST"

echo
echo "Batch report: $REPORT"
echo "SHA-256 manifest: $MANIFEST"
cat "$MANIFEST"

exit "$REPORT_RC"
