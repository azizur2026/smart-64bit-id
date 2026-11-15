#!/usr/bin/env bash
# lib.sh - shared helpers for the S64BT test package.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# Sourced by all run-*.sh scripts. Do not execute directly.

set -uo pipefail

# --- Locate this package ---
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCC_DIR="$LIB_DIR/gcc"

# --- Load s64bt.config ---
S64BT_CONFIG="$LIB_DIR/s64bt.config"
if [[ ! -f "$S64BT_CONFIG" ]]; then
    echo "FATAL: s64bt.config not found at $S64BT_CONFIG" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$S64BT_CONFIG"

# --- Validate required config keys ---
required_keys=(PKG_VERSION PKG_REVISION PKG_DATE DB_CONTROLLER
               DB_HOST DB_USER DB_SOCKET
               DB_NAME_TEST DB_NAME_CT07 DB_NAME_DRYRUN_PREFIX
               CT07_WORKERS CT07_OPS_PER_WORKER CT07_CLASS_ID
               EVIDENCE_DIR)
for k in "${required_keys[@]}"; do
    if [[ -z "${!k+x}" ]]; then
        echo "FATAL: s64bt.config missing required key: $k" >&2
        exit 1
    fi
done

# --- Validate DB controller ---
case "$DB_CONTROLLER" in
    mysql)
        MYSQL_BIN="${MYSQL_BIN:-/opt/lampp/bin/mysql}"
        MYSQL_CONFIG="${MYSQL_CONFIG:-/opt/lampp/bin/mysql_config}"
        ;;
    postgresql)
        echo "FATAL: DB_CONTROLLER=postgresql is reserved but not implemented in v0r04" >&2
        exit 1
        ;;
    *)
        echo "FATAL: unknown DB_CONTROLLER='$DB_CONTROLLER' (allowed: mysql)" >&2
        exit 1
        ;;
esac

# --- Export config-derived values for callers ---
export S64BT_PKG_VERSION="$PKG_VERSION"
export S64BT_PKG_REVISION="$PKG_REVISION"
export S64BT_PKG_DATE="$PKG_DATE"
export S64BT_DB_CONTROLLER="$DB_CONTROLLER"
export S64BT_DB_HOST="$DB_HOST"
export S64BT_DB_USER="$DB_USER"
export S64BT_DB_PASSWORD="$DB_PASSWORD"
export S64BT_DB_SOCKET="$DB_SOCKET"
export S64BT_DB_NAME_TEST="$DB_NAME_TEST"
export S64BT_DB_NAME_CT07="$DB_NAME_CT07"
export S64BT_DB_NAME_DRYRUN_PREFIX="$DB_NAME_DRYRUN_PREFIX"
export S64BT_CT07_WORKERS="$CT07_WORKERS"
export S64BT_CT07_OPS_PER_WORKER="$CT07_OPS_PER_WORKER"
export S64BT_CT07_CLASS_ID="$CT07_CLASS_ID"
export S64BT_EVIDENCE_DIR="$EVIDENCE_DIR"

# --- Derived paths ---
EVID="$LIB_DIR/$EVIDENCE_DIR"
BATCH_DIR="$EVID/BATCH"

# --- Alias for backward compat with runner scripts ---
MYSQL_USER="${MYSQL_USER:-$DB_USER}"
S64_DB_SOCKET="${S64_DB_SOCKET:-$DB_SOCKET}"
MYSQL_ARGS=(-u "$MYSQL_USER" --socket="$S64_DB_SOCKET")

