**Filename:** `QDH-LOGGING-AND-LIFECYCLE.md`
**Created on:** 2026-11-18
**Last modified:** 2026-11-23
**SMART 64-Bit ID Version & Revision:** v1.42 — Version 0, Revision 0010
**Companion Documents:** `QDH-SPECIFICATION.md` (RC2.2, final), `QDH-ERROR-CODES.md` (RC2.2, final), `qdh_schema_postgresql.sql` (RC2.2), `qdh_schema_mysql.sql` (RC2.2), `SPECIFICATION.md` (frozen, final)
**Status:** QDH Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**License:** AGPL3
**Email:** contact@samara.com.bd

---

# QDH Event Logging, Incident Taxonomy & Lifecycle Provenance

## 1. Immutable Audit Trail Architecture

Every QDH event, quarantine trigger, DE watermark verification, HE sanitization action, epoch transition, profile upgrade, and reactivation MUST produce an immutable JSON-structured event persisted to `qdh_audit_events`.

This architecture supports the audit-and-accountability objectives of **NIST SP 800-53** AU-06, AU-10, and AU-12, as described in §6. The hash chain provides tamper-**evidence**; non-repudiation against a privileged database attacker additionally requires external anchoring per §6.4 and `QDH-SPECIFICATION.md` §7.

### 1.1 Hash computation (normative)

Each record `N` in a stream for a given `(Class, Engine)` MUST include `prev_event_hash`, the SHA-256 digest of record `N-1` or the genesis sentinel for the first record, and `event_hash`, the SHA-256 digest of the canonical serialization of the entire event body with the `event_hash` field omitted before serialization.

In notation: `event_hash = SHA256(canonical_json(event_body minus event_hash))`.

The entire body participates, including `event_id`, `stream_seq`, `timestamp_utc`, `event_type`, `generation_epoch`, the `virtual_engine`, `lifecycle`, `watermark_audit`, `incident`, and `diagnostic` objects, and `prev_event_hash`. No field other than `event_hash` is excluded, there is no wrapper object, and there is no outer concatenation of duplicated fields. `event_type` explicitly participates.

An earlier draft defined `event_hash` as an outer concatenation that also included a payload fragment containing the same fields, creating a double-hashing ambiguity. That formulation is withdrawn and MUST NOT be used.

**Canonical bytes are persisted, not reconstructed.** Each record MUST store the exact canonical byte string from which `event_hash` was computed, in a byte-preserving column (`payload_canonical`), together with a JSON projection used only for querying. Re-hashing MUST operate on `payload_canonical` and MUST NOT operate on a database-native JSON representation, because such representations normalise key order and number form and cannot reproduce RFC 8785 output.

### 1.2 Canonical JSON serialization

For deterministic hash computation, the body MUST be serialized per RFC 8785: object keys sorted by Unicode code point; no insignificant whitespace; valid UTF-8 with `/` not escaped; numbers in shortest round-trip decimal form; `null` for absent optional fields rather than omission.

Where this document and RFC 8785 differ, RFC 8785 governs.

**Golden test vectors (mandatory artifact).** A conforming implementation MUST publish `tests/golden/audit_hash_vectors.json` containing at minimum:

- **TC-1:** a minimal `ENGINE_INITIAL_BOUND` body, its canonical bytes, and the expected digest.
- **TC-2:** a `RECLAMATION_COMMITTED` body exercising every nested object, its canonical bytes, and the expected digest.
- **TC-3:** a `FENCING_VIOLATION_BLOCKED` body with non-null error codes, exercising the null-versus-present branch.
- **TC-4:** the genesis record, `stream_seq = 1` with an all-zero `prev_event_hash`, its canonical bytes, and the expected digest.
- **TC-5:** a negative vector whose `event_hash` is deliberately mismatched, expected to fail with `QDH-E011`.

Every reference schema MUST ship a `verify_audit_vector()` helper that consumes these vectors. An implementation in any dialect MUST pass all five vectors, through that helper or an equivalent, before claiming conformance. Absence of either the helper or the vectors in a reference schema is a conformance failure of that schema.

### 1.3 Hash-chain conformance

The `(class_id, engine_id, stream_seq)` uniqueness constraint enforces serialization within a stream but cannot by itself verify that `prev_event_hash` matches the prior record's `event_hash`. Therefore:

