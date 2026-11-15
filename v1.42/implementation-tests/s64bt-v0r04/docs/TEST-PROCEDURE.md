# S64BT v0.r04 — Test Procedure

S64BT Package Version: 0
S64BT Package Revision: 04
S64BT Package Date: Nov 14, 2026

This document describes how each of the eight implementation-test gates
works, how it validates, and what evidence it produces.

## 1. Overall flow

The package runs in seven numbered stages (0 through 6), orchestrated by
the `run-*.sh` scripts sourced from `lib.sh` and configured by `s64bt.config`:

| Step | Script | Purpose | Evidence produced |
|---|---|---|---|
| 0 | `00-prep-fresh-tree.sh` | Validate config, version headers, MariaDB reachability | `gcc/evidence/ENV/` |
| 1 | `01-run-dry.sh` | Full machinery dry run, no evidence | none (logs to `/tmp`) |
| 2 | `02-run-fast-tests.sh` | CT-01 through CT-06 | `gcc/evidence/CT-0{1..6}/`, `summary-fast.txt` |
| 3 | `03-run-ct07.sh` | CT-07 plus CT-08 baseline capture | `gcc/evidence/CT-07/`, `CT-08/baseline.txt` |
| 4 | (operator) | Restart MariaDB | uptime reset, proven by CT-08 verify |
| 5 | `04-run-ct08-verify.sh` | CT-08 verify | `gcc/evidence/CT-08/` |
| 6 | `05-run-final-manifest.sh` | Combine summaries | `EVIDENCE-MANIFEST-*.txt`, `summary-final.txt`, `META-final.txt` |

## 2. Configuration

All parameters are in `s64bt.config`. No test reads environment variables
for its parameters except via `lib.sh`.

| Key | Purpose |
|---|---|
| `PKG_VERSION`, `PKG_REVISION`, `PKG_DATE` | Test-package version (not the identifier format version) |
| `DB_CONTROLLER` | Only `mysql` is implemented; `postgresql` is reserved and rejected |
| `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_SOCKET` | MySQL connection |
| `DB_NAME_TEST` | Default `s64_test` |
| `DB_NAME_CT07` | Default `s64_ct07_disposable` |
| `DB_NAME_DRYRUN_PREFIX` | Default `s64_dryrun_` |
| `CT07_WORKERS` | Workers for CT-07 (default 1000) |
| `CT07_OPS_PER_WORKER` | Operations per worker (default 100) |
| `CT07_CLASS_ID` | Class value for CT-07 (default 1) |
| `EVIDENCE_DIR` | Evidence root (default `gcc/evidence`) |

## 3. Common infrastructure

`lib.sh` provides:

- `mysql_require`, `mysql_run`, `mysql_scalar` — connection helpers
- `compile_c_test` — compiles a C test with `-std=c11 -O3 -Wall -Wextra -Werror`
- `assert_counts` — verifies per-assertion counts from a C test's log
- `write_env_meta` — writes `META-*.txt` with package harness hashes (18 files), test-source hashes (10 files), and environment details
- `source_hashes` — extracts test-source hash block
- `require_pass` — validates a batch summary against its log (fails closed on empty log)
- `dryrun_db_name` — constructs the dry-run database name

All test scripts print a version header line in their summaries:
`pkg=v0.r04 date=Nov 14, 2026`.

## 4. Per-gate procedure

### CT-01 — Bit encoding and decoding

**Source:** `gcc/CT-01-bit-encoding.c`

**Procedure:** build and run. The C test:
- encodes and decodes 4 canonical vectors with independent expected constants
- 8 v1.42 vectors (Version=0, Revision=0010), one per Class
- 4 cross-version structural vectors (Revision 0, 1, 2, 15)
- 2,048 boundary cases (Class 1–8 × Role 0–1 × Revision 0–15 × Engine {0, MAX} × Local {0, MAX} × Version {0, 1})
- 1,000,000 random cases with both Version values

**Assertion output:** one line per assertion: `CT-01: assertion N PASS|FAIL`.

**Validation:** `assert_counts` requires exactly 18 per-assertion lines, all PASS.

**Evidence:** `gcc/evidence/CT-01/run.log`, `compile.log`.

### CT-02 — Local ID boundary

**Source:** `gcc/CT-02-local-id-boundary.c`

**Procedure:** build and run. The C test validates 5 valid values (0, 1, MAX−2, MAX−1, MAX) and 4 invalid values (MAX+1, MAX+2, UINT32_MAX, UINT64_MAX) against `test_local_valid_local_id()`.

**Assertion output:** one line per assertion: `CT-02: assertion N PASS|FAIL`.

**Validation:** `assert_counts` requires exactly 9 per-assertion lines, all PASS.

**Evidence:** `gcc/evidence/CT-02/run.log`, `compile.log`.

### CT-03 — Engine uniqueness

**Source:** `gcc/CT-03-engine-uniqueness.sql`

**Procedure:** the runner builds the SQL by substituting placeholders (`__ENGINE_ID__`, `__S64_A__`, `__S64_B__`) into the source. The SQL runs inside a transaction that:
- inserts a physical engine and an allocation
- attempts a duplicate (engine_id, local_id) insert — must be rejected
- attempts a duplicate s64_id at a different local_id — must be rejected
- attempts a duplicate physical_engine engine_id — must be rejected
- verifies the surviving allocation row
- rolls back and verifies rollback

