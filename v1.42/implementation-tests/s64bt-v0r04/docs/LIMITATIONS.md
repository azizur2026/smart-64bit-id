# S64BT v0.r04 — Limitations

S64BT Package Version: 0
S64BT Package Revision: 04
S64BT Package Date: Nov 14, 2026

This document states exactly what the v0.r04 implementation-test package
proves and what it does not. It is normative for any publication claim.

A reader who takes only one document from this package should take this
one and the VERIFICATION-NOTE.

## 1. What the package is

S64BT v0.r04 is a **narrow, scope-limited implementation-test verification**
of SMART 64-Bit ID (S64) v1.42. It exercises **eight test gates** (CT-01
through CT-08) against a **test-local implementation** and a **schema**.

It is not:

- a specification conformance suite,
- a production-source verification,
- a security review,
- a performance benchmark,
- a claim of production readiness.

## 2. What the eight gates establish

| Gate | What it establishes | Confidence |
|---|---|---|
| CT-01 | 64-bit encoding/decoding round-trips on 1,002,064 cases, of which 16 are independent canonical constants | High for constants; Medium for round-trips |
| CT-02 | A test-local Local-ID validator enforces the 2^29 boundary | High for test-local; not verified for production |
| CT-03 | The database schema enforces `(engine_id, local_id)` uniqueness and `s64_id` uniqueness, and rolls back cleanly | High for schema; not verified for production allocator |
| CT-04 | Engine and Local bit ranges are independently encodable and decodable in single expressions | High for the expression; not verified for persistent isolation |
| CT-05 | A test-local `s64_error()` implements the profile identification and error codes `S64-E002`–`S64-E005` with precedence | High for test-local; not verified for production validator |
| CT-06 | A SQL workflow simulation of Class-consistency handling succeeds and rolls back cleanly | High for the schema; not verified for production Controller |
| CT-07 | A transactional allocation pattern produces 100,000 unique IDs at 1,000 worker threads executing transactions with 0 duplicates and 0 wrong encodings on the tested hardware | High for the measured result; not verified beyond 1,000 workers, other hardware, or production source |
| CT-08 | Committed allocations persist across a controlled MariaDB service restart; restart proven by uptime reset | High for controlled restart; not verified for power loss or crash |

## 3. What the package does not establish

### 3.1 Production-source conformance

**No production source is present.** The tests exercise **test-local code**
(`encode`/`decode`, `valid_local_id`, `s64_error`, the inline CT-07
encoding) and **the database schema**. They do not exercise any shipped
implementation.

If a production implementation exists elsewhere, a separate verification
is required.

### 3.2 Complete specification conformance

This package does not claim complete S64 specification conformance.

The working test-scope assessment identifies 17 of 43 mapped requirements
as fully covered, 6 as partially covered, and 20 as not covered. These
figures are retained as scope indicators only: the corresponding
requirement-to-test matrix (`docs/TRACEABILITY.md`) is not included in
this package, so the mappings and coverage counts cannot be independently
audited from the published artifacts alone.

CT-05 exercises four test-local error paths labelled S64-E002 through
S64-E005. This does not establish production error-handling conformance
or complete error-code coverage.

### 3.3 Lifecycle conformance

Not tested: retirement semantics, coordinate permanence, tombstones,
history chains, atomic activation, migration.

### 3.4 Rollover conformance

Not tested: engine exhaustion, `S64-E022`, `S64-E029`.

### 3.5 Routing conformance

Not tested: virtual-engine table lookups, physical-engine resolution,
`S64-E013`, `S64-E014`.

### 3.6 Durability under failure

CT-08 tests a controlled service restart. It does not test power loss,
crash-during-write, fsync failure, disk full, or network partition.

### 3.7 Concurrency beyond 1,000 workers

CT-07 uses 1,000 worker threads. No claim is made beyond that.

### 3.8 Sustained operation

CT-07 ran for approximately 914 seconds. No claim is made about hours or days.

### 3.9 Multi-engine behavior

CT-07 uses one engine. No claim is made about their interaction.

### 3.10 Production database configuration

CT-07 required `max_connections=2048`, `open_files_limit=10005`, and
client `ulimit -n=8192`. The package does not claim that S64 works under
default MariaDB settings at 1,000 workers.

### 3.11 PostgreSQL support

`DB_CONTROLLER=postgresql` is **reserved but not implemented** in v0.r04.
If set, `lib.sh` rejects the configuration with an explicit error. No
PostgreSQL behavior is tested or claimed.

## 4. Scope of the CT-07 result

CT-07 is a **contention test**, not a parallel-throughput benchmark. All
workers lock the same `engine_counter` row using `SELECT ... FOR UPDATE`,
which serializes the critical allocation step. The recorded run completed
100,000 successful allocations in approximately 914 seconds, with zero
duplicates. This demonstrates that the tested allocation pattern completed
under the recorded contention conditions; it does not establish parallel
allocation throughput or general production performance.

## 5. Scope of the CT-08 result

CT-08 compares an **aggregate snapshot** (row count, distinct count, min/max
local, next counter, server version) before and after a controlled MariaDB
restart. The snapshot is identical and the restart is proven by uptime
reset. This establishes aggregate persistence across a clean restart. It
does not establish per-row record-level verification, and it does not
cover power loss, crash, or arbitrary recovery.

## 6. Version and revision

The version and revision in this package (`v0.r04`) are the **test-package
version**, not the S64 identifier format version. The identifier format's
version for this profile is `Version 0, Revision 0010` (v1.42), as
specified in SPECIFICATION.md.

Both versions coexist without conflict. They are independent namespaces.

## 7. Post-run harness hardening

After the recorded run, three evidence-harness improvements were
implemented:

1. `write_env_meta` now fails closed on incomplete or failed hash generation.
2. The final manifest cross-checks package harness hashes across batches
   and against the current package.
3. Missing or empty expected batch logs cause manifest validation to fail.

These improvements were applied **after** the recorded run. The reported
8/8 result belongs to the harness that was active during the run
(`8c505f38…`), not to the hardened harness (`251da7e8…`). See
`docs/VERIFICATION-NOTE.md` for the full disclosure.

## 8. What the reader should do with this document

When citing this package, state:

- The eight-gate result (8/8 PASS).
- The narrow scope: test-local code and schema, not production source.
- The concurrency bound: 1,000 workers on the recorded hardware.
- The persistence scope: controlled restart, not power loss.
- The absence of PostgreSQL support.
- The post-run harness hardening, if citing evidence-file hashes.

Do not describe the 8/8 result as full S64 specification conformance,
production-source conformance, PostgreSQL support, or power-loss recovery.
