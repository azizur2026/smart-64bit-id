# Response to Technical Review — SMART 64-Bit ID v1.42 RC2.2

**Review under response:** static technical review, verdict "NOT READY FOR RELEASE"
**Response status:** P0 findings, P1 verification work, and second- and third-round findings remediated and verified
**Evidence rule:** every "verified" claim cites a captured artefact under `evidence/`.

## Finding-by-finding

| # | Finding | Sev | Verdict | Remediation | Evidence | Status |
|---|---|---|---|---|---|---|
| F1 | Allocator authorization bypass via caller-writable session variable | P0 | Accepted | Session variable and guard removed from both dialects. The allocator role holds EXECUTE only; INSERT on the three tables is revoked; role privileges are reset with REVOKE ALL on every load because roles outlive the database. Demonstrated end-to-end as the restricted role on both engines: allocation succeeds and returns `1442277780665401344`; identity=1, watermark=1, durable log=1, and one `CONSUMED` tombstone for the same coordinate (SPECIFICATION.md 10.3); a direct INSERT by the same role is denied (`ERROR 1142` / `permission denied`). | evidence/F1-bypass/, evidence/F1-bypass/allocator_path_mysql.log, evidence/F1-bypass/allocator_path_pg.log | **Verified** |
| F2 | SECURITY DEFINER without hardened search_path | P0 | Accepted, extended | All privileged functions pinned to `search_path = pg_catalog, public, pg_temp`; PUBLIC EXECUTE revoked on every function; writing trigger functions made SECURITY DEFINER. | evidence/F2-search-path/ | **Verified** |
| F3 | Quarantine entry point does not satisfy audit obligations | P0 | Accepted | Unused `p_incident_id` removed; the function is documented as a fencing primitive. `qdh_audit_gap` reports any engine quarantined without a `NODE_QUARANTINE_TRIGGERED` event for its **current** generation. Captured run under `SET ROLE s64_auditor_role`: the fence sets the node to `NODE_QUARANTINED`, the control plane propagates it to the engine, `gap_rows=1`; after the epoch-1 event is inserted, `gap_rows=0`. | evidence/F3-quarantine/audit_gap.log | **Verified** |
| F4 | Release checklist entirely unchecked | P1 | Accepted | Split into `RELEASE-CHECKLIST.md` (evidence record, filled from artefacts) and `OPERATOR-CHECKLIST.md` (deployment items, deliberately open). | RELEASE-CHECKLIST.md, OPERATOR-CHECKLIST.md | **Verified** |
| F5 | No executable database test suite | P1 | Accepted | `tests/sql/run.sh` plus `gen_event.py`: 14 scenarios, both engines, fresh database per case. | evidence/B2-conformance/ | **Verified** |
| F6 | Dialect parity unproven | P1 | Accepted | Identical suite executed on both engines; 14/14 each. | evidence/B2-conformance/ | **Verified** |
| F7 | QDH depends on external systems | — | Not a defect | Stated in LIMITATIONS.md section 11 and retained deliberately. | LIMITATIONS.md | No action |

## Defects found by our own suite, not raised by the review

All three are MySQL-only, all three are release-blocking, and any one of them alone
makes the audit trail non-functional on that engine.

| Defect | Symptom | Fix |
|---|---|---|
| Locking read on the table being inserted | `ERROR 1442` on every event; `trg_qae_before_insert` did `SELECT … FOR UPDATE` on `qdh_audit_events` | lock removed; `UNIQUE (class_id, engine_id, stream_seq)` serialises instead, with retry on conflict as `QDH-LOGGING` section 1.3 specifies |
| `CAST` of a `Z`-suffixed timestamp | every §2.1-conformant payload failed column correspondence | replaced with `STR_TO_DATE(..., '%Y-%m-%dT%H:%i:%s.%fZ')` |
| `JSON_UNQUOTE` of JSON `null` returns `'null'`, not `NULL` | every event with no diagnostic code failed correspondence | wrapped in `NULLIF(..., 'null')` |

These were invisible to static review and to a single reading of the trigger. One of our own
tests initially reported a false pass because two different defects emit the same `QDH-E011`;
the assertions now match the failure reason, not just the code.

## Suite results

| Case | Scenario | MySQL | PostgreSQL |
|---|---|---|---|
| C01 | same Local allocated twice | PASS | PASS |
| C02 | allocation after lease revocation | PASS | PASS |
| C03 | allocation after node quarantine | PASS | PASS |
| C04 | reissue of a retired coordinate | PASS | PASS |
| C05 | direct insert as allocator | PASS | PASS |
| C06 | allocation concurrent with quarantine | PASS | PASS |
| C07 | HE phase entered without DE evidence | PASS | PASS |
| C08 | reclamation with a stale watermark | PASS | PASS |
| C09 | lease bound to a non-current epoch | PASS | PASS |
| C10 | audit event with a wrong hash | PASS | PASS |
| C11 | audit event with a broken chain | PASS | PASS |
| C12 | identifier validation order | PASS | PASS |
| C13 | terminal exhaustion, no wraparound | PASS | PASS |
| C14 | stale prior-epoch quarantine event is not accepted as current-epoch evidence | PASS | PASS |

## Residual limitations, stated rather than hidden