# --- Logging ---
log()  { printf '%s\n' "$*"; }
logf() { printf '%s\n' "$*" | tee -a "${LOGFILE:-/dev/null}"; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

# --- MySQL helpers ---
mysql_run()    { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" "$@"; }
mysql_scalar() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" -N -B -e "$1"; }

mysql_require() {
    if ! mysql_scalar "SELECT 1" >/dev/null 2>&1; then
        die "MariaDB not reachable at socket $S64_DB_SOCKET as user $MYSQL_USER"
    fi
}

# --- Compilation helper for C tests ---
compile_c_test() {
    local id="$1" src="$2" out="$3"
    mkdir -p "$EVID/CT-$id"
    if gcc -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize \
           -march=native -Wall -Wextra -Werror \
           "$src" -o "$out" \
           >"$EVID/CT-$id/compile.log" 2>&1; then
        return 0
    fi
    return 1
}

compile_ct07_test() {
    mkdir -p "$EVID/CT-07"
    if gcc -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize \
           -march=native -Wall -Wextra -Werror \
           -I/opt/lampp/include "$GCC_DIR/CT-07-concurrent-allocation.c" \
           $("$MYSQL_CONFIG" --cflags --libs) -pthread \
           -o "$LIB_DIR/.build-CT-07" \
           >"$EVID/CT-07/compile.log" 2>&1; then
        return 0
    fi
    return 1
}

# --- Assertion-count cross-check (independent count from per-assertion lines) ---
assert_counts() {
    local logf="$1" expect_total="$2"
    local line
    line=$(grep -E '^assertions=[0-9]+ passed=[0-9]+$' "$logf" | tail -1 || true)
    [[ -n "$line" ]] || { printf 'missing assertion-count line in %s\n' "$logf" >&2; return 1; }
    local a p
    a=$(printf '%s\n' "$line" | sed -E 's/^assertions=([0-9]+).*/\1/')
    p=$(printf '%s\n' "$line" | sed -E 's/.*passed=([0-9]+)$/\1/')
    [[ "$a" == "$expect_total" ]] || { printf 'declared count %s != expected %s\n' "$a" "$expect_total" >&2; return 1; }
    [[ "$a" == "$p" ]] || { printf 'declared %s != passed %s\n' "$a" "$p" >&2; return 1; }
    local per_pass per_fail per_total
    per_pass=$(grep -cE '^CT-0[125]: assertion [0-9]+ PASS' "$logf" || true)
    per_fail=$(grep -cE '^CT-0[125]: assertion [0-9]+ FAIL' "$logf" || true)
    per_total=$((per_pass + per_fail))
    if (( per_total != expect_total )); then
        printf 'independent count %s != expected %s (pass=%s fail=%s)\n' \
            "$per_total" "$expect_total" "$per_pass" "$per_fail" >&2
        return 1
    fi
    if (( per_fail != 0 )); then
        printf '%s per-assertion FAIL lines\n' "$per_fail" >&2
        return 1
    fi
    return 0
}

# --- Environment metadata (now includes S64BT package version) ---
write_env_meta() {
    local meta="$1"
    mkdir -p "$(dirname "$meta")"
    local pkg_files=(s64bt.config lib.sh 00-prep-fresh-tree.sh
                     01-run-dry.sh 02-run-fast-tests.sh 03-run-ct07.sh
                     04-run-ct08-verify.sh 05-run-final-manifest.sh)
    local src_files=(CT-01-bit-encoding.c CT-02-local-id-boundary.c
                     CT-03-engine-uniqueness.sql CT-04-cross-engine-isolation.sql
                     CT-05-profile-validation.c CT-06-class-consistency.sql
                     CT-07-concurrent-allocation.c CT-07-disposable-schema.sql
                     CT-08-persistence.sh db-schema.sql)
    for f in "${pkg_files[@]}"; do
        [[ -f "$LIB_DIR/$f" ]] || { echo "write_env_meta: missing $f" >&2; return 1; }
    done
    for f in "${src_files[@]}"; do
        [[ -f "$GCC_DIR/$f" ]] || { echo "write_env_meta: missing $f" >&2; return 1; }
    done
    local pkg_hashes src_hashes
    pkg_hashes=$( cd "$LIB_DIR" && sha256sum "${pkg_files[@]}" ) || {
        echo "write_env_meta: harness sha256sum failed" >&2; return 1; }
    src_hashes=$( cd "$GCC_DIR" && sha256sum "${src_files[@]}" ) || {
        echo "write_env_meta: test-source sha256sum failed" >&2; return 1; }
    local n_pkg n_src
    n_pkg=$(printf '%s\n' "$pkg_hashes" | wc -l)
    n_src=$(printf '%s\n' "$src_hashes" | wc -l)
    if (( n_pkg != ${#pkg_files[@]} )); then
        echo "write_env_meta: harness count $n_pkg != ${#pkg_files[@]}" >&2; return 1
    fi
    if (( n_src != ${#src_files[@]} )); then
        echo "write_env_meta: source count $n_src != ${#src_files[@]}" >&2; return 1
    fi
    {
        echo "pkg_version=$S64BT_PKG_VERSION"
        echo "pkg_revision=$S64BT_PKG_REVISION"
        echo "pkg_date=$S64BT_PKG_DATE"
        echo "batch_start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "host=$(uname -a)"
        echo "kernel=$(uname -r)"
        echo "gcc=$(gcc --version | head -1)"
        echo "mariadb=$(mysql_scalar 'SELECT VERSION()' 2>/dev/null || echo unknown)"
        echo "db_controller=$S64BT_DB_CONTROLLER"
        echo "socket=$S64_DB_SOCKET"
        echo "mysql_user=$MYSQL_USER"
        echo "lib_dir=$LIB_DIR"
        echo "max_connections=$(mysql_scalar "SHOW VARIABLES LIKE 'max_connections'" 2>/dev/null | awk '{print $2}' || echo unknown)"
        echo "open_files_limit=$(mysql_scalar "SHOW VARIABLES LIKE 'open_files_limit'" 2>/dev/null | awk '{print $2}' || echo unknown)"
        echo "table_open_cache=$(mysql_scalar "SHOW VARIABLES LIKE 'table_open_cache'" 2>/dev/null | awk '{print $2}' || echo unknown)"
        echo "ulimit_n=$(ulimit -n 2>/dev/null || echo unknown)"
        echo "--- package harness hashes ---"
        printf '%s\n' "$pkg_hashes" | sort -k2
        echo "--- test source hashes ---"
        printf '%s\n' "$src_hashes" | sort -k2
    } > "$meta"
    return 0
}

# --- Source hash extraction ---
source_hashes() {
    local dir="$1"
    ( cd "$dir" && sha256sum CT-*.c CT-*.sql CT-08-persistence.sh db-schema.sql 2>/dev/null | sort -k2 )
}

# --- File presence guard ---
require_file() {
    local f="$1" msg="${2:-required file missing}"
    [[ -s "$f" ]] || die "$msg: $f"
}

# --- M1: batch-log validator + exact count check ---
# Usage: require_pass <summary-file> <batch-name> <exact-pass-count> [<batch-log>] [<test-prefix>]
# Verifies:
#   - summary has PASSED: N where N == expect
#   - summary has FAILED: 0
#   - if batch-log provided: each test line reports PASS, and expected test count matches
require_pass() {
    local summary="$1" label="$2" expect="${3:-1}" batch_log="${4:-}" test_prefix="${5:-}"
    require_file "$summary" "$label summary missing"
    # Fail closed: if batch_log arg is empty OR test_prefix is empty, refuse
    if [[ -z "$batch_log" ]] || [[ -z "$test_prefix" ]]; then
        die "$label: require_pass needs batch_log and test_prefix for independent validation"
    fi
    local passed failed
    passed=$(grep -E '^PASSED: [0-9]+' "$summary" | tail -1 | awk '{print $2}')
    failed=$(grep -E '^FAILED: [0-9]+' "$summary" | tail -1 | awk '{print $2}')
    if [[ -z "$passed" ]] || [[ -z "$failed" ]]; then
        die "$label summary missing PASSED/FAILED: $summary"
    fi
    if ! [[ "$passed" =~ ^[0-9]+$ ]] || ! [[ "$failed" =~ ^[0-9]+$ ]]; then
        die "$label summary non-numeric: passed=$passed failed=$failed"
    fi
    if (( failed != 0 )); then
        die "$label summary FAILED=$failed: $summary"
    fi
    if (( passed != expect )); then
        die "$label summary PASSED=$passed, expected exactly $expect"
    fi
    # M1: independently verify batch log if provided
    if [[ -n "$batch_log" ]]; then
        require_file "$batch_log" "$label batch log missing"
        if [[ -n "$test_prefix" ]]; then
            local n_pass n_fail
            n_pass=$(grep -cE "^${test_prefix}: PASS" "$batch_log" || true)
            n_fail=$(grep -cE "^${test_prefix}: FAIL" "$batch_log" || true)
            if (( n_fail != 0 )); then
                die "$label batch log shows $n_fail FAIL lines"
            fi
            if (( n_pass != expect )); then
                die "$label batch log shows $n_pass PASS lines, expected $expect"
            fi
        fi
    fi
}

# --- Dry-run database name ---
dryrun_db_name() {
    local stamp="$1"
    printf '%s%s' "$S64BT_DB_NAME_DRYRUN_PREFIX" "$stamp"
}
