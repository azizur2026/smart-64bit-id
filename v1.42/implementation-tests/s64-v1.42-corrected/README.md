# S64 v1.42 — Corrected implementation-test revision

This directory is a **new corrected test revision** prepared from the supplied `gcc.zip`.
It does not overwrite or replace the original v1.42 test sources, logs, reports, or checksums.

## Important evidence rule

The original eight PASS results remain historical results from the original source revision.
They are not results of these corrected sources. The corrected test runner creates new evidence
under `gcc/evidence/`. Do not merge the old evidence directory into this one.

## Corrections included

- CT-01: adds four independent canonical 64-bit vectors in addition to round-trip tests.
- CT-02: explicitly tests three out-of-range Local ID values against a test-local validation function; this is not a production allocator integration test.
- CT-03: checks the duplicate composite key using a collision-checked fixture ID and rolls
  the transaction back. The runner generates per-run S64 values.
- CT-04: fixes the output-column separation and labels the test as expression-level only.
- CT-05: tests invalid Class 0 and 9, reserved bits, and invalid Version. Role and Revision
  cover all representable bit patterns; those bit widths cannot encode an out-of-range value.
- CT-06: compares actual physical and virtual Class values and rolls back test fixtures.
- CT-07 revision 2: uses a separate database named `s64_ct07_disposable` and provisions a NEW
  unused Engine ID for each run (the next ID after the current maximum in that dedicated database).
  It never reuses Engine 1001 from `s64_test`, deletes allocations, or resets an existing counter.
  Each new test Engine starts at Local ID 1 in the separate disposable database; prior test Engines
  and their evidence remain intact. A database advisory lock serializes Engine provisioning.
- The original `s64_test` Engine 1001 is expected to retain `next_local_id = 100001` based on the
  original CT-07/CT-08 evidence. This corrected CT-07 does not read, reset, or modify that counter.
- Batch runner: records source hashes, environment details, individual logs, batch summary,
  and a fresh evidence checksum manifest.
- CT-08: uses a two-phase snapshot comparison. The operator must restart MariaDB manually
  between `baseline` and `verify`.

## Prerequisites

- Linux, GCC, pthreads.
- MariaDB client and server.
- MariaDB Connector/C development headers and `mysql_config`.
- Database account with privileges to create/use `s64_test` and `s64_ct07_disposable`.
- The configured MariaDB socket must be accessible.

Default client paths match the supplied environment:
`/opt/lampp/bin/mysql` and `/opt/lampp/bin/mysql_config`.

Override paths using `MYSQL_BIN` and `MYSQL_CONFIG` if needed.
Set `MYSQL_USER`, `MYSQL_PWD`, and `S64_DB_SOCKET` when your environment differs.

## Run the corrected test suite

From this `gcc` directory:

```bash
chmod +x run-all-tests.sh CT-08-persistence.sh
./run-all-tests.sh --run-ct07
```

This executes CT-01 through CT-07, captures a CT-08 baseline, and reports CT-08 as
INCOMPLETE pending a manual MariaDB service restart. The runner never restarts MariaDB
automatically.

## Run CT-07 in its dedicated disposable database

```bash
./run-all-tests.sh --run-ct07
```

This creates/uses `s64_ct07_disposable`. The program provisions a new unused Engine ID
inside that dedicated database, starting from the next ID after its current maximum.
The ID is recorded in `evidence/CT-07/engine-id.txt` and is used by CT-08. The program
requires the explicit `--i-understand-disposable-db` confirmation. It never deletes,
truncates, or resets existing data. A successful run leaves its 100,000 allocation records
intact. Subsequent runs provision another Engine ID and leave earlier test records intact.

**Counter separation:** the historical `s64_test` Engine 1001 counter is 100001. This
corrected workload does not use that Engine or counter. The test-local counter starts at 1
only for a newly provisioned Engine in `s64_ct07_disposable`, a separate database namespace.
The generated test IDs are disposable test data and must not be exported or treated as
production allocations.

The CT-07 connection uses:
- `S64_DB_USER` (set from `MYSQL_USER`)
- `S64_DB_PASS` (set from `MYSQL_PWD`)
- `S64_DB_SOCKET` (default `/opt/lampp/var/mysql/mysql.sock`)

## Complete CT-08 controlled-restart verification

After `--run-ct07` completes, the runner captures a CT-08 baseline.
Then restart MariaDB manually using the normal service procedure for your installation.
Do not run a destructive reset.

After the server is back, run:

```bash
./run-all-tests.sh --verify-ct08
```

The verification compares allocation count, distinct ID count, Local ID minimum/maximum,
next counter, and server version against the saved baseline. CT-08 passes only if the
post-restart snapshot matches.

## Evidence and interpretation

- `evidence/CT-*/` contains newly generated logs and run-specific SQL.
- `evidence/ENV/` contains compiler, CPU, OS, and MariaDB server-version records.
- `evidence/BATCH/summary.txt` contains the execution status.
- `evidence/BATCH/SHA256SUMS.txt` covers files generated under `evidence/` at the end
  of that runner invocation.
- `SOURCE-SHA256SUMS.txt` records hashes of source and shell files in this revision.
- A test marked INCOMPLETE is not a PASS.
- The runner has not been executed against your MariaDB server in preparing this package.
  Local database results must be generated on your machine and reviewed before publication.

## Scope caveats

These tests still do not constitute a complete production certification:
- CT-04 is an expression-level encoding check, not a full persistent cross-Engine isolation test.
- CT-06 is a SQL workflow simulation, not a production Controller integration test.
- CT-07 exercises the allocation transaction under concurrent workers in a dedicated test database.
- CT-08 covers a controlled MariaDB service restart, not power loss or arbitrary crash recovery.
- No claim is made about production readiness from these tests alone.
