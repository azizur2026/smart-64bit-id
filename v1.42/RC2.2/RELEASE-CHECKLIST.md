# SMART 64-Bit ID v1.42 RC2.2 — Release Evidence Record

**Profile:** Version 0, Revision 0010
**Status:** Release Candidate 2 — Finalized 2026-11-23
**Nature of this document:** a record of what was executed and what it produced. It is not a
plan and it is not a to-do list. Every row cites an artefact under `evidence/`.

## 1. Package integrity

| Item | Result | Artefact |
|---|---|---|
| SHA-256 manifest over the shipped files | all verify | `SHA256SUMS.txt` |
| Golden audit vectors TC-1..TC-4 | match on both engines | `evidence/B2-conformance/` |
| Golden vector TC-5 | correctly rejected | `evidence/B2-conformance/` |

## 2. Schema build

| Item | Result | Artefact |
|---|---|---|
| MySQL 8.0.16+ builds in one pass on an empty database | exit 0 | `evidence/ENVIRONMENT`, suite logs |
| PostgreSQL 11+ builds in one pass on an empty database | exit 0 | `evidence/B2-conformance/postgresql_suite.log` |

## 3. Conformance suite

14 scenarios, fresh database per case, executed on both engines. See `tests/sql/README.md` for the
case contract and `REVIEW-RESPONSE.md` for the results table. Current result: 14/14 on each engine.

## 4. Security controls

| Control | Verification | Artefact |
|---|---|---|
| Allocator cannot insert identity rows directly | privilege error at the boundary, both engines | `evidence/F1-bypass/` |
| Allocator can still execute its own procedure | reaches procedure preconditions | `evidence/F1-bypass/` |
| Controller-only commit path closed to allocator | permission denied for function | `evidence/F2-search-path/` |
| Privileged functions pinned to a safe search_path | `prosecdef=t`, `search_path` set | `evidence/F2-search-path/` |
| No PUBLIC EXECUTE on privileged functions | eight `REVOKE ... FROM PUBLIC` applied | `evidence/F2-search-path/` |

## 5. Audit floor

| Control | Verification | Artefact |
|---|---|---|
| Event with a wrong hash | rejected at the hash check | `evidence/B2-conformance/mysql_suite.log`, `evidence/B2-conformance/postgresql_suite.log` |
| Event breaking the stream chain | rejected at the linkage check | same |
| Missing per-engine quarantine event | detectable via `qdh_audit_gap` | `evidence/F3-quarantine/` |

## 6. Open items, declared

The following are not complete and are not claimed:

- Profile-upgrade end-to-end sequence (requires a `PROFILE_UPGRADED` event with a signed body).
- External anchoring, attestation generation, key custody, sanitisation execution.
- `S64-E006`, `S64-E007`, `S64-E009` cannot arise in this schema by construction.

## 7. Disposition

**Release decision:** approved for publication as Release Candidate 2, on the evidence above.
**Not approved for production without:** the operator checklist completed in the deployment
environment, and independent review of the residual items in section 6.

**Reviewer:** ____________________  **Date:** ____________________
