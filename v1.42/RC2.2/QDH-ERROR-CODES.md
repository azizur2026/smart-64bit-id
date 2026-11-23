**Filename:** `QDH-ERROR-CODES.md`
**Created on:** 2026-11-18
**Last modified:** 2026-11-23
**SMART 64-Bit ID Version & Revision:** v1.42 — Version 0, Revision 0010
**Companion Documents:** `ERROR-CODES.md` (frozen, final), `QDH-SPECIFICATION.md` (RC2.2, final), `QDH-LOGGING-AND-LIFECYCLE.md` (RC2.2, final), `qdh_schema_postgresql.sql` (RC2.2), `qdh_schema_mysql.sql` (RC2.2)
**Status:** QDH Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**License:** AGPL3
**Email:** contact@samara.com.bd

---

# SMART 64-Bit ID v1.42 — QDH & Reclamation Error Codes

## 1. Purpose and relationship to `S64-Exxx`

This registry defines the **20 normative QDH diagnostic error codes (`QDH-E001` through `QDH-E020`)** governing Quarantine, Database Engineering, Hardware Engineering, and Automated Virtual Engine Reclamation.

- **Core boundary codes (`S64-E001`–`S64-E031`):** emitted on external validation, allocation, routing, and administrative interfaces per `ERROR-CODES.md` (frozen, final). This document redefines none of them.
- **Subsystem telemetry codes (`QDH-E001`–`QDH-E020`):** emitted by the QDH policy engine, sanitization workers, and audit subsystem.

**Boundary behaviour.** All 20 QDH codes have a defined `S64-Exxx` mapping for use when the condition crosses an **external caller boundary**. When a QDH condition is observed and handled **entirely within** the QDH subsystem — for example, a routine diagnostic recorded to `qdh_audit_events` without being surfaced to an external caller — the emitter MAY record only the `QDH-Exxx` code and MAY omit the `S64-Exxx` code. The mapping is always available for boundary adapters; it is not always required.

**Detection / triage / emission separation.** The QDH subsystem MUST treat these as distinct:

1. **Detection:** the trigger or worker raises a structured error record containing the `QDH-Exxx` code, `class_id`, `engine_id`, `local_id` where applicable, `generation_epoch`, and `operation_class` (`COMMIT` | `LEASE_RENEWAL` | `RETIREMENT` | `TOMBSTONE_WRITE` | `CONTROL`).
2. **Triage:** the precedence rules of §4 select which code is primary when multiple conditions apply.
3. **Emission:** the boundary adapter maps the primary `QDH-Exxx`, plus `operation_class`, to the correct `S64-Exxx` via §2. For `QDH-E003` and `QDH-E015` this is the only sanctioned way to determine the boundary code.

Boundary adapters MUST NOT infer code mapping from the free text of a database exception message. The structured error record is the interface.

**Structured error surface.** Both reference schemas emit eight fields in a stable order:

`qdh_code | s64_code | operation_class | class_id | engine_id | local_id | generation_epoch | human_message`

PostgreSQL carries this as a `DETAIL` JSON object; MySQL carries it as a `MESSAGE_TEXT` value with `|` delimiters. `human_message` is never machine-parsed. The SQLSTATE class assignments are declared in each schema's header and are versioned with this document.

This registry does not prescribe logging format, transport of errors, retry policy, or user-facing message text.

## 2. Normative QDH error code registry

