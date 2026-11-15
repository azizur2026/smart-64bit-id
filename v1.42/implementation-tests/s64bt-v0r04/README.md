# S64BT v0.r04 - Implementation-Test Package

S64BT Package Version: 0
S64BT Package Revision: 04
S64BT Package Date: Nov 14, 2026

## What this is

S64BT v0.r04 is a **narrow, scope-limited implementation-test verification**
of SMART 64-Bit ID (S64) v1.42. It exercises eight test gates (CT-01
through CT-08) against a test-local implementation and a schema.

Result: **8/8 PASS**, in the recorded run, within the disclosed scope.

This is not a specification conformance suite, a production-source
verification, a security review, a performance benchmark, or a claim of
production readiness. See `docs/LIMITATIONS.md` for the complete scope.

## Reading order

Start with these five documents, in order:

1. `docs/VERIFICATION-NOTE.md` - the claim and the evidence
2. `docs/LIMITATIONS.md` - what is not claimed
3. `docs/TEST-PROCEDURE.md` - how each gate works
4. `docs/EVIDENCE-INDEX.md` - every file in the package, with hashes
5. This `README.md` - overview

## Package layout

    s64bt-v0r04/
    ├── s64bt.config                  configuration (single source of truth)
    ├── lib.sh                        shared helpers
    ├── 00-prep-fresh-tree.sh         step 0 - prep and version gate
    ├── 01-run-dry.sh                 step 1 - dry run
    ├── 02-run-fast-tests.sh          step 2 - CT-01..CT-06
    ├── 03-run-ct07.sh                step 3 - CT-07
    ├── 04-run-ct08-verify.sh         step 5 - CT-08 verify (after restart)
    ├── 05-run-final-manifest.sh      step 6 - combine batches
    ├── SHA256SUMS.txt                integrity manifest (23 files)
    ├── README.md                     (this file)
    ├── docs/
    │   ├── VERIFICATION-NOTE.md
    │   ├── LIMITATIONS.md
    │   ├── TEST-PROCEDURE.md
    │   └── EVIDENCE-INDEX.md
    └── gcc/
        ├── db-schema.sql
        ├── CT-07-disposable-schema.sql
        ├── CT-01-bit-encoding.c
        ├── CT-02-local-id-boundary.c
        ├── CT-03-engine-uniqueness.sql
        ├── CT-04-cross-engine-isolation.sql
        ├── CT-05-profile-validation.c
        ├── CT-06-class-consistency.sql
        ├── CT-07-concurrent-allocation.c
        ├── CT-08-persistence.sh
        └── evidence/                 (produced by the recorded run)

## Prerequisites

- Linux (Ubuntu 20.04 was the recorded environment)
- GCC with C11 support (9.4.0 was the recorded compiler)
- MariaDB with InnoDB (10.4.32 was the recorded server)
- MariaDB Connector/C (`mysql_config` on PATH)
- A database account that can create databases

Default paths assume XAMPP at `/opt/lampp`:

- `MYSQL_BIN` default `/opt/lampp/bin/mysql`
- `MYSQL_CONFIG` default `/opt/lampp/bin/mysql_config`
- `MYSQL_USER` default `root`
- `S64_DB_SOCKET` default `/opt/lampp/var/mysql/mysql.sock`

All can be overridden via environment or by editing `s64bt.config`.

## How to run

The full procedure, including CT-08 restart, is:

    # Step 0 - prep
    ./00-prep-fresh-tree.sh

    # Step 1 - dry run (no evidence)
    ./01-run-dry.sh --i-understand-this-is-a-dry-run --keep-dryrun-logs

    # Step 2 - fast batch (CT-01..CT-06)
    ./02-run-fast-tests.sh

    # Step 3 - CT-07 (~15 min)
    ulimit -n 8192
    ./03-run-ct07.sh --i-understand-disposable-db

    # Step 4 - operator restarts MariaDB
    sudo /opt/lampp/lampp stopmysql
    sudo /opt/lampp/lampp startmysql

    # Step 5 - CT-08 verify
    ./04-run-ct08-verify.sh

    # Step 6 - final manifest
    ./05-run-final-manifest.sh

The runner exits non-zero at any failed step. The final manifest refuses
to emit `OVERALL: 8/8 PASS` unless all three batches pass with matching
harness and test-source hashes.

## Version

The version and revision in this package (`v0.r04`) are the
**test-package version**, not the S64 identifier format version. The
identifier format's version for this profile is `Version 0, Revision 0010`
(v1.42), as defined in SPECIFICATION.md.

## Post-run hardening disclosure

After the recorded run, three evidence-harness improvements were applied:

1. `write_env_meta` now fails closed on incomplete or failed hash generation.
2. The final manifest cross-checks package harness hashes across batches
   and against the current package.
3. Missing or empty expected batch logs cause manifest validation to fail.

The reported 8/8 result belongs to the harness active during the recorded
run (`8c505f38...`). The hardened harness (`251da7e8...`) applies to
subsequent runs. See `docs/VERIFICATION-NOTE.md` for the full disclosure.

## AI-assisted review

An AI-assisted review was conducted using documentation, source excerpts, and command outputs supplied during the review. Tested with the help of the package owner and the AI partner.

## Integrity

Verify the package with:

    sha256sum -c SHA256SUMS.txt

All 23 files must report `OK`.

The evidence manifest retains its original SHA-256:

    395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e

## What this package does not claim

- Full S64 specification conformance
- Production-source conformance
- PostgreSQL support (`DB_CONTROLLER=postgresql` is reserved, not implemented)
- Power-loss or crash recovery (CT-08 is a controlled restart)
- Parallel allocation throughput (CT-07 is a contention test)
- Behavior beyond 1,000 worker threads on the recorded hardware
