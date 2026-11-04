#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MYSQL_BIN="${MYSQL_BIN:-/opt/lampp/bin/mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
DB="s64_ct07_disposable"
OUT="evidence/CT-08"
ENGINE_FILE="evidence/CT-07/engine-id.txt"
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

case "${1:-}" in
  baseline)
    {
      echo "phase=baseline"
      echo "database=$DB"
      echo "engine_id=$ENGINE_ID"
      echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      query_snapshot
    } > "$OUT/baseline.txt"
    echo "CT-08 baseline saved for Engine $ENGINE_ID. Restart MariaDB manually, then run --verify-ct08."
    ;;
  verify)
    test -s "$OUT/baseline.txt" || { echo "Missing baseline evidence" >&2; exit 2; }
    {
      echo "phase=post_restart"
      echo "database=$DB"
      echo "engine_id=$ENGINE_ID"
      echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      query_snapshot
    } > "$OUT/recovery-results.txt"
    python3 - "$OUT/baseline.txt" "$OUT/recovery-results.txt" <<'PY'
import sys

def parse(path):
    lines = open(path, encoding="utf-8").read().splitlines()
    meta = {line.split("=", 1)[0]: line.split("=", 1)[1]
            for line in lines if "=" in line and not line.startswith("captured_utc=")}
    data = [line for line in lines if line and not line.startswith(("phase=", "database=", "engine_id=", "captured_utc="))]
    if len(data) != 1:
        raise SystemExit(f"Expected one snapshot row in {path}; got {len(data)}")
    return meta, data[0]

(a_meta, a), (b_meta, b) = map(parse, sys.argv[1:])
keys = ("database", "engine_id")
ok = all(a_meta.get(k) == b_meta.get(k) for k in keys) and a == b
with open(sys.argv[2], "a", encoding="utf-8") as f:
    f.write("comparison=" + ("PASS" if ok else "FAIL") + "\n")
print("CT-08:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PY
    ;;
  *)
    echo "Usage: $0 baseline|verify" >&2
    exit 2
    ;;
esac