- `S64-E006`, `S64-E007` and `S64-E009` are structurally unreachable in the reference schema: Class is part of the primary key and there is exactly one row per coordinate, so a missing, mismatched or duplicate Class record cannot exist. The schema makes those conditions impossible rather than detectable. Implementations storing coordinates differently must still emit them.
- The profile-upgrade path is implemented in `s64_validate` (provenance is compared against the allocation generation) but the end-to-end upgrade sequence is not exercised, because it requires a `PROFILE_UPGRADED` event with a signed canonical body.
- External anchoring, attestation generation, key custody and sanitisation remain outside the package, as documented.

## On the review's scope statement

The reviewed archive contained 39 files and 31 checksums. The frozen RC2.2 set has a different
composition: it adds the QDH documents, both schemas, the executable suite and the evidence bundle,
and contains no implementation-tests artefacts. The two trees cannot be compared by file count.
Findings 1-3 were reproduced against the RC2.2 schemas directly.

## Rule adopted

No control may be enforced by a value the caller can write. Authorization by privileges;
invariants by constraints and triggers; obligations by artefacts whose absence is detectable.

## Second-round findings

| # | Finding | Sev | Verdict | Remediation | Evidence | Status |
|---|---|---|---|---|---|---|
| A | `public` schema left writable by `PUBLIC` | P0 | Accepted | `REVOKE CREATE ON SCHEMA public FROM PUBLIC` and `ALTER SCHEMA public OWNER TO CURRENT_USER` are applied in the PostgreSQL schema after role creation. Captured on a freshly loaded database: neither `PUBLIC` nor the test role holds `CREATE` on `public`; the schema owner retains it. | evidence/A-public-schema/ | **Verified** |
| B | `qdh_audit_gap` could accept a prior epoch's quarantine event | HIGH | Accepted | PostgreSQL already carried the epoch predicate. The view was **absent from `qdh_schema_mysql.sql` entirely** — the first remediation updated only one dialect. Added to MySQL as an anti-join on `generation_epoch`, with read grants; PostgreSQL gained the explicit read grant it was missing because the view is created after the bulk `GRANT ... ON ALL TABLES`. | evidence/B2-conformance/ | **Verified** |
| C | F3 evidence recorded a failed authentication | P0 (evidence integrity) | Accepted | The previous `audit_gap.log` contained `FATAL: password authentication failed` and was correctly rejected. It has been replaced by a successful capture (`exit=0`) executed as `s64_auditor_role` against a freshly created database. | evidence/F3-quarantine/audit_gap.log | **Verified** |
| D | No regression for the epoch-mismatch case | P1 | Accepted | Case C14 added to `tests/sql/run.sh` for both dialects; the full suite is now 14 cases on each engine. | evidence/B2-conformance/ | **Verified** |

### Scope note

`qdh_begin_quarantine(p_node_id text)` fences the node only and writes no audit
event by design; the control plane must propagate the fence to each engine and
insert one `NODE_QUARANTINE_TRIGGERED` event per engine in the same transaction.
The F3 capture reproduces both steps so that `qdh_audit_gap` is shown detecting
the omission rather than a state the function can never produce.

## Third-round findings

| # | Finding | Sev | Verdict | Remediation | Evidence | Status |
|---|---|---|---|---|---|---|
| 1 | C14 tested a mismatched future epoch, not a stale prior-epoch event | P1 | Accepted | C14 rebuilt around the schema-supported path. The engine is advanced to epoch 2 only by appending a lineage entry that closes generation 1 and cites a real epoch-1 `RECLAMATION_COMMITTED` event; a bare `generation_epoch = 2` update is rejected by the control trigger (`QDH-E005`). The case then asserts `qdh_audit_gap = 1` while only the epoch-1 quarantine event exists, and `0` after the epoch-2 quarantine event is inserted. | evidence/B2-conformance/ | **Verified** |
| 2 | Restricted allocator success not demonstrated | P1 | Accepted | `tests/sql/allocator_path.sh` executes the whole path as `s64_alloc`@`localhost` (MySQL) and `s64_alloc_pg` (PostgreSQL) over a real client connection: allocation succeeds, and the same role is denied a direct INSERT. Every invariant is asserted in the script (smart ID, four counts, tombstone coordinate and status, denial) and any mismatch exits non-zero. | evidence/F1-bypass/allocator_path_mysql.log, evidence/F1-bypass/allocator_path_pg.log | **Verified** |
| 3 | Deployment assumptions for search-path hardening undocumented | P2 | Accepted (documentation) | Added a "Deployment assumptions" section to `LIMITATIONS.md`: trusted installer/owner; no `CREATE` for untrusted roles in schemas used by privileged functions; no ownership of privileged functions by application roles; deployment-specific grants audited in addition to defaults. This documents assumptions; it does not claim enforcement. | LIMITATIONS.md | **Verified** |

### Note on the C14 correction

The first version of C14 inserted a `NODE_QUARANTINE_TRIGGERED` event at epoch 2 while
the engine stood at epoch 1. It therefore proved that a future-epoch event is not
accepted as evidence, which is not the defect that was reported. The rebuilt case
keeps a genuine prior-epoch event in place and requires the view to report the
current generation as unaudited. Both directions are asserted, because a single
positive assertion cannot distinguish a correct view from one that reports every
quarantined engine.

### Fixture realism in C14

C14 models the post-reclamation state rather than replaying DE, HE and
RECLAIM_COMMIT. It advances the epoch through the schema-supported path (one
appended lineage entry citing a real epoch-1 RECLAMATION_COMMITTED closing event)
and then applies the universal quarantine transition. The DE and HE evidence gates
are exercised by C07 and by the control trigger; the subject of C14 is the
audit-gap predicate, not the reclamation sequence.