| QDH Code | Identifier | Mapped `S64` | Trigger condition and normative action |
|---|---|---|---|
| `QDH-E001` | `QDH_TRIGGER_UNVERIFIED` | `S64-E021` | Quarantine or reclamation request lacks cryptographically signed telemetry or a valid node-health proof. Reject the request; maintain `STATE_QUARANTINED`. |
| `QDH-E002` | `QDH_WATERMARK_UNESTABLISHED` | `S64-E021` | DE phase cannot establish the First Never-Consumed Local Coordinate from durable lease and tombstone evidence, and no tombstone gap exists. Halt reclamation; last-ID lookup is forbidden. |
| `QDH-E003` | `QDH_EPOCH_STALE_FENCE` | `S64-E019` for `operation_class = COMMIT`; `S64-E021` for `LEASE_RENEWAL`, `CONTROL`, and `TOMBSTONE_WRITE` | Stale allocator or delayed worker attempted a write using a retired `generation_epoch`. Append-only prior-generation tombstone writes permitted by `SPECIFICATION.md` §10.7.2 are **exempt**; that path sets `operation_class = RETIREMENT` and skips the epoch-match check. |
| `QDH-E004` | `QDH_HARDWARE_SANITIZATION_FAILED` | `S64-E021` | HE phase failed sanitization verification, memory zeroing, attestation, nonce freshness, allowlist match, certificate validity window, or revocation-freshness validation. Mark the node `NODE_UNFIT`; block reactivation on that hardware. |
| `QDH-E005` | `QDH_LINEAGE_MUTATION_ATTEMPT` | `S64-E021` | Attempt to update, truncate, or delete existing entries in the lineage or in `qdh_audit_events`. Block via database trigger; raise a critical alert. **This code MUST NOT be used for any other condition.** |
| `QDH-E006` | `QDH_LAST_ID_INFERENCE_FORBIDDEN` | `S64-E021` | Allocator or recovery script attempted a maximum-Local scan, or equivalent last-ID inference, to determine a post-crash resume point. Abort immediately. |
| `QDH-E007` | `QDH_NODE_BLAST_RADIUS_UNCHECKED` | `S64-E021` | Attempt to bind, allocate on, or reactivate an engine whose hosting node is not `NODE_ACTIVE`. Detected via `physical_nodes.node_state`. |
| `QDH-E008` | `QDH_LEGACY_PROFILE_RECLAIM_FORBIDDEN` | `S64-E002` | Attempt to run QDH reclamation on an engine already permanently retired under pre-v1.42 rules, or to re-enter a key retired outside QDH (`SPECIFICATION.md` §11). **Does not apply** to a v1.41-profile engine operating under v1.42 governance, which is eligible and reissues deterministically under `v1.41`. |
| `QDH-E009` | `QDH_MANUAL_OVERRIDE_REJECTED` | `S64-E021` | Human operator or unauthenticated tool attempted to force a state transition, alter `local_watermark`, advance `generation_epoch`, or bypass quarantine fencing. Reject; raise a security incident. |
| `QDH-E010` | `QDH_TOMBSTONE_GAP_DETECTED` | `S64-E017` | DE audit detected a missing tombstone or retired record required by `SPECIFICATION.md` §10.3, or a tombstone referencing a Local coordinate higher than every other evidence source. Suspend reclamation pending authoritative restore. `QDH-E002` is not emitted alongside this code. |
| `QDH-E011` | `QDH_AUDIT_HASH_CHAIN_BROKEN` | `S64-E012` | `prev_event_hash` verification failed, indicating tampering or corruption. Freeze QDH transitions on the affected stream until resolved. |
| `QDH-E012` | `QDH_CONCURRENT_RECLAMATION_LOCK` | `S64-E020` | Two QDH workers attempted simultaneous reclamation of the same `(Class, Engine)`. Detected via row lock with no-wait semantics, or equivalent. The losing worker aborts and yields immediately. |
| `QDH-E013` | `QDH_POOL_INDEX_DESYNC` | `S64-E021` | The rollover index disagrees with control-table lifecycle state. Halt rollover and rebuild atomically from authoritative evidence; issuance is forbidden during rebuild and last-ID inference is forbidden. |
| `QDH-E014` | `QDH_WATERMARK_REGRESSION` | `S64-E018` | Computed `next_safe_local` is **strictly less than** an established non-reuse floor, prior watermark, or consumed coordinate. **Equality is normal** when a lease ceiling was ahead of actual writes and MUST NOT trigger this code. On strict regression, lock the engine permanently and raise `S64-E018`. |
| `QDH-E015` | `QDH_EVIDENCE_PROFILE_MISMATCH` | `S64-E030` | DE reconciliation found conflicting `allocated_profile` values across the durable log, lease watermarks, tombstones, or the control-table `active_profile` for the same `(class_id, engine_id)`. Halt reclamation; quarantine until authoritative profile evidence is reconciled. |
| `QDH-E016` | `QDH_EVIDENCE_BINDING_MISSING` | `S64-E021` | A state transition into `STATE_HE_SANITIZING` or `STATE_RECLAIM_COMMIT` lacks the required prior audit evidence for the current `generation_epoch`. Block the transition; return to `STATE_QUARANTINED`. **This code MUST NOT be used for an otherwise inadmissible transition.** |
| `QDH-E017` | `QDH_PHASE5_ORDERING_VIOLATION` | `S64-E021` | `ENGINE_REACTIVATED` emitted before `ALLOCATOR_LEASE_ISSUED` for the same `(class_id, engine_id, generation_epoch)`. Block emission. |
| `QDH-E018` | `QDH_LIFECYCLE_TRANSITION_INVALID` *(new)* | `S64-E031` | A requested lifecycle transition is not permitted by the state machine of `QDH-SPECIFICATION.md` §3, or the engine's current state does not admit the requested operation. Reject the transition. |
| `QDH-E019` | `QDH_VIRTUAL_ENGINE_NOT_FOUND` *(new)* | `S64-E013` | A `(Class, Engine)` key does not resolve to a control-table row during a QDH operation. Reject the operation; do not create state implicitly. |
| `QDH-E020` | `QDH_ALLOCATION_RANGE_INVALID` *(new)* | `S64-E023` | Engine or Local coordinate outside `0–2,097,151` or `0–536,870,911`, or a Local coordinate below `next_safe_local`. Reject before any packing, tombstone, or constraint evaluation; a surfaced database constraint violation is non-conforming. |

