#!/usr/bin/env bash
# 01-run-dry.sh - dry run.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# Writes no evidence into gcc/evidence/. Refuses evidence-tree modification.
set -uo pipefail
cd "$(dirname "$0")"

DRYRUN=0
KEEP_LOGS=0
for arg in "$@"; do
    case "$arg" in
        --i-understand-this-is-a-dry-run) DRYRUN=1 ;;
        --keep-dryrun-logs)               KEEP_LOGS=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
if (( ! DRYRUN )); then
    echo "Refusing to run without --i-understand-this-is-a-dry-run" >&2
    exit 2
fi

source ./lib.sh
mysql_require || exit 1

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
DRYLOG=/tmp/s64-dryrun-$STAMP
DRYDB=$(dryrun_db_name "$STAMP")
mkdir -p "$DRYLOG"

echo "===== DRY RUN ====="
echo "stamp:  $STAMP"
echo "db:     $DRYDB"
echo "logdir: $DRYLOG"
echo "note:   no evidence will be written to $EVIDENCE_DIR/"

EVID_BEFORE=$(cd "$EVID" 2>/dev/null && find . -type f | sort | sha256sum | awk '{print $1}')

cleanup() {
    local code=$?
    echo
    echo "Cleaning up dry-run database $DRYDB"
    mysql_run -e "DROP DATABASE IF EXISTS \`$DRYDB\`" >/dev/null 2>&1 || true
    local evid_after
    evid_after=$(cd "$EVID" 2>/dev/null && find . -type f | sort | sha256sum | awk '{print $1}')
    if [[ "$EVID_BEFORE" != "$evid_after" ]]; then
        echo "FAIL: evidence tree changed during dry run" >&2
        code=1
    fi
    if (( KEEP_LOGS )); then
        echo "dry-run logs preserved at: $DRYLOG"
    else
        rm -rf "$DRYLOG"
    fi
    exit "$code"
}
trap cleanup EXIT
trap 'echo; echo "Interrupted by signal" >&2; exit 130' INT TERM

mysql_run -e "CREATE DATABASE IF NOT EXISTS $DB_NAME_TEST"
mysql_run -e "CREATE DATABASE \`$DRYDB\`"
mysql_run "$DRYDB" < gcc/db-schema.sql > "$DRYLOG/db-schema.log" 2>&1 || {
    echo "dry run: schema load failed" >&2; exit 1; }

run_c_test() {
    local tid="$1" src="$2"
    local out="$DRYLOG/.bin-CT-$tid"
    if ! gcc -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize \
            -march=native -Wall -Wextra -Werror \
            "$src" -o "$out" > "$DRYLOG/CT-$tid-compile.log" 2>&1; then
        echo "CT-$tid: compile FAIL (dry)" >&2; return 1
    fi
    if ! "$out" > "$DRYLOG/CT-$tid-run.log" 2>&1; then
        echo "CT-$tid: run FAIL (dry)" >&2; return 1
    fi
    # H4: strict assertion count from per-assertion lines
    local expect="$3"
    local per_pass per_fail per_total
    per_pass=$(grep -cE "^CT-$tid: assertion [0-9]+ PASS" "$DRYLOG/CT-$tid-run.log" || true)
    per_fail=$(grep -cE "^CT-$tid: assertion [0-9]+ FAIL" "$DRYLOG/CT-$tid-run.log" || true)
    per_total=$((per_pass + per_fail))
    if (( per_total != expect || per_fail != 0 )); then
        echo "CT-$tid: FAIL (dry, independent count $per_total/$expect fail=$per_fail)" >&2
        return 1
    fi
    echo "CT-$tid: PASS (dry)"
    return 0
}

run_c_test 01 gcc/CT-01-bit-encoding.c       18 || exit 1
run_c_test 02 gcc/CT-02-local-id-boundary.c   9 || exit 1
run_c_test 05 gcc/CT-05-profile-validation.c 36 || exit 1