**Assertion output:** six boolean rows (`0` or `1`), one per assertion.

**Validation:** the runner requires:
- the log contains `assertions=6 passed=6`
- exactly 6 boolean rows exist
- zero `0` rows exist

**Evidence:** `gcc/evidence/CT-03/CT-03-run.sql`, `run.log`.

### CT-04 — Cross-engine bit separation

**Source:** `gcc/CT-04-cross-engine-isolation.sql`

**Procedure:** the runner executes the SQL directly. It sets variables, builds two S64 identifiers with identical Class/Role/Version/Revision but different Engine, and runs eight expression-level assertions:
- the two IDs are distinct
- Engine_a decodes correctly
- Engine_b decodes correctly
- Local_a decodes correctly
- Local_b decodes correctly
- Reserved bits a are zero
- Reserved bits b are zero
- both IDs are distinct and non-zero

**Assertion output:** eight boolean rows.

**Validation:** the runner requires:
- the log contains `assertions=8 passed=8`
- exactly 8 boolean rows exist
- zero `0` rows exist

**Evidence:** `gcc/evidence/CT-04/run.log`.

### CT-05 — Profile identification, error codes, precedence

**Source:** `gcc/CT-05-profile-validation.c`

**Procedure:** build and run. The C test exercises the test-local `s64_error()` function against 36 cases:
- 16 positive (all 8 Classes × 2 Roles) — expect no error
- 5 wrong profile (Version≠0 or Revision≠0010) — expect S64-E002
- 2 reserved bits nonzero — expect S64-E003
- 1 Class 0 — expect S64-E004
- 7 Class 9–15 — expect S64-E005
- 5 precedence cases (multi-defect) — expect the earlier-stage code

**Assertion output:** one line per assertion.

**Validation:** `assert_counts` requires exactly 36 per-assertion lines, all PASS.

**Evidence:** `gcc/evidence/CT-05/run.log`, `compile.log`.

### CT-06 — Authoritative Class consistency

**Source:** `gcc/CT-06-class-consistency.sql`

**Procedure:** the runner substitutes placeholders for physical/virtual engine fixture IDs and executes the SQL inside a transaction. It:
- inserts a matching physical/virtual pair — attachment must succeed
- inserts a mismatched physical/virtual pair — virtual must go INACTIVE, physical QUARANTINED, request REJECTED
- rolls back and verifies all fixture rows removed

**Assertion output:** eight boolean rows.

**Validation:** the runner requires:
- the log contains `assertions=8 passed=8`
- exactly 8 boolean rows exist
- zero `0` rows exist

**Evidence:** `gcc/evidence/CT-06/CT-06-run.sql`, `run.log`.

### CT-07 — Concurrent allocation

**Source:** `gcc/CT-07-concurrent-allocation.c`

**Procedure:** build and run with `--i-understand-disposable-db`. The C test:
- provisions a fresh Engine ID in `s64_ct07_disposable` via `MAX(engine_id)+1` under a `GET_LOCK` advisory lock
- reads workers, ops per worker, class from `s64bt.config`
- starts `workers` POSIX threads, each performing `ops` allocation transactions
- each transaction: `SELECT ... FOR UPDATE` on `engine_counter`, `UPDATE`, `INSERT`, `COMMIT`

**Assertion output:** six lines of human-readable metrics plus `assertions=6 passed=6`.

**Validation:** the runner requires (per FIX M2):
- `Workers created: N` equals `CT07_WORKERS`
- `Expected allocations: N` equals workers × ops
- `Successful allocations: N` equals expected
- `Failed allocations: 0`
- `Rows with wrong encoding: 0`
- `assertions=6 passed=6`

Plus `CT-08 baseline` captured automatically (fail-closed).

**Evidence:** `gcc/evidence/CT-07/run.log`, `engine-id.txt`, `database-setup.log`, plus `CT-08/baseline.txt`.

### CT-08 — Persistence across controlled restart

**Source:** `gcc/CT-08-persistence.sh`

**Procedure:**
- `baseline` phase: capture aggregate snapshot of the CT-07 engine
- operator restarts MariaDB
- `verify` phase: capture snapshot again, compare, require identical and uptime decreased

**Assertion output:** `comparison=PASS` plus uptime baseline/recovery.

**Validation:** the runner calls `04-run-ct08-verify.sh`, which invokes the script and requires exit 0.

**Evidence:** `gcc/evidence/CT-08/baseline.txt`, `recovery-results.txt`, `verify-command.log`.

## 5. Validation gates

Each gate validates independently and exits on failure. The final manifest
re-validates each batch's log before emitting `OVERALL: 8/8 PASS`.

- C tests: `assert_counts` reads per-assertion lines, not the summary line
- SQL tests: strict boolean check, no `0` allowed
- CT-07: six metrics validated from `run.log`
- CT-08: `comparison=PASS`
- Manifest: batch logs and harness hash blocks cross-checked

## 6. Evidence integrity

Each `META-*.txt` file records:
- package version
- environment
- 18 package harness hashes (config + lib + all runners)
- 10 test-source hashes

The three batches (fast, CT-07, CT-08) must record identical harness hash
blocks. The final manifest (`05`) cross-checks them.

## 7. How to reproduce

The full procedure is documented in this package's `README.md` (step-by-step).
See also `docs/LIMITATIONS.md` for the environment requirements and the
post-run hardening disclosure.
