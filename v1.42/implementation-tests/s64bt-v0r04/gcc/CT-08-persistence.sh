#!/usr/bin/env bash
# CT-08 - Persistence after controlled restart.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# Scope: controlled MariaDB service restart only; not power-loss.
set -euo pipefail
cd "$(dirname "$0")/.."
MYSQL_BIN="${MYSQL_BIN:-/opt/lampp/bin/mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
DB="${S64BT_DB_NAME_CT07:-s64_ct07_disposable}"
EVID="${S64BT_EVIDENCE_DIR:-gcc/evidence}"
OUT="$EVID/CT-08"
ENGINE_FILE="$EVID/CT-07/engine-id.txt"
mkdir -p "$OUT"

if [[ ! -s "$ENGINE_FILE" ]]; then
    echo "Missing CT-07 engine identity: $ENGINE_FILE" >&2
    exit 2
fi
ENGINE_ID="$(awk -F= '$1=="engine_id"{print $2}' "$ENGINE_FILE")"
[[ "$ENGINE_ID" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid test Engine ID in $ENGINE_FILE" >&2; exit 2; }

query_snapshot() {
    "$MYSQL_BIN" -u "$MYSQL_USER" --socket="${S64_DB_SOCKET:-/opt/lampp/var/mysql/mysql.sock}" -N -B "$DB" -e "
    SELECT
      (SELECT COUNT(*) FROM allocation WHERE engine_id=$ENGINE_ID),
      (SELECT COUNT(DISTINCT s64_id) FROM allocation WHERE engine_id=$ENGINE_ID),
      (SELECT COALESCE(MIN(local_id),0) FROM allocation WHERE engine_id=$ENGINE_ID),
      (SELECT COALESCE(MAX(local_id),0) FROM allocation WHERE engine_id=$ENGINE_ID),
      (SELECT next_local_id FROM engine_counter WHERE engine_id=$ENGINE_ID),
      VERSION();
    "
}

query_uptime() {
    "$MYSQL_BIN" -u "$MYSQL_USER" --socket="${S64_DB_SOCKET:-/opt/lampp/var/mysql/mysql.sock}" -N -B -e \
        "SHOW GLOBAL STATUS LIKE 'Uptime'" | awk '{print $2}'
}

case "${1:-}" in
  baseline)
    {
        echo "phase=baseline"
        echo "database=$DB"
        echo "engine_id=$ENGINE_ID"
        echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "mariadb_uptime_seconds=$(query_uptime)"
        query_snapshot
    } > "$OUT/baseline.txt"
    echo "CT-08: SCOPE=controlled-service-restart"
    echo "CT-08 baseline saved for Engine $ENGINE_ID. Restart MariaDB manually, then run verify."
    ;;
  verify)
    test -s "$OUT/baseline.txt" || { echo "Missing baseline evidence" >&2; exit 2; }
    {
        echo "phase=post_restart"
        echo "database=$DB"
        echo "engine_id=$ENGINE_ID"
        echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "mariadb_uptime_seconds=$(query_uptime)"
        query_snapshot
    } > "$OUT/recovery-results.txt"
    python3 - "$OUT/baseline.txt" "$OUT/recovery-results.txt" <<'PY'
import sys

def parse(path):
    meta = {}
    data = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        if "=" in line and not line[0].isdigit() and "\t" not in line:
            k, v = line.split("=", 1)
            meta[k] = v
        elif "\t" in line:
            data = line
    if data is None:
        raise SystemExit(f"Expected one snapshot row in {path}")
    return meta, data

a_meta, a_snapshot = parse(sys.argv[1])
b_meta, b_snapshot = parse(sys.argv[2])

if a_snapshot != b_snapshot:
    print("comparison=FAIL")
    print(f"baseline_snapshot={a_snapshot}")
    print(f"recovery_snapshot={b_snapshot}")
    sys.exit(1)

try:
    a_up = int(a_meta["mariadb_uptime_seconds"])
    b_up = int(b_meta["mariadb_uptime_seconds"])
except (KeyError, ValueError):
    print("comparison=UNKNOWN (uptime missing)")
    sys.exit(2)

if b_up >= a_up:
    print("comparison=FAIL (server uptime did not reset; restart not proven)")
    print(f"baseline_uptime={a_up}")
    print(f"recovery_uptime={b_up}")
    sys.exit(1)

print("comparison=PASS")
print(f"baseline_uptime={a_up} recovery_uptime={b_up}")
PY
    ;;
  *)
    echo "Usage: $0 baseline|verify" >&2
    exit 2
    ;;
esac