- **On append and concurrency.** The application MUST lock the control-table row for the `(Class, Engine)`, read the current maximum `stream_seq` and its `event_hash` within the same serializable transaction, and insert `stream_seq + 1` with `prev_event_hash` equal to that value, or to the genesis sentinel when no prior record exists. On serialization or uniqueness conflict the writer MUST roll back and retry from a fresh read, and MUST NEVER fork `stream_seq`. On an uncertain commit timeout, recovery MUST query by `(class_id, engine_id, event_id)` before retrying so duplicates are never emitted.
- **Database-enforced linkage.** Both reference schemas MUST enforce, in a before-insert trigger, that `stream_seq` is exactly prior plus one, that `prev_event_hash` equals the prior record's `event_hash`, that a genesis record uses the all-zero sentinel, and that every relational column corresponds to the canonical payload per §2.3.
- **What the database does not prove.** The database layer proves **linkage and correspondence**. It does not prove that `event_hash` is the correct digest of the body, because canonical JSON cannot be produced inside the trigger. Hash correctness MUST be verified by the application on append and at every full-chain verification point. Acceptance by a trigger is not evidence of hash validity, and no implementation may claim database-layer hash verification.
- **Verification points.** Full-chain verification MUST occur on service startup before accepting writes, at every incident and reclamation boundary, and on every audit-integrity read by an auditor or diagnostic tool.
- **Adjacent-link verification.** On every ordinary append the implementation SHOULD verify the adjacent link, but is not required to re-verify the full chain on each tail or pagination read.
- **On break.** The implementation MUST emit `QDH-E011` mapping to `S64-E012`, quarantine the affected stream, and MUST NOT proceed with any operation depending on audit integrity until the break is resolved. Recovery is an authorized operator procedure; the recovered chain MUST preserve the existing prefix and MUST be externally anchored before the stream is unquarantined.

### 1.4 Genesis sentinel

The genesis sentinel is exactly 64 lowercase hexadecimal zeros, with no prefix and no ellipsis. It matches the `CHAR(64)` column type in both reference schemas and the digest format used throughout.

### 1.5 Immutability

`qdh_audit_events` rows MUST NOT be updated or deleted. Implementations MUST enforce this at the database layer: PostgreSQL through a before-update-or-delete trigger, MySQL through separate before-update and before-delete triggers plus a restrictive grant model. An implementation that cannot enforce this at the database layer MUST enforce it at the application layer, document the residual risk, and MUST NOT claim full QDH conformance.

### 1.6 Structured error surface

Database triggers MUST NOT rely on free-text parsing by the boundary adapter. Both reference schemas emit eight fields in a stable order:

`qdh_code | s64_code | operation_class | class_id | engine_id | local_id | generation_epoch | human_message`

PostgreSQL raises a SQLSTATE-coded exception with a `DETAIL` JSON object carrying the same eight fields. MySQL uses `SIGNAL` with `MESSAGE_TEXT` set to a `|`-delimited string in the same order. `human_message` is never machine-parsed. SQLSTATE class assignments are declared in each schema header and versioned with this document.

## 2. Canonical event schema

### 2.1 Normal state-transition event

The body contains: `event_id`, a UUID; `stream_seq`; `timestamp_utc`, in ISO-8601 UTC with microsecond precision; `event_type`; `generation_epoch`; `virtual_engine` with `class_id` and `engine_id`; `lifecycle` with `previous_state`, `new_state`, `epoch_before`, `epoch_after`, `profile_before`, `profile_after`; `watermark_audit` with `prior_consumed_max`, `durable_lease_ceiling`, `verified_first_never_consumed_local`; `incident` with `incident_id`, `trigger_class`, `physical_node_before`, `physical_node_after`, `he_attestation_digest`; `diagnostic` with `qdh_code`, `s64_code`, `orchestrator_node`; and `prev_event_hash`.

`event_hash` is absent from the body. It is computed over the body, stored in its column, and omitted again on every verification.

### 2.2 Failed-transition event

A failed transition records the diagnostic codes on the event. `diagnostic.qdh_code` and `diagnostic.s64_code` carry the codes from `QDH-ERROR-CODES.md` and `ERROR-CODES.md` respectively. `watermark_audit.verified_first_never_consumed_local` and `incident.he_attestation_digest` are `null` when not established.

