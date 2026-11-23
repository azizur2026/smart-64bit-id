# S64BT v0.r04 — Verification Note

S64BT Package Version: 0
S64BT Package Revision: 04
S64BT Package Date: Nov 14, 2026

Evidence manifest: gcc/evidence/BATCH/EVIDENCE-MANIFEST-20261115T112515Z.txt
Manifest SHA-256: 395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e
SHA256SUMS.txt SHA-256: recorded in the external sidecar `SHA256SUMS.txt.sha256`, generated after the publication documentation was finalized. The frozen evidence manifest does not attest this package-level checksum file.

## 1. The claim

S64BT v0.r04 completed its eight implementation-test gates successfully in
the reported run, within the explicitly disclosed test scope.

That is the claim. Nothing broader. See `docs/LIMITATIONS.md` for the scope.

## 2. Results from the recorded run

| Gate | Result | Assertions |
|---|---|---|
| CT-01 | PASS | 18 / 18 |
| CT-02 | PASS | 9 / 9 |
| CT-03 | PASS | 6 / 6 (strict) |
| CT-04 | PASS | 8 / 8 (strict) |
| CT-05 | PASS | 36 / 36 |
| CT-06 | PASS | 8 / 8 (strict) |
| CT-07 | PASS | 6 / 6 (six-metric log validation) |
| CT-08 | PASS | comparison=PASS |

Overall: **8/8 PASS**.

CT-07 measurements from the recorded run:
- 1,000 workers, 100,000 allocations attempted, 100,000 successful
- 0 failed, 0 retries, 0 duplicate-key errors, 0 connection failures
- 100,000 distinct S64 IDs, min local 1, max 100,000, next 100,001
- **Rows with wrong encoding: 0**
- Elapsed approximately 914 seconds on the recorded hardware
- Observed rate approximately 109 successful allocations per second

CT-08 measurements from the recorded run:
- Aggregate snapshot identical before and after controlled MariaDB restart
- MariaDB uptime reset from 2,079 s to 3 s — restart proven
- `comparison=PASS`

## 3. Environment

Recorded in `META-fast.txt`, `META-ct07.txt`, `META-ct08.txt`:

- Host: Linux `aziz-ZenBook-UX363JA-UX363JA`, kernel `5.15.0-139-generic` (Ubuntu 20.04)
- GCC: 9.4.0-1ubuntu1~20.04.2
- MariaDB: 10.4.32-MariaDB, InnoDB, XAMPP at `/opt/lampp`
- Database controller: `mysql` (config `DB_CONTROLLER=mysql`)
- `max_connections=2048` for the CT-07 run
- Client `ulimit -n=8192` for the CT-07 run

## 4. Integrity anchors

- Evidence manifest: `gcc/evidence/BATCH/EVIDENCE-MANIFEST-20261115T112515Z.txt`
- Manifest SHA-256: `395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e`
- Package `SHA256SUMS.txt`: its current digest is recorded in the external sidecar `SHA256SUMS.txt.sha256`. The frozen evidence manifest covers `gcc/evidence/` only (31 files) and does not attest the package checksum file as it existed at the original test run.
- Evidence files: 31
- `META-final.txt`: `overall_pass=1`, all three batches passed
- Recorded harness hash block (identical across fast/ct07/ct08): `8c505f38…`
- Recorded test-source hash block (identical across fast/ct07/ct08): `c46267ed…`
- Current hardened harness hash: `251da7e8…` (differs because of post-run hardening)

## 5. Recorded harness and current harness

The three META files record matching harness hash blocks (`8c505f38…`) and
matching test-source hash blocks (`c46267ed…`). The recorded test-source
hashes match the current test-source files on disk — meaning the test logic
that produced the 8/8 result is unchanged.

The current hardened harness hash (`251da7e8…`) differs from the recorded
harness because of the post-run hardening described in §6.

## 6. Post-run Harness Hardening and Evidence Integrity

> The S64BT v0.r04 implementation-test run completed with an overall result
> of 8/8 PASS.
>
> After completion of the run, three evidence-harness improvements were
> implemented:
>
> 1. write_env_meta now fails closed if package hash generation is
>    incomplete or unsuccessful.
> 2. The final manifest now cross-checks package harness hashes across
>    batches and against the current package.
> 3. Missing or empty expected batch logs now cause manifest validation
>    to fail.
>
> These improvements were made after the recorded test run. No test
> workloads were rerun as part of this hardening.
>
> The original batch metadata records matching harness hash blocks across
> the fast, CT-07 and CT-08 batches (8c505f38...). The recorded test-source
> hash blocks also agree across all three batches (c46267ed...), and the
> recorded test-source hashes match the current test-source files.
>
> The current hardened harness has a different hash (251da7e8...) because
> of the post-run changes. It is intended for subsequent runs and is not
> represented as the harness that produced the original results.
>
> The original evidence manifest is retained with SHA-256:
>
> 395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e
>
> The reported 8/8 result applies to the original recorded run and its
> recorded harness. The subsequent hardening improves the reliability of
> future evidence collection and validation; it does not retroactively
> alter or replace the original run evidence.
>
> This verification is limited to the eight implementation-test gates
> and their explicitly documented scope. It does not claim complete S64
> specification conformance or production-source conformance.

## 7. AI-assisted review assessment

An AI-assisted review was conducted using documentation, source excerpts, and command outputs supplied during the review. Tested with the help of the package owner and the AI partner.

Three conditions for release were stated during the review and are honored by this package:

1. Keep the original manifest and metadata unchanged as historical evidence.
2. Identify the hardened harness as a post-run revision, not the run's original harness.
3. Do not describe the 8/8 result as a fresh execution under the hardened harness.

No third full test run was performed. The recorded run is the evidence.

## 8. What this note does not claim

This note does not claim:

- production-source conformance (no production source is present);
- full S64 specification conformance;
- PostgreSQL support (`DB_CONTROLLER=postgresql` is reserved, not implemented);
- power-loss or crash recovery (CT-08 is a controlled restart);
- parallel allocation throughput (CT-07 is a contention test).

See `docs/LIMITATIONS.md` for the full scope statement.

## 9. Document set

| Document | Purpose |
|---|---|
| `docs/VERIFICATION-NOTE.md` | This document — claim, results, disclosure, verdict |
| `docs/LIMITATIONS.md` | Scope statement |
| `docs/TEST-PROCEDURE.md` | How each gate works |
| `docs/EVIDENCE-INDEX.md` | All evidence files with hashes and roles |
| `README.md` | Front door and navigation |

Together these five documents constitute the publication record for
S64BT v0.r04.
