#!/usr/bin/env bash
# 02-run-fast-tests.sh - Step 2. Runs CT-01 .. CT-06, records evidence.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

mysql_require || exit 1
command -v gcc >/dev/null || die "gcc not found"

# Ensure test DB has schema
mysql_run -e "CREATE DATABASE IF NOT EXISTS $DB_NAME_TEST"
if ! mysql_run "$DB_NAME_TEST" < "$GCC_DIR/db-schema.sql" 2>/dev/null; then
    die "schema load into $DB_NAME_TEST failed"
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOGFILE="$EVID/BATCH/run-fast-$STAMP.log"
SUMMARY="$EVID/BATCH/summary-fast.txt"
META="$EVID/BATCH/META-fast.txt"

mkdir -p "$BATCH_DIR" "$EVID/CT-01" "$EVID/CT-02" "$EVID/CT-03" \
         "$EVID/CT-04" "$EVID/CT-05" "$EVID/CT-06" "$EVID/ENV"
: > "$LOGFILE"
: > "$SUMMARY"

logf "S64 v1.42 - Fast batch (CT-01 .. CT-06)"
logf "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
logf "started_utc=$STAMP"
logf "database=$DB_NAME_TEST"
logf "-----"

write_env_meta "$META"

PASS=0
FAIL=0
record() {
    local name="$1" ok="$2" detail="${3:-}"
    if [[ "$ok" == "1" ]]; then
        logf "$name: PASS${detail:+ ($detail)}"; PASS=$((PASS+1))
    else
        logf "$name: FAIL${detail:+ ($detail)}"; FAIL=$((FAIL+1))
    fi
}

run_c() {
    local id="$1" src="$2" expect_asserts="$3"
    local bin="$LIB_DIR/.build-CT-$id"
    if ! compile_c_test "$id" "$GCC_DIR/$src" "$bin" >> "$LOGFILE" 2>&1; then
        record "CT-$id" 0 "compile"; return
    fi
    if ! "$bin" > "$EVID/CT-$id/run.log" 2>&1; then
        record "CT-$id" 0 "run"; rm -f "$bin"; return
    fi
    rm -f "$bin"
    if ! assert_counts "$EVID/CT-$id/run.log" "$expect_asserts"; then
        record "CT-$id" 0 "assertion-count mismatch"; return
    fi
    record "CT-$id" 1 ""
}
run_c 01 "CT-01-bit-encoding.c"      "18"
run_c 02 "CT-02-local-id-boundary.c" "9"
run_c 05 "CT-05-profile-validation.c" "36"

find_free_engine() {
    local start="$1" candidate used
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        candidate=$(( start + RANDOM % 100000 ))
        used=$(mysql_scalar "SELECT COUNT(*) FROM $DB_NAME_TEST.physical_engine WHERE engine_id IN ($candidate,$((candidate+1)))" 2>/dev/null) || return 1
        if [[ "$used" == "0" ]]; then echo "$candidate"; return 0; fi
    done
    return 1
}

# --- CT-03 ---
ENGINE=$(find_free_engine 1800000 2>/dev/null || echo "")
if [[ -z "$ENGINE" ]]; then
    record "CT-03" 0 "no free engine id"
else
    S64_A=$(python3 -c "print((2<<59) | (1<<50) | ($ENGINE<<29) | 1)")
    S64_B=$(python3 -c "print((2<<59) | (1<<50) | ($ENGINE<<29) | 2)")
    sed -e "s/__ENGINE_ID__/$ENGINE/g" \
        -e "s/__S64_A__/$S64_A/g" -e "s/__S64_B__/$S64_B/g" \
        "$GCC_DIR/CT-03-engine-uniqueness.sql" > "$EVID/CT-03/CT-03-run.sql"
    if mysql_run "$DB_NAME_TEST" < "$EVID/CT-03/CT-03-run.sql" > "$EVID/CT-03/run.log" 2>&1 \
       && grep -qE '^assertions=6 passed=6$' "$EVID/CT-03/run.log" \
       && [[ "$(grep -cE '^[01]$' "$EVID/CT-03/run.log")" == "6" ]] \
       && [[ "$(grep -cE '^0$' "$EVID/CT-03/run.log" || true)" == "0" ]]; then
        record "CT-03" 1 "6/6 assertions, strict"
    else
        record "CT-03" 0 "strict check failed"
    fi
fi

# --- CT-04 ---
if mysql_run -N -B "$DB_NAME_TEST" < "$GCC_DIR/CT-04-cross-engine-isolation.sql" \
       > "$EVID/CT-04/run.log" 2>&1 \
   && grep -qE '^assertions=8 passed=8$' "$EVID/CT-04/run.log" \
   && [[ "$(grep -cE '^[01]$' "$EVID/CT-04/run.log")" == "8" ]] \
   && [[ "$(grep -cE '^0$' "$EVID/CT-04/run.log" || true)" == "0" ]]; then
    record "CT-04" 1 "expression-level, 8/8 strict"
else
    record "CT-04" 0 "strict check failed"
fi

# --- CT-06 ---
P=$(find_free_engine 1600000 2>/dev/null || echo "")
V=$(( 8000000 + RANDOM * 100 + RANDOM ))
if [[ -z "$P" ]]; then
    record "CT-06" 0 "no free physical fixture ids"
else
    VUSED=$(mysql_scalar "SELECT COUNT(*) FROM $DB_NAME_TEST.virtual_engine WHERE virtual_engine_id IN ($V,$((V+1)))")
    if [[ "$VUSED" != "0" ]]; then
        record "CT-06" 0 "virtual fixture collision"
    else
        sed -e "s/__PHYS_MATCH__/$P/g" -e "s/__PHYS_MISMATCH__/$((P+1))/g" \
            -e "s/__VIRT_MATCH__/$V/g" -e "s/__VIRT_MISMATCH__/$((V+1))/g" \
            "$GCC_DIR/CT-06-class-consistency.sql" > "$EVID/CT-06/CT-06-run.sql"
        if mysql_run -N -B "$DB_NAME_TEST" < "$EVID/CT-06/CT-06-run.sql" \
               > "$EVID/CT-06/run.log" 2>&1 \
           && grep -qE '^assertions=8 passed=8$' "$EVID/CT-06/run.log" \
           && [[ "$(grep -cE '^[01]$' "$EVID/CT-06/run.log")" == "8" ]] \
           && [[ "$(grep -cE '^0$' "$EVID/CT-06/run.log" || true)" == "0" ]]; then
            record "CT-06" 1 "8/8 strict"
        else
            record "CT-06" 0 "strict check failed"
        fi
    fi
fi

logf "-----"
logf "PASSED: $PASS"
logf "FAILED: $FAIL"
logf "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
    echo "S64 v1.42 - Fast batch (CT-01 .. CT-06)"
    echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
    echo "started_utc=$STAMP"
    echo "database=$DB_NAME_TEST"
    echo "-----"
    grep -E '^CT-0[0-9]: (PASS|FAIL)' "$LOGFILE"
    echo "-----"
    echo "PASSED: $PASS"
    echo "FAILED: $FAIL"
    echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$SUMMARY"

cat "$SUMMARY"

# H3: require 6 passes AND 0 failures
if (( PASS != 6 || FAIL != 0 )); then
    echo "FAIL: PASS=$PASS FAIL=$FAIL (require 6/0)" >&2
    exit 1
fi