### 2.3 Binding between columns and payload

Every relational column of `qdh_audit_events` MUST be derivable from `payload_canonical` without exception, and no column may exist that is absent from the payload. The bound set is: `class_id`, `engine_id`, `stream_seq`, `event_type`, `generation_epoch`, `timestamp_utc`, `previous_state`, `new_state`, `epoch_before`, `epoch_after`, `profile_before`, `profile_after`, `watermark_verified`, `qdh_error_code`, `s64_error_code`, and `prev_event_hash`.

`diagnostic.orchestrator_node` and the `incident` fields have no separate columns and MUST remain payload-only.

`generation_epoch` is a top-level field reflecting the resulting epoch, equal to `lifecycle.epoch_after`. `event_type` is a top-level field and is hashed. `epoch_before` and `epoch_after` are separate transition metadata, both present and both hashed.

## 3. Mandatory event types

Every conforming implementation MUST emit at least the following twelve event types. Additional types MAY be emitted, each conforming to §2 and registered in `event_type_registry`. The `event_type` column is a foreign key to that registry, so unregistered values cannot be stored.

| `event_type` | Description | Emitted at |
|---|---|---|
| `ENGINE_INITIAL_BOUND` | Genesis binding at `generation_epoch = 1`, `local_watermark = 0`. | Initial binding |
| `NODE_QUARANTINE_TRIGGERED` | Node-wide blast-radius quarantine initiated. | Phase 1, once per affected engine |
| `DE_WATERMARK_VERIFIED` | Durable lease and tombstone audit completed. Required evidence before `STATE_HE_SANITIZING`. | Phase 2 |
| `HE_SANITIZATION_ATTESTED` | Sanitization verification, memory zeroing, and attestation passed. Required evidence before `STATE_RECLAIM_COMMIT`. | Phase 3 |
| `RECLAMATION_COMMITTED` | Atomic epoch increment and lineage append completed. | Phase 4 |
| `ALLOCATOR_LEASE_ISSUED` | New epoch-fenced allocator lease granted. MUST precede `ENGINE_REACTIVATED`. | Phase 5 |
| `ENGINE_REACTIVATED` | Engine transitioned to `STATE_ACTIVE`. | Phase 5 |
| `FENCING_VIOLATION_BLOCKED` | Stale allocator write rejected. | Any phase |
| `ENGINE_EXHAUSTED_ROLLOVER` | Namespace exhausted and the lowest eligible forward Engine safely reserved. | Phase 2 or later |
| `ENGINE_EXHAUSTED_TERMINAL` | Namespace exhausted and no eligible higher Engine remains. | Phase 2 or later |
| `ENGINE_RETIRED_PERMANENT` | Permanent retirement. | Any phase |
| `PROFILE_UPGRADED` *(new)* | Explicit profile upgrade under `SPECIFICATION.md` §13.1; records `profile_before`, `profile_after`, and the closed generation. | Profile upgrade |

`ENGINE_REACTIVATED` is distinct from `ALLOCATOR_LEASE_ISSUED`: the lease establishes authority, the reactivation is the externally observable transition. Both MUST be emitted in that order, and out-of-order emission is `QDH-E017`.

`ENGINE_EXHAUSTED_ROLLOVER` and `ENGINE_EXHAUSTED_TERMINAL` are distinct: the first records a successful reservation, the second records pool-wide exhaustion. Both may be emitted for the same engine at different points in the pool's lifecycle.

`PROFILE_UPGRADED` is the closing event for a `PROFILE_UPGRADE` generation. It MUST NOT be emitted by a reclamation cycle.

**Operator-defined extensions.** An operator MAY register additional types with `is_core = FALSE`. The twelve mandatory types are seeded with `is_core = TRUE` and cannot be removed or renamed. Operator-defined types MUST conform to §2 and be approved by the operator's governance before insertion.

## 4. Lineage append-only entry format

Each element of the control-table `lineage` MUST contain:

