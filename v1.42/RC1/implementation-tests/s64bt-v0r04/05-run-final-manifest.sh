#!/usr/bin/env bash
# 05-run-final-manifest.sh - Step 6. Combines batch summaries into final manifest.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# H5: independently validates each batch's log, not only the summary counts.
# M4: manifest excludes itself from its own inventory.
set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
SUMMARY="$EVID/BATCH/summary-final.txt"
MANIFEST="$EVID/BATCH/EVIDENCE-MANIFEST-$STAMP.txt"
FINAL_META="$EVID/BATCH/META-final.txt"

declare -A BATCH_PASS=()
declare -A BATCH_SRC_HASHES=()
declare -A BATCH_PKG_HASHES=()

require_batch() {
    local name="$1" summary="$2" meta="$3" expect="${4:-0}" log_prefix="${5:-}"
    require_file "$summary" "$name summary missing"
    require_file "$meta"    "$name meta missing"
    local passed failed
    passed=$(grep -E '^PASSED: [0-9]+' "$summary" | tail -1 | awk '{print $2}')
    failed=$(grep -E '^FAILED: [0-9]+' "$summary" | tail -1 | awk '{print $2}')
    if [[ -z "$passed" ]] || [[ -z "$failed" ]]; then
        die "$name summary malformed: $summary"
    fi
    if ! [[ "$passed" =~ ^[0-9]+$ ]] || ! [[ "$failed" =~ ^[0-9]+$ ]]; then
        die "$name summary non-numeric: passed=$passed failed=$failed"
    fi
    if (( expect > 0 )) && (( passed != expect )); then
        die "$name summary PASSED=$passed, expected exactly $expect"
    fi
    # H5: independently validate batch log if provided
    if [[ -n "$log_prefix" ]]; then
        local logf
        logf=$(ls -1t "$EVID/BATCH/${log_prefix}"* 2>/dev/null | head -1)
        if [[ -z "$logf" ]]; then
            die "$name batch log missing (prefix '$log_prefix')"
        fi
        if [[ ! -s "$logf" ]]; then
            die "$name batch log is empty: $logf"
        fi
        local n_pass n_fail
        n_pass=$(grep -cE "^CT-0[0-9]: PASS" "$logf" || true)
        n_fail=$(grep -cE "^CT-0[0-9]: FAIL" "$logf" || true)
        if (( n_fail != 0 )); then
            die "$name log shows $n_fail FAIL lines ($logf)"
        fi
        if (( n_pass != expect )); then
            die "$name log shows $n_pass PASS lines, expected $expect ($logf)"
        fi
    fi
    BATCH_PASS["$name"]="passed=$passed failed=$failed"
    BATCH_SRC_HASHES["$name"]=$(awk '/^--- test source hashes ---/{f=1;next} f' "$meta" | sort -k2 | sha256sum | awk '{print $1}')
    BATCH_PKG_HASHES["$name"]=$(awk '/^--- package harness hashes ---/{f=1;next} /^--- /{if(f)exit} f' "$meta" | sort -k2 | sha256sum | awk '{print $1}')
}

require_batch "fast"  "$EVID/BATCH/summary-fast.txt"  "$EVID/BATCH/META-fast.txt"  6 "run-fast-"
require_batch "ct07"  "$EVID/BATCH/summary-ct07.txt"  "$EVID/BATCH/META-ct07.txt"  1 "run-ct07-"
require_batch "ct08"  "$EVID/BATCH/summary-ct08.txt"  "$EVID/BATCH/META-ct08.txt"  1 "run-ct08-"

ALL_PASS=1
for name in fast ct07 ct08; do
    local_passed=$(printf '%s\n' "${BATCH_PASS[$name]}" | sed -E 's/^passed=([0-9]+).*/\1/')
    local_failed=$(printf '%s\n' "${BATCH_PASS[$name]}" | sed -E 's/.*failed=([0-9]+)$/\1/')
    if (( local_failed != 0 )); then
        echo "batch $name has failures (${BATCH_PASS[$name]})" >&2
        ALL_PASS=0
    fi
done

H_FAST="${BATCH_SRC_HASHES[fast]}"
H_CT07="${BATCH_SRC_HASHES[ct07]}"
H_CT08="${BATCH_SRC_HASHES[ct08]}"
if [[ "$H_FAST" != "$H_CT07" ]] || [[ "$H_FAST" != "$H_CT08" ]]; then
    echo "source hashes differ across batches; refusing to emit final summary" >&2
    ALL_PASS=0
fi