## 3. Mapping rationale

| QDH Code | `S64` mapping | Rationale |
|---|---|---|
| `QDH-E001`, `QDH-E002` | `S64-E021` | Unverified trigger telemetry, or unestablished durable watermark, prevents positive establishment of non-reuse allocation safety. |
| `QDH-E003` | `S64-E019` / `S64-E021` | `E019` is defined for stale **commit** attempts. A stale lease renewal or control operation is not a commit and is an allocation-safety condition, correctly reported as `E021`. The structured record carries `operation_class`, so the adapter never parses message text. |
| `QDH-E004` | `S64-E021` | A failed sanitization or attestation means the engine cannot safely return to service. `E014` was rejected: it concerns unreachability, not sanitization failure. |
| `QDH-E005` | `S64-E021` | The audit trail or lineage is no longer trustworthy, so allocation safety cannot be positively established. |
| `QDH-E006`, `QDH-E007`, `QDH-E013` | `S64-E021` | Each prevents positive establishment of allocation safety. |
| `QDH-E008` | `S64-E002` | Closest boundary code where an interface requires an `S64` response for an engine permanently retired under legacy rules. `E026` was rejected: it concerns coercing a valid cross-profile identifier. |
| `QDH-E009` | `S64-E021` | A manual override attempt compromises allocation safety. `E019` was rejected: it is specific to a stale allocator whose authority has ended. |
| `QDH-E010` | `S64-E017` | A missing tombstone is exactly the retention-integrity failure `E017` describes. |
| `QDH-E011` | `S64-E012` | Coarse boundary code indicating authoritative validation cannot be trusted or completed. |
| `QDH-E012` | `S64-E020` | Direct match with the core definition of concurrent allocator collision. |
| `QDH-E014` | `S64-E018` | A strict regression would permit Local reuse; the mapping surfaces the underlying non-reuse violation. |
| `QDH-E015` | `S64-E030` | Since this revision the core has a dedicated profile-provenance code; conflicting profile evidence is a provenance failure, not a generic safety failure. The previous `E021` mapping is withdrawn. |
| `QDH-E016`, `QDH-E017` | `S64-E021` | Missing evidence binding, and an out-of-order reactivation, both prevent positive establishment of allocation safety. |
| `QDH-E018` | `S64-E031` | A dedicated core code now exists for an inadmissible lifecycle transition. |
| `QDH-E019` | `S64-E013` | Direct match with the core routing code. |
| `QDH-E020` | `S64-E023` | Direct match with the core coordinate-range code. |

## 4. Precedence rules for QDH diagnostics

When multiple QDH fault conditions occur simultaneously, the policy engine MUST evaluate and emit in strict tier priority:

1. **Tamper, security, and integrity:** `QDH-E005`, `QDH-E009`, `QDH-E011`.
2. **Epoch fencing, concurrency, and ordering:** `QDH-E003`, `QDH-E012`, `QDH-E017`.
3. **Trigger admissibility:** `QDH-E001` — no reclamation may begin without verified trigger evidence; this gate applies only after fencing conditions have been evaluated.
4. **Legacy, host fitness, evidence binding, and transition admissibility:** `QDH-E008`, `QDH-E007`, `QDH-E016`, `QDH-E018`.
5. **Watermark, non-reuse, range, routing, and evidence-reconciliation safety:** `QDH-E006`, `QDH-E014`, `QDH-E002`, `QDH-E010`, `QDH-E015`, `QDH-E019`, `QDH-E020`.
6. **Hardware and index readiness:** `QDH-E004`, `QDH-E013`.

**Intra-tier tie-breaker.** Within any tier, when more than one code is applicable at the same evaluation point, the engine MUST emit them in strict ascending numeric order, and the externally reported `S64` code is that of the first emitted code having a mapping.

**Why `QDH-E001` is tier 3 and not tier 2.** Trigger evidence gates whether reclamation may proceed at all, but a stale-epoch fence or a tamper event must be reported in preference to a telemetry fault. Placing the gate below fencing is what guarantees the core rule that a stale-epoch commit is never masked.

