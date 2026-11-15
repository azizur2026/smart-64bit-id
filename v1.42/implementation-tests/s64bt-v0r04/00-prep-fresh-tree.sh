#!/usr/bin/env bash
# 00-prep-fresh-tree.sh - verify the package is ready to run.
# S64BT Package Version: 0
# S64BT Package Revision: 04
# S64BT Package Date: Nov 14, 2026
# Verifies: config present, version headers consistent, MariaDB reachable.

set -euo pipefail
cd "$(dirname "$0")"

echo "===== 00-prep-fresh-tree ====="
echo "dir:  $(pwd)"
echo "utc:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Load config
if [[ ! -f s64bt.config ]]; then
    echo "MISSING: s64bt.config" >&2
    exit 1
fi
# shellcheck disable=SC1091
source s64bt.config
echo "package: v${PKG_VERSION}.r${PKG_REVISION} (${PKG_DATE})"

# Required files (all must have version header)
required_files=(
    lib.sh
    01-run-dry.sh
    02-run-fast-tests.sh
    03-run-ct07.sh
    04-run-ct08-verify.sh
    05-run-final-manifest.sh
    gcc/CT-01-bit-encoding.c
    gcc/CT-02-local-id-boundary.c
    gcc/CT-03-engine-uniqueness.sql
    gcc/CT-04-cross-engine-isolation.sql
    gcc/CT-05-profile-validation.c
    gcc/CT-06-class-consistency.sql
    gcc/CT-07-concurrent-allocation.c
    gcc/CT-07-disposable-schema.sql
    gcc/CT-08-persistence.sh
    gcc/db-schema.sql
)

missing=()
for f in "${required_files[@]}"; do
    [[ -f "$f" ]] || missing+=("$f")
done
if (( ${#missing[@]} )); then
    echo "MISSING files:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

# Version header check — every file must declare the current package version
echo "checking version headers..."
bad_version=()
for f in "${required_files[@]}"; do
    if ! grep -qE "S64BT Package Version: ${PKG_VERSION}" "$f" 2>/dev/null; then
        bad_version+=("$f (missing version)")
        continue
    fi
    if ! grep -qE "S64BT Package Revision: ${PKG_REVISION}" "$f" 2>/dev/null; then
        bad_version+=("$f (missing revision)")
        continue
    fi
done
if (( ${#bad_version[@]} )); then
    echo "VERSION HEADER MISMATCH:" >&2
    printf '  %s\n' "${bad_version[@]}" >&2
    exit 1
fi
echo "  all files carry v${PKG_VERSION}.r${PKG_REVISION}"

# Directory structure
mkdir -p "$EVIDENCE_DIR/BATCH"
mkdir -p "$EVIDENCE_DIR"/CT-0{1,2,3,4,5,6,7,8}
mkdir -p "$EVIDENCE_DIR/ENV"

chmod +x 01-run-dry.sh 02-run-fast-tests.sh 03-run-ct07.sh \
         04-run-ct08-verify.sh 05-run-final-manifest.sh \
         gcc/CT-08-persistence.sh

# Load lib for mysql_require
# shellcheck disable=SC1091
source ./lib.sh
mysql_require || exit 1

echo "MariaDB reachable at $S64_DB_SOCKET as $MYSQL_USER"
echo "Server version: $(mysql_scalar 'SELECT VERSION()')"
echo "gcc: $(gcc --version | head -1)"
echo "Ready."