| Field | Type | Description |
|---|---|---|
| `generation_epoch` | integer | The generation epoch that the entry closes. |
| `profile_version_revision` | string | The profile under which that generation operated. |
| `local_start` | integer | First Local coordinate addressable in that generation: `0` for the first generation, otherwise the prior `local_end_watermark`. |
| `local_end_watermark` | integer | Exclusive upper bound of consumed or leased coordinates in that generation. |
| `physical_node_id` | string | Node that hosted the generation. |
| `opened_at_utc` | timestamp | Start of generation. |
| `closed_at_utc` | timestamp | End of generation. |
| `closure_reason` | enum | One of `FAIL_HARD_RECLAIMED`, `NODE_REFURBISHMENT`, `EXHAUSTED`, `PROFILE_UPGRADE`. |
| `closing_audit_event_id` | UUID | Links to `qdh_audit_events.event_id`; verified by the schema. |

A reclamation cycle MAY record only the first three closure reasons. `PROFILE_UPGRADE` is recorded exclusively by the core §13.1 procedure, whose closing event is `PROFILE_UPGRADED`; it is not a reclamation and MUST NOT be recorded as one.

The lineage is append-only. Existing entries MUST NOT be rewritten or pruned while any identifier from a prior generation remains subject to retention.

**Referential linkage.** Each `closing_audit_event_id` MUST reference an existing audit row that: exists; has an `event_type` in `RECLAMATION_COMMITTED`, `ENGINE_EXHAUSTED_ROLLOVER`, `ENGINE_EXHAUSTED_TERMINAL`, `ENGINE_RETIRED_PERMANENT`, or `PROFILE_UPGRADED`; matches `(class_id, engine_id)`; and has `generation_epoch` equal to the entry's `generation_epoch`. A dangling or mismatched reference raises `QDH-E005`.

## 5. Incident taxonomy

`incident.trigger_class` carries a stable token. The following are reserved and MUST NOT be redefined:

| Token | Meaning |
|---|---|
| `FAIL_HARD_POWER_LOSS` | Power cut or power-loss event. |
| `FAIL_HARD_HARDWARE_FAULT` | Hardware fault or failure. |
| `FAIL_HARD_STORAGE_STALL` | Storage stall affecting authoritative state. |
| `FAIL_HARD_SPLIT_BRAIN` | Heartbeat loss indicative of split-brain. |
| `DE_EVIDENCE_INSUFFICIENT` | DE could not establish a safe watermark. |
| `DE_TOMBSTONE_GAP` | DE detected a missing or out-of-range tombstone. |
| `DE_PROFILE_MISMATCH` | DE detected conflicting profile evidence. |
| `HE_SANITIZATION_FAILED` | HE failed verification or attestation. |
| `HE_ATTESTATION_REPLAYED` | HE rejected a replayed nonce, expired certificate, stale revocation check, or non-allowlisted digest. |
| `FENCING_VIOLATION` | Stale allocator write or lease renewal blocked. |
| `MANUAL_OVERRIDE_ATTEMPT` | Unauthorized manual override attempted. |
| `AUDIT_CHAIN_BREAK` | Audit hash-chain integrity failure. |
| `EVIDENCE_BINDING_MISSING` | Transition attempted without required prior evidence. |
| `PHASE5_ORDERING_VIOLATION` | Phase 5 events emitted out of order. |
| `LIFECYCLE_TRANSITION_REJECTED` *(new)* | Transition not permitted by the state machine. |
| `ENGINE_NOT_FOUND` *(new)* | `(Class, Engine)` did not resolve during a QDH operation. |
| `RANGE_INVALID` *(new)* | Engine or Local coordinate out of range, or below the watermark floor. |
| `HOST_UNFIT` *(new)* | Binding, allocation, or reactivation attempted on a non-active node. |
| `PROFILE_UPGRADE` *(new)* | Explicit profile upgrade under core §13.1. |

Tokens are enforced by an `incident_trigger_class` registry table with a foreign key from the payload projection, so an unregistered token cannot be stored. Additional tokens MAY be defined by an operator's governance and MUST be registered before use.

## 6. International standards alignment

| Domain | Standard | Relationship |
|---|---|---|
| Audit content | **NIST SP 800-53** AU-12 | §3 and §2 capture event type, timestamp, source, and outcome. |
| Audit review | **NIST SP 800-53** AU-06 | The hash chain supports after-the-fact review; read access is not a substitute for immutability. |
| Non-repudiation | **NIST SP 800-53** AU-10 | The hash chain provides tamper-evidence; external anchoring per §6.4 is required for non-repudiation. |
| Deterministic serialization | **RFC 8785** | §1.2. |
| Key management | **NIST SP 800-57 Part 1** | Where events are signed by the orchestrator, signing-key lifecycle follows the standard. |
| Asset inventory and duties | **ISO/IEC 27001:2022** A.5.3, A.5.9 | Role separation and the authoritative chain of engine records. |

