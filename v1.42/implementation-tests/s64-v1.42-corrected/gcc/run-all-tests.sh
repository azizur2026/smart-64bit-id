#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"

MYSQL_BIN="${MYSQL_BIN:-/opt/lampp/bin/mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_SOCKET="${MYSQL_SOCKET:-${S64_DB_SOCKET:-/opt/lampp/var/mysql/mysql.sock}}"
DB="${S64_TEST_DB:-s64_test}"
MYSQL_ARGS=(-u "$MYSQL_USER" --socket="$MYSQL_SOCKET")
RUN_CT07=0
VERIFY_CT08=0
for arg in "$@"; do
  case "$arg" in
    --run-ct07) RUN_CT07=1 ;;
    --verify-ct08) VERIFY_CT08=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if (( RUN_CT07 && VERIFY_CT08 )); then
  echo "Choose either --run-ct07 or --verify-ct08, not both." >&2
  exit 2
fi
E="evidence"
B="$E/BATCH"
mkdir -p "$B"
REPORT="$B/summary.txt"
if (( VERIFY_CT08 )) && [[ -s "$REPORT" ]]; then
  cp "$REPORT" "$B/pre-restart-summary.txt"
fi
: > "$REPORT"
PASS=0; FAIL=0; INCOMPLETE=0
log(){ printf '%s\n' "$*" | tee -a "$REPORT"; }
run_mysql(){ "$MYSQL_BIN" "${MYSQL_ARGS[@]}" "$@"; }
compile_c(){
  local id="$1" src="$2" dir="$E/CT-$1" exe=".build-CT-$1"
  mkdir -p "$dir"
  if ! gcc -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize \
      -march=native -Wall -Wextra -Werror "$src" -o "$exe" \
      >"$dir/compile.log" 2>&1; then
    log "CT-$id: FAIL (compile)"; cat "$dir/compile.log" >> "$REPORT"; FAIL=$((FAIL+1)); return
  fi
  if "./$exe" >"$dir/run.log" 2>&1; then
    log "CT-$id: PASS"; PASS=$((PASS+1))
  else
    log "CT-$id: FAIL (execution)"; cat "$dir/run.log" >> "$REPORT"; FAIL=$((FAIL+1))
  fi
  rm -f "$exe"
}
find_free_physical(){
  local start="$1" candidate
  for ((i=0;i<40;i++)); do
    candidate=$((start + (RANDOM % 100000)))
    local used
    used=$(run_mysql -N -B "$DB" -e "SELECT COUNT(*) FROM physical_engine WHERE engine_id IN ($candidate,$((candidate+1)))" 2>/dev/null) || return 1
    if [[ "$used" == "0" ]]; then echo "$candidate"; return 0; fi
  done
  return 1
}
log "S64 v1.42 corrected test revision"
log "Started UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Database: $DB"
log "Execution mode: CT-07 opt-in=$RUN_CT07; CT-08 verify=$VERIFY_CT08"

# Environment evidence
mkdir -p "$E/ENV"
gcc --version > "$E/ENV/gcc-version.txt" 2>&1 || true
uname -a > "$E/ENV/system-info.txt" 2>&1 || true
lscpu > "$E/ENV/cpu-info.txt" 2>&1 || true
printf '%s\n' '-std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize -march=native -Wall -Wextra -Werror' > "$E/ENV/compiler-flags.txt"
run_mysql -N -B -e "SELECT VERSION()" > "$E/ENV/mariadb-server-version.txt" 2>&1 || true

if (( VERIFY_CT08 )); then
  log "CT-01 through CT-06: skipped in post-restart verification phase; prior evidence retained."
else
  compile_c 01 CT-01-bit-encoding.c
  compile_c 02 CT-02-local-id-boundary.c
  compile_c 05 CT-05-profile-validation.c