# Cross-check source hashes vs current files
for batch in fast ct07 ct08; do
    meta_file="$EVID/BATCH/META-$batch.txt"
    if [[ -s "$meta_file" ]]; then
        recorded=$(awk '/^--- test source hashes ---/{f=1;next} f' "$meta_file" | sort -k2)
        current=$(cd "$GCC_DIR" && sha256sum CT-*.c CT-*.sql CT-08-persistence.sh db-schema.sql 2>/dev/null | sort -k2)
        if [[ "$recorded" != "$current" ]]; then
            echo "batch $batch source hashes do not match current files" >&2
            ALL_PASS=0
        fi
    fi
done

# B-fix: harness hash agreement across batches
HP_FAST="${BATCH_PKG_HASHES[fast]}"
HP_CT07="${BATCH_PKG_HASHES[ct07]}"
HP_CT08="${BATCH_PKG_HASHES[ct08]}"
if [[ -z "$HP_FAST" ]] || [[ -z "$HP_CT07" ]] || [[ -z "$HP_CT08" ]]; then
    echo "harness hash blocks missing from one or more batches" >&2
    ALL_PASS=0
elif [[ "$HP_FAST" != "$HP_CT07" ]] || [[ "$HP_FAST" != "$HP_CT08" ]]; then
    echo "harness hashes differ across batches" >&2
    ALL_PASS=0
fi

current_pkg=$( cd "$LIB_DIR" && sha256sum s64bt.config lib.sh 00-prep-fresh-tree.sh \
    01-run-dry.sh 02-run-fast-tests.sh 03-run-ct07.sh \
    04-run-ct08-verify.sh 05-run-final-manifest.sh 2>/dev/null | sort -k2 | sha256sum | awk '{print $1}')
if [[ "$HP_FAST" != "$current_pkg" ]]; then
    echo "current package harness hashes do not match batch recordings" >&2
    ALL_PASS=0
fi

# M4: exclude manifest and summary-final from inventory
{
    echo "S64 v1.42 — Evidence Manifest"
    echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
    echo "generated_utc=$STAMP"
    echo "host=$(uname -a)"
    echo "gcc=$(gcc --version | head -1)"
    echo "mariadb=$(mysql_scalar 'SELECT VERSION()')"
    echo
    echo "=== Batch summaries (verbatim) ==="
    for name in fast ct07 ct08; do
        echo "--- $name ---"
        cat "$EVID/BATCH/summary-$name.txt"
        echo
    done
    echo "=== Source hash agreement across batches ==="
    echo "fast: $H_FAST"
    echo "ct07: $H_CT07"
    echo "ct08: $H_CT08"
    echo
    echo "=== File-by-file: path | size | sha256 | mtime_utc ==="
    find "$EVID" -type f \
         ! -name 'EVIDENCE-MANIFEST-*' \
         ! -name 'summary-final.txt' \
         -print0 | sort -z | while IFS= read -r -d '' f; do
        printf '%s | %s | %s | %s\n' \
          "$f" \
          "$(stat -c%s "$f")" \
          "$(sha256sum "$f" | awk '{print $1}')" \
          "$(date -u -r "$f" +%Y-%m-%dT%H:%M:%SZ)"
    done
} > "$MANIFEST"

{
    echo "S64 v1.42 — Final summary"
    echo "pkg=v${S64BT_PKG_VERSION}.r${S64BT_PKG_REVISION} date=$S64BT_PKG_DATE"
    echo "generated_utc=$STAMP"
    echo
    for name in fast ct07 ct08; do
        echo "$name: ${BATCH_PASS[$name]}"
    done
    echo
    if (( ALL_PASS )); then
        echo "OVERALL: 8/8 PASS"
    else
        echo "OVERALL: NOT 8/8"
    fi
} > "$SUMMARY"

{
    echo "final_stamp=$STAMP"
    echo "pkg_version=$S64BT_PKG_VERSION"
    echo "pkg_revision=$S64BT_PKG_REVISION"
    echo "pkg_date=$S64BT_PKG_DATE"
    echo "final_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "overall_pass=$ALL_PASS"
    echo "manifest_path=$MANIFEST"
    echo "manifest_sha256=$(sha256sum "$MANIFEST" | awk '{print $1}')"
    echo "fast_pass=${BATCH_PASS[fast]}"
    echo "ct07_pass=${BATCH_PASS[ct07]}"
    echo "ct08_pass=${BATCH_PASS[ct08]}"
} > "$FINAL_META"

cat "$SUMMARY"
echo
echo "manifest: $MANIFEST"
echo "manifest_sha256: $(sha256sum "$MANIFEST" | awk '{print $1}')"
echo "meta: $FINAL_META"

(( ALL_PASS )) || exit 1
