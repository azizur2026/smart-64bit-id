#!/usr/bin/env bash
# 03-run-ct07.sh - Step 3. Runs CT-07 only.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# M2: validates CT-07 run.log against config-derived expected values.
# M3: post-run audit is SUPPLEMENTARY evidence, not a pass/fail gate.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

mysql_require || exit 1

if [[ "${1:-}" != "--i-understand-disposable-db" ]]; then
    echo "Refusing to run without --i-understand-disposable-db" >&2
    exit 2
fi

FAST_LOG=$(ls -1t "$EVID/BATCH/run-fast-"*.log 2>/dev/null | head -1)
require_pass "$EVID/BATCH/summary-fast.txt" "fast-batch" 6 \
             "$FAST_LOG" "CT-0[1-9]"

FAST_META="$EVID/BATCH/META-fast.txt"
require_file "$FAST_META" "fast batch metadata missing"
FAST_HASHES=$(awk '/^--- test source hashes ---/{f=1;next} f' "$FAST_META" | sort -k2)
NOW_HASHES=$(source_hashes "$GCC_DIR")
if [[ "$FAST_HASHES" != "$NOW_HASHES" ]]; then
    echo "Source hashes differ between fast batch and now. Refusing to run." >&2
    diff <(echo "$FAST_HASHES") <(echo "$NOW_HASHES") >&2
    exit 1
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOGFILE="$EVID/BATCH/run-ct07-$STAMP.log"
SUMMARY="$EVID/BATCH/summary-ct07.txt"
META="$EVID/BATCH/META-ct07.txt"

: > "$LOGFILE"
write_env_meta "$META"

logf "S64 v1.42 — CT-07 batch"
logf "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
logf "started_utc=$STAMP"
logf "database=$DB_NAME_CT07"
logf "-----"

if ! mysql_run -e "CREATE DATABASE IF NOT EXISTS $DB_NAME_CT07" \
       > "$EVID/CT-07/database-setup.log" 2>&1; then
    logf "CT-07: FAIL (could not create $DB_NAME_CT07)"
    { echo "PASSED: 0"; echo "FAILED: 1"; } >> "$SUMMARY"
    exit 1
fi
{
    echo "--- $(date -u +%Y-%m-%dT%H:%M:%SZ) applying CT-07-disposable-schema.sql ---"
} >> "$EVID/CT-07/database-setup.log"

if ! mysql_run < "$GCC_DIR/CT-07-disposable-schema.sql" \
       >> "$EVID/CT-07/database-setup.log" 2>&1; then
    logf "CT-07: FAIL (schema load failed)"
    { echo "PASSED: 0"; echo "FAILED: 1"; } >> "$SUMMARY"
    exit 1
fi
{
    echo "--- schema applied successfully ---"
    echo "tables:"
    mysql_run -N -B "$DB_NAME_CT07" -e "SHOW TABLES" 2>/dev/null
} >> "$EVID/CT-07/database-setup.log"

if ! compile_ct07_test >> "$LOGFILE" 2>&1; then
    logf "CT-07: FAIL (compile)"
    { echo "PASSED: 0"; echo "FAILED: 1"; } >> "$SUMMARY"
    exit 1
fi

mkdir -p "$EVID/CT-07"
if S64BT_CONFIG="$S64BT_CONFIG" \
   S64_EVIDENCE_DIR="$EVID" \
   LD_LIBRARY_PATH=/opt/lampp/lib:${LD_LIBRARY_PATH:-} \
   S64_DB_USER="$MYSQL_USER" S64_DB_PASS="${MYSQL_PWD:-}" \
   S64_DB_SOCKET="$S64_DB_SOCKET" \
   "$LIB_DIR/.build-CT-07" --i-understand-disposable-db \
   > "$EVID/CT-07/run.log" 2>&1; then
    logf "CT-07: PASS"
    PASS=1; FAIL=0
else
    logf "CT-07: FAIL"
    PASS=0; FAIL=1
fi
rm -f "$LIB_DIR/.build-CT-07"

# M2: independently validate run.log against config
if (( PASS == 1 )); then
    EXPECTED=$(( S64BT_CT07_WORKERS * S64BT_CT07_OPS_PER_WORKER ))
    LOG="$EVID/CT-07/run.log"
    v_workers=$(grep -cE '^Workers created: '"$S64BT_CT07_WORKERS"'$' "$LOG" || true)
    v_exp=$(grep -cE '^Expected allocations: '"$EXPECTED"'$' "$LOG" || true)
    v_ok=$(grep -cE '^Successful allocations: '"$EXPECTED"'$' "$LOG" || true)
    v_fail=$(grep -cE '^Failed allocations: 0$' "$LOG" || true)
    v_enc=$(grep -cE '^Rows with wrong encoding: 0$' "$LOG" || true)
    v_asm=$(grep -cE '^assertions=6 passed=6$' "$LOG" || true)
    if (( v_workers==1 && v_exp==1 && v_ok==1 && v_fail==1 && v_enc==1 && v_asm==1 )); then
        logf "CT-07 log validation: PASS (6 metrics matched)"
    else
        logf "CT-07 log validation: FAIL (w=$v_workers e=$v_exp ok=$v_ok f=$v_fail enc=$v_enc asm=$v_asm)"
        PASS=0; FAIL=1
    fi
fi

# M3: audit is supplementary, not a gate
{
    echo "--- post-run audit (SUPPLEMENTARY; not a gate) ---"
    echo "engine_counter:"
    mysql_run -N -B "$DB_NAME_CT07" -e "SELECT engine_id, next_local_id FROM engine_counter ORDER BY engine_id" 2>/dev/null
    echo "current engine allocation snapshot:"
    CUR_ENGINE=$(awk -F= '$1=="engine_id"{print $2}' "$EVID/CT-07/engine-id.txt" 2>/dev/null)
    if [[ -n "$CUR_ENGINE" ]]; then
        mysql_run -N -B "$DB_NAME_CT07" -e "SELECT COUNT(*), COUNT(DISTINCT s64_id), MIN(local_id), MAX(local_id) FROM allocation WHERE engine_id=$CUR_ENGINE" 2>/dev/null
    fi
} >> "$EVID/CT-07/database-setup.log"

# Auto-capture CT-08 baseline
if (( PASS == 1 )); then
    if MYSQL_BIN="$MYSQL_BIN" MYSQL_USER="$MYSQL_USER" S64_DB_SOCKET="$S64_DB_SOCKET" \
       bash "$GCC_DIR/CT-08-persistence.sh" baseline \
       > "$EVID/CT-08/baseline-command.log" 2>&1; then
        logf "CT-08 baseline captured: $EVID/CT-08/baseline.txt"
    else
        logf "CT-08 baseline capture FAILED — see $EVID/CT-08/baseline-command.log"
        logf "CT-07: FAIL (CT-08 baseline missing)"
        PASS=0; FAIL=1
    fi
fi

logf "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
    echo "S64 v1.42 — CT-07 batch"
    echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
    echo "started_utc=$STAMP"
    echo "database=$DB_NAME_CT07"
    echo "ct08_baseline=$([[ -s "$EVID/CT-08/baseline.txt" ]] && echo present || echo missing)"
    echo "-----"
    grep -E '^CT-07: (PASS|FAIL)' "$LOGFILE"
    echo "PASSED: $PASS"
    echo "FAILED: $FAIL"
    echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$SUMMARY"

cat "$SUMMARY"

(( FAIL == 0 )) || exit 1