# CT-03 dry
ENGINE=$((1800000 + RANDOM % 100000))
S64_A=$(python3 -c "print((2<<59) | (1<<50) | ($ENGINE<<29) | 1)")
S64_B=$(python3 -c "print((2<<59) | (1<<50) | ($ENGINE<<29) | 2)")
sed -e "s/__ENGINE_ID__/$ENGINE/g" \
    -e "s/__S64_A__/$S64_A/g" -e "s/__S64_B__/$S64_B/g" \
    gcc/CT-03-engine-uniqueness.sql > "$DRYLOG/CT-03-run.sql"
if mysql_run "$DRYDB" < "$DRYLOG/CT-03-run.sql" > "$DRYLOG/CT-03-run.log" 2>&1 \
   && grep -qE '^assertions=6 passed=6$' "$DRYLOG/CT-03-run.log" \
   && [[ "$(grep -cE '^[01]$' "$DRYLOG/CT-03-run.log")" == "6" ]] \
   && [[ "$(grep -cE '^0$' "$DRYLOG/CT-03-run.log" || true)" == "0" ]]; then
    echo "CT-03: PASS (dry)"
else
    echo "CT-03: FAIL (dry)" >&2; exit 1
fi

# CT-04 dry
if mysql_run -N -B "$DRYDB" < gcc/CT-04-cross-engine-isolation.sql \
       > "$DRYLOG/CT-04-run.log" 2>&1 \
   && grep -qE '^assertions=8 passed=8$' "$DRYLOG/CT-04-run.log" \
   && [[ "$(grep -cE '^[01]$' "$DRYLOG/CT-04-run.log")" == "8" ]] \
   && [[ "$(grep -cE '^0$' "$DRYLOG/CT-04-run.log" || true)" == "0" ]]; then
    echo "CT-04: PASS (dry)"
else
    echo "CT-04: FAIL (dry)" >&2; exit 1
fi

# CT-06 dry
P=$((1600000 + RANDOM % 100000))
V=$((8000000 + RANDOM * 100 + RANDOM))
sed -e "s/__PHYS_MATCH__/$P/g" -e "s/__PHYS_MISMATCH__/$((P+1))/g" \
    -e "s/__VIRT_MATCH__/$V/g" -e "s/__VIRT_MISMATCH__/$((V+1))/g" \
    gcc/CT-06-class-consistency.sql > "$DRYLOG/CT-06-run.sql"
if mysql_run -N -B "$DRYDB" < "$DRYLOG/CT-06-run.sql" \
       > "$DRYLOG/CT-06-run.log" 2>&1 \
   && grep -qE '^assertions=8 passed=8$' "$DRYLOG/CT-06-run.log" \
   && [[ "$(grep -cE '^[01]$' "$DRYLOG/CT-06-run.log")" == "8" ]] \
   && [[ "$(grep -cE '^0$' "$DRYLOG/CT-06-run.log" || true)" == "0" ]]; then
    echo "CT-06: PASS (dry)"
else
    echo "CT-06: FAIL (dry)" >&2; exit 1
fi

# CT-07 compile only
if ! gcc -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize \
        -march=native -Wall -Wextra -Werror \
        -I/opt/lampp/include gcc/CT-07-concurrent-allocation.c \
        $("${MYSQL_CONFIG:-/opt/lampp/bin/mysql_config}" --cflags --libs) -pthread \
        -o "$DRYLOG/.bin-CT-07" > "$DRYLOG/CT-07-compile.log" 2>&1; then
    echo "CT-07: compile FAIL (dry)" >&2; exit 1
fi
echo "CT-07: compile PASS (dry; workload not run in dry mode)"

# CT-08 syntax only
if ! bash -n gcc/CT-08-persistence.sh; then
    echo "CT-08: syntax FAIL (dry)" >&2; exit 1
fi
echo "CT-08: syntax PASS (dry; restart not exercised in dry mode)"

echo
echo "DRY RUN: all compilation and fast checks passed."
echo "No evidence was recorded. Proceed to Step 2 (02-run-fast-tests.sh) when ready."