**Core boundary precedence is not overridden.** Where an external allocation or administrative write boundary is crossed, the boundary interface MUST also satisfy `ERROR-CODES.md` §4.5 and `SPECIFICATION.md` §16.2. `QDH-E018` performs the `S64-E031` projection, `QDH-E019` performs `S64-E013`, and `QDH-E020` performs `S64-E023`, at the core stage corresponding to their tier. None of these may preempt tiers 1–3.

`S64-E022` is **not a fault.** It reports a completed forward-engine rollover. Terminal pool exhaustion is `S64-E029`. Neither appears in these precedence tiers as a fault code.

## 5. International standards alignment

| Domain | Standard | Relationship |
|---|---|---|
| Media sanitization | **NIST SP 800-88** (current revision) | `QDH-E004` references the **verification** stage of the two-stage assurance model. Organizational **validation** is an operator-policy layer above this registry. |
| Cryptographic modules | **ISO/IEC 19790** (current edition) | Trigger-telemetry verification, attestation verification, and lease signing rely on modules validated to ISO/IEC 19790. Cryptographic Erase key sanitization follows its zeroization requirements. |
| Key management | **NIST SP 800-57 Part 1** (current revision) | Allocator-lease signing key lifecycle; key destruction is audited per the standard's post-operational requirements. |
| Audit and accountability | **NIST SP 800-53** AU-10 | `QDH-E005` and `QDH-E011` enforce audit-trail integrity. Non-repudiation additionally requires external anchoring per `QDH-SPECIFICATION.md` §7. |
| Access control and duties | **ISO/IEC 27001:2022** A.5.3, A.5.18 | `QDH-E009` enforces prohibition and auditability of manual override; the code tiers assume separated roles. |

Edition numbers and publication dates MUST be verified against the published standards before final release. Where an operator's governing policy imposes stricter diagnostic requirements, the stricter requirement governs.

## 6. Compliance

Conforming QDH implementations MUST:

- Emit the exact `QDH-Exxx` code defined in §2 whenever the corresponding trigger condition occurs.
- Emit the mapped `S64-Exxx` code at any interface boundary crossing an external caller, per `ERROR-CODES.md` and §1.
- Apply the detection / triage / emission separation of §1.
- Apply the precedence tiers of §4, including the intra-tier ascending tie-breaker.
- Emit the eight-field structured surface of §1, never parsing human text.
- For `QDH-E003`, select `S64-E019` for `COMMIT` and `S64-E021` for `LEASE_RENEWAL`, `CONTROL`, and `TOMBSTONE_WRITE`; the tombstone-write exemption must not emit `QDH-E003` at all.
- For `QDH-E005`, `QDH-E016`, and `QDH-E018`, confine each to its defined condition; these three are the most common sites of catch-all misuse.
- For `QDH-E008`, apply only to engines permanently retired under pre-v1.42 rules or to keys retired outside QDH.
- For `QDH-E014`, trigger on strict regression only.
- For `QDH-E015`, halt and quarantine on conflicting profile evidence.
- For `QDH-E016`, block the transition and return to `STATE_QUARANTINED`.
- For `QDH-E017`, block out-of-order Phase 5 emission.
- For `QDH-E020`, validate ranges before any packing or constraint evaluation.

Removing a code or redefining an established code's meaning requires a new QDH Revision. This registry redefines no `S64-Exxx` code.

## 7. Change Log

| Revision | Date | Change |
|---|---|---|
| RC1 | 2026-11-18 | Initial 14-code registry. |
| RC2 | 2026-11-20 | Added `E015`–`E017`; clarified `E003` operation-class mapping and tombstone exemption; clarified the `E010` extended case; separated detection/triage/emission; updated tiers. |
| RC2 (final) | 2026-11-23 | Added `QDH-E018`, `QDH-E019`, `QDH-E020`. Remapped `QDH-E015` from `S64-E021` to `S64-E030`. Confined `QDH-E005`, `QDH-E016`, `QDH-E018` to their defined conditions and prohibited catch-all use. Moved `QDH-E001` to tier 3 so fencing and tamper conditions are never masked. Extended `QDH-E004` to allowlist, certificate-window, and revocation-freshness checks. Extended `QDH-E007` to binding and allocation, not only reactivation. Extended `QDH-E008` to keys retired outside QDH. Extended `QDH-E020` to Local coordinates below `next_safe_local`. Standardized the structured surface at eight fields in both dialects. De-dated standards citations pending verification. Registry now contains 20 codes, `E001`–`E020`. |