if ! run_mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB\`" >"$E/ENV/database-setup.log" 2>&1; then
  log "Database connection/setup failed; SQL tests CT-03, CT-04, and CT-06 cannot run."
  INCOMPLETE=$((INCOMPLETE+3))
else
  if ! run_mysql "$DB" < db-schema.sql >>"$E/ENV/database-setup.log" 2>&1; then
    log "Schema setup failed; SQL tests cannot run."
    INCOMPLETE=$((INCOMPLETE+3))
  else
    # CT-03 uses a collision-checked fixture ID and rolls back all fixture rows.
    mkdir -p "$E/CT-03"
    ENGINE=$(find_free_physical 1800000 2)
    if [[ -z "${ENGINE:-}" ]]; then
      log "CT-03: INCOMPLETE (could not obtain unused fixture ID)"; INCOMPLETE=$((INCOMPLETE+1))
    else
      read -r S64_A S64_B < <(python3 - "$ENGINE" <<'PY'
import sys
e=int(sys.argv[1])
base=(1<<63)|(1<<50)|(e<<29)
print(base+1, base+2)
PY
)
      sed -e "s/__ENGINE_ID__/$ENGINE/g" -e "s/__S64_A__/$S64_A/g" -e "s/__S64_B__/$S64_B/g" \
          CT-03-engine-uniqueness.sql > "$E/CT-03/CT-03-run.sql"
      if run_mysql "$DB" < "$E/CT-03/CT-03-run.sql" > "$E/CT-03/run.log" 2>&1 &&
         grep -q 'CT-03: PASS' "$E/CT-03/run.log"; then
        log "CT-03: PASS (duplicate composite key rejected; fixture rolled back)"; PASS=$((PASS+1))
      else
        log "CT-03: FAIL"; cat "$E/CT-03/run.log" >> "$REPORT"; FAIL=$((FAIL+1))
      fi
    fi

    mkdir -p "$E/CT-04"
    if run_mysql -N -B "$DB" < CT-04-cross-engine-isolation.sql > "$E/CT-04/run.log" 2>&1 &&
       grep -Eq '^[[:space:]]*1([[:space:]]+1){6}[[:space:]]*$' "$E/CT-04/run.log"; then
      log "CT-04: PASS (seven expression-level assertions)"; PASS=$((PASS+1))
    else
      log "CT-04: FAIL"; cat "$E/CT-04/run.log" >> "$REPORT"; FAIL=$((FAIL+1))
    fi

    mkdir -p "$E/CT-06"
    P=$(find_free_physical 1600000 2)
    V=$((8000000 + RANDOM * 100 + RANDOM))
    if [[ -z "${P:-}" ]]; then
      log "CT-06: INCOMPLETE (could not obtain unused physical fixture IDs)"; INCOMPLETE=$((INCOMPLETE+1))
    else
      # Confirm virtual IDs are unused before using explicit IDs.
      VUSED=$(run_mysql -N -B "$DB" -e "SELECT COUNT(*) FROM virtual_engine WHERE virtual_engine_id IN ($V,$((V+1)))" 2>/dev/null || echo 1)
      if [[ "$VUSED" != "0" ]]; then
        log "CT-06: INCOMPLETE (virtual fixture collision)"; INCOMPLETE=$((INCOMPLETE+1))
      else
        sed -e "s/__PHYS_MATCH__/$P/g" -e "s/__PHYS_MISMATCH__/$((P+1))/g" \
            -e "s/__VIRT_MATCH__/$V/g" -e "s/__VIRT_MISMATCH__/$((V+1))/g" \
            CT-06-class-consistency.sql > "$E/CT-06/CT-06-run.sql"
        if run_mysql -N -B "$DB" < "$E/CT-06/CT-06-run.sql" > "$E/CT-06/run.log" 2>&1 &&
           awk '$1=="matching_attachment"&&$2=="1"{a=1}
                $1=="mismatch_virtual_inactive"&&$2=="1"{b=1}
                $1=="mismatch_engine_quarantined"&&$2=="1"{c=1}
                $1=="mismatch_request_rejected"&&$2=="1"{d=1}
                END{exit !(a&&b&&c&&d)}' "$E/CT-06/run.log"; then
          log "CT-06: PASS (four Class comparison workflow assertions; transaction rolled back)"; PASS=$((PASS+1))
        else
          log "CT-06: FAIL"; cat "$E/CT-06/run.log" >> "$REPORT"; FAIL=$((FAIL+1))
        fi
      fi
    fi
  fi
fi

fi

if (( RUN_CT07 )); then
  mkdir -p "$E/CT-07"
  if ! run_mysql -e "CREATE DATABASE IF NOT EXISTS s64_ct07_disposable" >"$E/CT-07/database-setup.log" 2>&1 ||
     ! run_mysql < CT-07-disposable-schema.sql >>"$E/CT-07/database-setup.log" 2>&1; then
    log "CT-07: INCOMPLETE (dedicated disposable database/schema setup failed)"; INCOMPLETE=$((INCOMPLETE+1))
  else
    MYSQL_CONFIG="${MYSQL_CONFIG:-/opt/lampp/bin/mysql_config}"
    if [[ ! -x "$MYSQL_CONFIG" ]]; then MYSQL_CONFIG="$(command -v mysql_config || true)"; fi
    if [[ -z "$MYSQL_CONFIG" ]]; then
      log "CT-07: INCOMPLETE (mysql_config not found)"; INCOMPLETE=$((INCOMPLETE+1))
    else
      # shellcheck disable=SC2046
      if gcc -I/opt/lampp/include -std=c11 -O3 -fno-tree-vectorize -fno-tree-slp-vectorize -march=native \
          -Wall -Wextra -Werror CT-07-concurrent-allocation.c \
          $("$MYSQL_CONFIG" --cflags --libs) -pthread -o .build-CT-07 \
          >"$E/CT-07/compile.log" 2>&1; then
        if LD_LIBRARY_PATH=/opt/lampp/lib:${LD_LIBRARY_PATH:-} S64_DB_USER="$MYSQL_USER" S64_DB_PASS="${MYSQL_PWD:-}" \
           S64_DB_SOCKET="$MYSQL_SOCKET" \
           ./.build-CT-07 --i-understand-disposable-db >"$E/CT-07/run.log" 2>&1; then
          log "CT-07: PASS (fresh isolated 1,000-worker workload; no deletion/reset)"; PASS=$((PASS+1))
          if MYSQL_BIN="$MYSQL_BIN" MYSQL_USER="$MYSQL_USER" S64_DB_SOCKET="$MYSQL_SOCKET" bash CT-08-persistence.sh baseline > "$E/CT-08/baseline-command.log" 2>&1; then
            log "CT-08: INCOMPLETE (baseline captured; manual MariaDB restart and verify still required)"; INCOMPLETE=$((INCOMPLETE+1))
          else
            log "CT-08: INCOMPLETE (could not capture baseline; inspect CT-08/baseline-command.log)"; INCOMPLETE=$((INCOMPLETE+1))
          fi
        else
          log "CT-07: FAIL or REFUSED (see CT-07/run.log)"; cat "$E/CT-07/run.log" >> "$REPORT"; FAIL=$((FAIL+1))
        fi
        rm -f .build-CT-07
      else
        log "CT-07: FAIL (compilation)"; cat "$E/CT-07/compile.log" >> "$REPORT"; FAIL=$((FAIL+1))
      fi
    fi
  fi
elif (( VERIFY_CT08 )); then
  if grep -q "CT-07: PASS" "$E/CT-07/run.log" 2>/dev/null; then
    log "CT-07: PASS (previous fresh workload evidence; not rerun during restart verification)"; PASS=$((PASS+1))
  else
    log "CT-07: INCOMPLETE (no successful CT-07 workload evidence found)"; INCOMPLETE=$((INCOMPLETE+1))
  fi
else
  log "CT-07: INCOMPLETE (opt-in required: --run-ct07; uses separate disposable database)"; INCOMPLETE=$((INCOMPLETE+1))
fi

if (( VERIFY_CT08 )); then
  mkdir -p "$E/CT-08"
  if MYSQL_BIN="$MYSQL_BIN" MYSQL_USER="$MYSQL_USER" S64_DB_SOCKET="$MYSQL_SOCKET" bash CT-08-persistence.sh verify > "$E/CT-08/verify-command.log" 2>&1; then
    log "CT-08: PASS (post-restart snapshot matches baseline)"; PASS=$((PASS+1))
  else
    log "CT-08: FAIL/INCOMPLETE (see CT-08/verify-command.log)"; cat "$E/CT-08/verify-command.log" >> "$REPORT"; FAIL=$((FAIL+1))
  fi
else
  if (( RUN_CT07 == 0 )); then
    log "CT-08: INCOMPLETE (requires CT-07 fresh baseline, manual MariaDB restart, then --verify-ct08)"; INCOMPLETE=$((INCOMPLETE+1))
  fi
fi

log "----------------------------------------"
log "PASSED: $PASS"
log "FAILED: $FAIL"
log "INCOMPLETE: $INCOMPLETE"
log "Finished UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Hash evidence generated in this run; do not hash the manifest itself.
find "$E" -type f ! -name SHA256SUMS.txt -print0 |
  sort -z | xargs -0 -r sha256sum > "$B/SHA256SUMS.txt"
find . -maxdepth 1 -type f \( -name '*.c' -o -name '*.sql' -o -name '*.sh' \) -print0 |
  sort -z | xargs -0 -r sha256sum > SOURCE-SHA256SUMS.txt

if (( FAIL > 0 || INCOMPLETE > 0 )); then exit 1; fi
exit 0
