#!/usr/bin/env bash
# 04-run-ct08-verify.sh - Step 5. Verify CT-08 after operator restarts MariaDB.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

mysql_require || exit 1

CT07_LOG=$(ls -1t "$EVID/BATCH/run-ct07-"*.log 2>/dev/null | head -1)
require_pass "$EVID/BATCH/summary-ct07.txt" "ct07-batch" 1 \
             "$CT07_LOG" "CT-07"

CT07_META="$EVID/BATCH/META-ct07.txt"
require_file "$CT07_META" "CT-07 metadata missing"
CT07_HASHES=$(awk '/^--- test source hashes ---/{f=1;next} f' "$CT07_META" | sort -k2)
NOW_HASHES=$(source_hashes "$GCC_DIR")
if [[ "$CT07_HASHES" != "$NOW_HASHES" ]]; then
    echo "Source hashes differ between CT-07 batch and now. Refusing to run." >&2
    diff <(echo "$CT07_HASHES") <(echo "$NOW_HASHES") >&2
    exit 1
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOGFILE="$EVID/BATCH/run-ct08-$STAMP.log"
SUMMARY="$EVID/BATCH/summary-ct08.txt"
META="$EVID/BATCH/META-ct08.txt"

: > "$LOGFILE"
write_env_meta "$META"

logf() { printf '%s\n' "$*" | tee -a "$LOGFILE"; }

logf "S64 v1.42 - CT-08 verify batch"
logf "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
logf "started_utc=$STAMP"

if [[ ! -s "$EVID/CT-08/baseline.txt" ]]; then
    logf "CT-08: FAIL (no baseline)"
    { echo "S64 v1.42 - CT-08 verify batch"
      echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
      echo "started_utc=$STAMP"
      echo "PASSED: 0"
      echo "FAILED: 1"
      echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; } > "$SUMMARY"
    exit 1
fi

if MYSQL_BIN="$MYSQL_BIN" MYSQL_USER="$MYSQL_USER" S64_DB_SOCKET="$S64_DB_SOCKET" \
   bash "$GCC_DIR/CT-08-persistence.sh" verify \
   > "$EVID/CT-08/verify-command.log" 2>&1; then
    logf "CT-08: PASS"
    PASS=1; FAIL=0
else
    logf "CT-08: FAIL"
    PASS=0; FAIL=1
fi

logf "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
    echo "S64 v1.42 - CT-08 verify batch"
    echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
    echo "started_utc=$STAMP"
    echo "-----"
    tail -20 "$EVID/CT-08/verify-command.log"
    echo "PASSED: $PASS"
    echo "FAILED: $FAIL"
    echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$SUMMARY"

cat "$SUMMARY"

(( FAIL == 0 )) || exit 1