Edition and publication dates MUST be verified before final release. Where an operator's policy imposes stricter requirements, the stricter requirement governs.

### 6.4 External anchoring

A conforming implementation MUST: at least daily or per operator governance, compute a root hash over all per-engine stream head `event_hash` values, canonicalised per RFC 8785 and sorted by `(class_id, engine_id)`; publish that root hash to an anchor outside the database superuser's trust boundary; record the anchor URI, digest, and timestamp in `audit_anchors`; and require a matching anchor on any integrity verification request.

Absence of a matching anchor downgrades the assurance claim from "non-repudiation" to "tamper-evident within the database trust boundary."

### 6.5 Retention, archival, and restore verification

A conforming implementation MUST define and enforce: a retention period no shorter than `SPECIFICATION.md` §10.3, enforced by append-only, delete-prohibited storage; archival copies that preserve the full body including `prev_event_hash` and `event_hash`, verified by spot-check re-hashing against the anchor, inheriting all immutability and anchoring requirements; re-verification of the full chain and of head hashes against the most recent anchor before any restored database is placed in service, with mismatch as `QDH-E011` blocking service; and anchor retention at least as long as the events they anchor.

## 7. Conformance

A conforming implementation MUST:

- Emit immutable, hash-chained events per §1 and §2.
- Compute `event_hash` exactly per §1.1 and persist the canonical bytes it was computed from.
- Use RFC 8785 serialization per §1.2 and pass all five golden vectors in every target dialect, with `verify_audit_vector()` present in each reference schema.
- Enforce chain linkage at the database layer per §1.3, and verify hash correctness at the application layer and at every full-chain verification point.
- Consume the eight-field structured surface of §1.6, never SQL message text.
- Use the genesis sentinel of §1.4 for `stream_seq = 1`.
- Register event types in `event_type_registry` and emit at least the twelve mandatory types of §3, including `ALLOCATOR_LEASE_ISSUED` before `ENGINE_REACTIVATED`, the distinction between the two exhaustion events, and `PROFILE_UPGRADED` for core §13.1 upgrades.
- Append lineage entries per §4, with a `closure_reason` from the stated enum, `PROFILE_UPGRADE` used only by the upgrade procedure, and a `closing_audit_event_id` verified against a matching event.
- Bind every column to the canonical payload per §2.3, with no column outside the payload.
- Use only registered `trigger_class` tokens per §5.
- Preserve immutability of events and lineage per §1.5 and `SPECIFICATION.md` §6.3.1.
- Anchor root hashes externally per §6.4, or explicitly disclaim AU-10 non-repudiation.
- Enforce retention, archival, restore, and anchor policies per §6.5.

An implementation that cannot satisfy an applicable logging, hash-integrity, canonicalization, immutability, event-type completeness, binding, or anchoring requirement MUST NOT claim QDH logging conformance.

## 8. Change Log

| Revision | Date | Change |
|---|---|---|
| RC1 | 2026-11-18 | Initial logging and lifecycle specification. |
| RC2 | 2026-11-20 | Closed X-006, X-008, X-009, X-010, N-04, N-08, N-13, N-14, S-003, S-004, S-005. Added golden vectors, database-layer linkage, structured error surface, lineage linkage, event-type registry, new trigger classes, external anchoring, retention and restore verification. |
| RC2 (final) | 2026-11-23 | Added `payload_canonical` byte-preserving storage and a closed column-to-payload binding list (§1.1, §2.3). Corrected the claim that the database proves hash correctness; it proves linkage only (§1.3). Made `verify_audit_vector()` and the golden vectors mandatory schema artifacts (§1.2). Standardized the structured surface at eight fields (§1.6). Added `PROFILE_UPGRADED` as a twelfth mandatory event type (§3) and `PROFILE_UPGRADE` to the closure-reason enum (§4), restricted to the core §13.1 procedure. Added five trigger-class tokens and an FK-enforced `incident_trigger_class` registry (§5). De-dated standards citations pending verification. |

---
