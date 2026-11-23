**Filename:** `QDH-SPECIFICATION.md`
**Created on:** 2026-11-18
**Last modified:** 2026-11-23
**SMART 64-Bit ID Version & Revision:** v1.42 — Version 0, Revision 0010
**Companion Documents:** `SPECIFICATION.md` (frozen RC2.2, final), `ERROR-CODES.md` (frozen RC2.2, final), `QDH-ERROR-CODES.md` (RC2.2, final), `QDH-LOGGING-AND-LIFECYCLE.md` (RC2.2, final), `qdh_schema_postgresql.sql` (RC2.2), `qdh_schema_mysql.sql` (RC2.2)
**Status:** QDH Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**License:** AGPL3
**Email:** contact@samara.com.bd

---

# SMART 64-Bit ID v1.42 — QDH & Automated Reclamation Specification

## 1. Purpose and Architectural Boundary

This document defines the normative protocols, governance directives, automated state machines, and storage invariants for **QDH (Quarantine, Database Engineering, and Hardware Engineering)** and **Automated Virtual Engine Reclamation** under SMART 64-Bit ID v1.42 (`Version 0, Revision 0010`).

QDH denotes the programme of Quarantine, Database Engineering, and Hardware Engineering. The Hardware Engineering phase comprises sanitization and refurbishment. This expansion is fixed and MUST NOT be varied.

This document is subordinate to `SPECIFICATION.md` (frozen, final) and `ERROR-CODES.md` (frozen, final). Where this document and a frozen core document appear to conflict, the frozen core document governs.

This revision is aligned to the finalized core and closes the additional findings arising from the core review: the profile-provenance correction (`S64-E030`), the lifecycle-transition code (`S64-E031`), the lineage `PROFILE_UPGRADE` closure reason, and the control-table semantics of `SPECIFICATION.md` §6.3.2.

### 1.1 Historical Continuity Boundary

- **Pre-v1.42 (including v1.41 `Revision 0001`):** Any `FAIL_HARD` event (`SPECIFICATION.md` §7.1) permanently retired the entire `(Class, Engine)` Virtual Engine and its issued Local coordinates. No reclamation procedure existed for engines retired under those rules. Such engines are permanently ineligible for QDH reclamation (`QDH-E008`).
- **SMART v1.42 (Revision `0010`):** Introduces automated QDH governance to safely refurbish, sanitize, audit, and reclaim physical nodes and `(Class, Engine)` Virtual Engines without violating permanent Local coordinate non-reuse (`SPECIFICATION.md` §7.2) or history-chain retention (`SPECIFICATION.md` §10.3).

**Important distinction.** A Virtual Engine whose `active_profile` is `v1.41` but which operates under the v1.42 QDH governance framework **IS eligible for QDH reclamation** and reissues deterministically under `v1.41` per `SPECIFICATION.md` §10.7.1. `QDH-E008` applies only to engines **already permanently retired** under the pre-v1.42 legacy rules, which never entered the v1.42 QDH lifecycle.

**Retirement outside QDH is final.** A Virtual Engine key retired under `SPECIFICATION.md` §11 without passing through the QDH lifecycle MUST NOT be re-entered as a new Virtual Engine. QDH is the only re-entry path for a `(Class, Engine)` key.

### 1.2 International Standards Alignment

This document adopts terminology and assurance concepts from the following standards. Citations are for vocabulary and assurance-model alignment; SMART does not claim certification unless separately stated by an implementer.

| Domain | Standard | Application |
|---|---|---|
| Media sanitization | **NIST SP 800-88** (current revision) | Establishes an enterprise sanitization programme with Clear/Purge/Destroy methods; separates **verification** (technical completion check) from **validation** (organizational risk determination). Cryptographic Erase is covered; key sanitization references **ISO/IEC 19790** zeroization; technology-specific methods reference **IEEE 2883**. |
| Cryptographic modules | **ISO/IEC 19790** (current edition) | Security requirements for cryptographic modules, including sensitive security parameter zeroization. Used where Cryptographic Erase, attestation, or lease signing require a validated module. |
| Key management | **NIST SP 800-57 Part 1** (current revision) | Key lifecycle phases and metadata retention for audit after key destruction. Allocator-lease signing keys follow this lifecycle. |
| Audit and accountability | **NIST SP 800-53** AU-06, AU-10, AU-12 | Hash-chained audit events provide tamper-evidence supporting AU-10; audit generation content per AU-12. External anchoring (§7) is required for non-repudiation against a privileged database attacker. |
| Access control and duties | **ISO/IEC 27001:2022** A.5.3, A.5.18 | QDH role separation and QDH-D1 align with segregation-of-duties and privileged-access controls. |
| Asset inventory | **ISO/IEC 27001:2022** A.5.9; **NIST SP 800-53** CM-8 | The Virtual Engine control table is the authoritative component inventory for engines and nodes. |
| Industrial control systems (optional) | **IEC 62443-2-1** (current edition) | For deployments where nodes are IACS components; node-wide quarantine aligns with zone/conduit isolation. |
| Deterministic serialization | **RFC 8785** | Canonical JSON for audit event hash computation. |

Edition numbers and publication dates MUST be verified against the published standards before final release. Where an operator's governing policy imposes stricter requirements, the stricter requirement governs.

## 2. Core QDH Directives (Normative)

- **QDH-D1 (Zero Manual Override).** Human operators MUST NOT manually force-reclaim a Virtual Engine, bypass quarantine fencing, reset a Local watermark, or increment `generation_epoch` outside the automated QDH policy engine. Any unauthorized manual override attempt MUST emit `QDH-E009` and trigger an immutable security incident record in `qdh_audit_events`.
- **QDH-D2 (Strict Watermark Monotonicity).** Reclaiming a `(Class, Engine)` Virtual Engine NEVER resets its Local coordinate counter to `0`. Post-reclamation allocation MUST resume at or above the authoritatively verified **First Never-Consumed Local Coordinate** (`SPECIFICATION.md` §7.3).
- **QDH-D3 (Epoch Isolation).** Every completed reclamation cycle MUST increment `generation_epoch` by `1`. Stale allocators or delayed asynchronous workers from prior epochs MUST be rejected at the database write boundary (`SPECIFICATION.md` §10.7.2), emitting `S64-E019` and `QDH-E003` for **commit attempts**. Stale **lease renewals** emit `QDH-E003` with `S64-E021`. The append-only prior-generation tombstone-write exemption of `SPECIFICATION.md` §10.7.2 remains in force.
- **QDH-D4 (Immutable Lineage & Tamper-Evident Audit).** Every state transition, hardware scrub, database verification, and epoch bump MUST be recorded in an append-only, hash-chained audit trail and appended to the control-table lineage. Truncation or mutation is non-conforming (`QDH-E005`). Hash chaining provides tamper-**evidence** only; non-repudiation against a privileged database attacker additionally requires external anchoring (§7).
- **QDH-D5 (Node-Wide Blast Radius Assessment).** Per `SPECIFICATION.md` §9.3, a fault on a physical node places the entire node and **all** Virtual Engines hosted on it into `STATE_QUARANTINED`, in every non-terminal state including `STATE_UNALLOCATED` and `STATE_EXHAUSTED`. Each Virtual Engine MUST pass independent verification (`SPECIFICATION.md` §9.4) before returning to service. Node state is tracked in the `physical_nodes` table and transitions are enforced by the blast-radius trigger.

## 3. Automated QDH Lifecycle State Machine

A `(Class, Engine)` Virtual Engine MUST occupy exactly one of eight mutually exclusive operational states:

| State | Description | Allocation permitted? | Allowed next states |
|---|---|---|---|
| `STATE_UNALLOCATED` | Engine within the Class pool never yet bound to an active lifecycle. | No (requires binding) | `STATE_ACTIVE`, `STATE_QUARANTINED` |
| `STATE_ACTIVE` | Normal production minting under the current `generation_epoch` and `active_profile`. | **Yes** | `STATE_QUARANTINED`, `STATE_EXHAUSTED`, `STATE_RETIRED_PERMANENT` |
| `STATE_QUARANTINED` | Fenced immediately upon `FAIL_HARD`, power cut, hardware anomaly, or node-wide incident. | **No** (hard fenced) | `STATE_DE_VERIFYING`, `STATE_RETIRED_PERMANENT` |
| `STATE_DE_VERIFYING` | **Database Engineering.** Audits tombstones, verifies historical records, computes the First Never-Consumed Local Coordinate. | **No** | `STATE_HE_SANITIZING`, `STATE_EXHAUSTED`, `STATE_QUARANTINED`, `STATE_RETIRED_PERMANENT` |
| `STATE_HE_SANITIZING` | **Hardware Engineering.** Sanitizes node storage per NIST SP 800-88, verifies firmware/enclave attestation, confirms a clean substrate. | **No** | `STATE_RECLAIM_COMMIT`, `STATE_QUARANTINED`, `STATE_RETIRED_PERMANENT` |
| `STATE_RECLAIM_COMMIT` | Atomic control-plane commit: increments `generation_epoch`, appends lineage, updates the Class pool index, binds the new allocator lease. | **No** (transitional) | `STATE_ACTIVE`, `STATE_QUARANTINED` |
| `STATE_EXHAUSTED` | All `2^29` Local coordinates consumed; rollover per §4.6 applies. | **No** | `STATE_RETIRED_PERMANENT`, `STATE_QUARANTINED` |
| `STATE_RETIRED_PERMANENT` | Terminal retirement (pre-v1.42 legacy engine, or unrecoverable watermark evidence). | **No** (terminal) | None |

The eight states are mutually exclusive; exactly one applies at any instant. Transitions other than those listed are non-conforming and are reported as `S64-E031` with `QDH-E018`. `STATE_RETIRED_PERMANENT` is terminal and is never quarantined.

**Quarantine is a universal entry transition.** Every non-terminal state MUST be able to enter `STATE_QUARANTINED`. Node-wide quarantine MUST NOT fail because an engine on the node is unallocated or exhausted.

**Evidence binding.** Every transition into `STATE_HE_SANITIZING` MUST be accompanied by a `DE_WATERMARK_VERIFIED` audit event for the same `(class_id, engine_id, generation_epoch)` committed **before** the transition. Every transition into `STATE_RECLAIM_COMMIT` MUST be accompanied by an `HE_SANITIZATION_ATTESTED` event committed **before** the transition. A transition attempted without the required prior evidence raises `QDH-E016`.

**Phase 5 event ordering.** `ALLOCATOR_LEASE_ISSUED` MUST be committed before `ENGINE_REACTIVATED` for the same `(class_id, engine_id, generation_epoch)`. Out-of-order emission is `QDH-E017`.

**Core vocabulary mapping.** Where `SPECIFICATION.md` §6.4 refers to an engine "in the Unallocated or Reclaimed lifecycle state", `STATE_UNALLOCATED` is the corresponding state. `STATE_RECLAIM_COMMIT` is transient and is never a rollover candidate.

## 4. Automated Reclamation Protocol

### 4.0 Initial Binding (STATE_UNALLOCATED → STATE_ACTIVE)

Initial binding of a never-before-used `(Class, Engine)` is **not** QDH reclamation. It follows `SPECIFICATION.md` §6.3–6.4:

1. The engine is bound to a physical node whose `node_state = 'NODE_ACTIVE'` and which holds a current `HE_SANITIZATION_ATTESTED` for its substrate, including after any engine on that node reached `STATE_EXHAUSTED`.
2. `generation_epoch` is set to `1`.
3. `local_watermark` is set to `0`.
4. `active_profile` is set to the profile under which the engine will operate.
5. The state transitions from `STATE_UNALLOCATED` to `STATE_ACTIVE`.
6. An `ENGINE_INITIAL_BOUND` event is emitted.

A node that is not `NODE_ACTIVE`, or that has no current attestation, MUST NOT receive a binding. QDH reclamation (§4.1–4.6) applies only to engines that entered `STATE_QUARANTINED` after an incident.

### 4.1 Phase 1: Immediate Quarantine & Epoch Fencing (Q-Phase)

1. On detecting a `FAIL_HARD` trigger (`SPECIFICATION.md` §7.1), power loss, storage stall, or split-brain heartbeat loss, the control plane MUST, **within one serializable transaction**:

   - set `physical_nodes.node_state = 'NODE_QUARANTINED'`;
   - transition **every** hosted `(Class, Engine)` to `STATE_QUARANTINED` and clear `allocator_lease_id`, for all non-terminal states;
   - set `revoked_at_utc` on every allocator lease referenced by those engines;
   - append one `NODE_QUARANTINE_TRIGGERED` event per affected engine to `qdh_audit_events`.

2. **Revocation is defined as a durable, non-null `revoked_at_utc` on the `allocator_leases` row.** Clearing `virtual_engines.allocator_lease_id` alone is not revocation and MUST NOT be reported as such. A reclamation that reissues a lease MUST NOT complete while a prior lease remains unrevoked.

3. Any in-flight or delayed **commit attempt** carrying the previous `generation_epoch` fails at the database write boundary (`S64-E019` / `QDH-E003`) per `SPECIFICATION.md` §10.7.2. A stale **lease renewal** emits `QDH-E003` with `S64-E021`.

4. A database-layer cascade MAY perform the state transitions. It MUST NOT be treated as satisfying the audit emission or lease revocation obligations. Where the dialect cannot compute the event hash inside a trigger, items in step 1 that concern audit emission and lease revocation are the control plane's obligation in the same transaction, and the implementation MUST NOT claim the quarantine is atomic without them.

### 4.2 Phase 2: Database Engineering Verification & Watermark Discovery (DE-Phase)

1. Transition the engine to `STATE_DE_VERIFYING`.

2. Query **only** durable evidence — `durable_allocation_log`, `lease_watermarks`, and permanent `coordinate_tombstones`. This phase MUST NOT perform a raw last-ID guess; attempting last-ID inference emits `QDH-E006`.

3. Compute `next_safe_local` as the maximum of three values: the highest durable lease ceiling whose release state is `ACTIVE` or `CONSUMED` (default `0`); the highest tombstoned Local coordinate plus one (default `0`); and the current `local_watermark`. Issued-but-unacknowledged lease ranges are treated as consumed up to their durable lease ceiling (`SPECIFICATION.md` §7.3).

4. **Evidence reconciliation.** The three sources MUST be reconciled before computing `next_safe_local`:

   - If lease ceiling and durable-log maximum disagree, the **higher** value governs; the lower value is under-recording, not evidence of safety.
   - If a tombstone references a Local coordinate higher than every other evidence source, that is a **tombstone gap in durable evidence**: halt with `QDH-E010` only, quarantine the engine, and require an authorized backup-restore reconciliation. `QDH-E002` is not emitted for this condition.
   - A gap **within** a lease is acceptable; the lease ceiling is treated as consumed even if the log has no row for every integer in the range.
   - Conflicting profile evidence across sources for the same `(class_id, engine_id)` is `QDH-E015`.

5. **Boundary check.** Valid Local IDs are `0` through `536,870,911`. `536,870,912` means all Local coordinates are consumed. If `next_safe_local >= 536,870,912`:

   - Transition the engine directly to `STATE_EXHAUSTED`, bypassing `STATE_HE_SANITIZING` and `STATE_RECLAIM_COMMIT`.
   - Invoke rollover per §4.6 and `SPECIFICATION.md` §6.4: ascending search for the lowest eligible Engine with `engine_id` greater than the exhausted engine, in the same Class pool, no wraparound. Eligible means `STATE_UNALLOCATED`, or an existing engine whose prior allocator authority has been conclusively invalidated under §7.4.
   - If a forward Engine is safely reserved, emit `S64-E022` and log `ENGINE_EXHAUSTED_ROLLOVER`. If none remains, emit `S64-E029` and log `ENGINE_EXHAUSTED_TERMINAL`.
   - `536,870,912` MUST NOT be treated as an allocatable Local coordinate.

6. Verify that every coordinate below `next_safe_local` is accounted for as consumed, retired, or covered by a durable lease watermark. If authoritative evidence cannot be established, suspend in `STATE_QUARANTINED` and emit `QDH-E002` / `S64-E021`.

7. On success, write `DE_WATERMARK_VERIFIED` with the computed `next_safe_local`. The subsequent transition to `STATE_HE_SANITIZING` is gated on this event per §3.

### 4.3 Phase 3: Hardware Engineering Sanitization & Refurbishment (HE-Phase)

1. Transition the engine to `STATE_HE_SANITIZING`.

2. Execute automated media sanitization and hardware diagnostics using NIST SP 800-88 vocabulary:

   - **Clear:** logical techniques sufficient for reuse within the same controlled environment. Multi-pass overwriting is not required for modern media.
   - **Purge:** techniques rendering target data infeasible to recover, including **Cryptographic Erase** where full-disk encryption is in place and key destruction is verified. Key sanitization follows ISO/IEC 19790 zeroization; technology-specific methods SHOULD reference IEEE 2883.
   - **Destroy:** physical destruction where Clear or Purge are not applicable.
   - Additional automated diagnostics: memory zeroization, clock-drift validation, and hardware root-of-trust attestation using a module validated to an applicable standard.

3. Perform the two-stage assurance: **verification**, a technical check that the action completed and produced the expected effect; and **validation**, an organizational determination under the operator's policy that the sanitized state meets the risk-based requirements for the intended reuse.

4. **Attestation freshness, anti-replay, revocation, and allowlisting.** Attestation evidence MUST be persisted in `hardware_attestations`, recording the sanitization method and its verification result, with:

   - `challenge_nonce` — a fresh, single-use cryptographic nonce; reuse is rejected by the `nonce_registry`.
   - Binding to `class_id`, `engine_id`, `generation_epoch`, and `incident_id`, all matching the current engine context.
   - `attestation_digest`, which MUST appear in the `trust_roots` measurement allowlist for the platform.
   - `cert_not_before_utc <= verified_at_utc < cert_not_after_utc`.
   - `revocation_checked_at_utc` no older than an operator-defined maximum age (default 24 hours).
   - A trust root that is present and not revoked.

   Replayed nonces, expired or not-yet-valid certificates, stale revocation checks, revoked keys, non-allowlisted digests, and unbound attestations MUST be rejected with `QDH-E004` / `S64-E021`.

   **Trust-root revocation MUST be actionable independently of the orchestrator's ordinary write path**, and revocation MUST immediately block attestations bound to that root.

5. If hardware fails refurbishment or sanitization verification, transition the engine back to `STATE_QUARANTINED` and emit `QDH-E004` / `S64-E021`. The node is marked `NODE_UNFIT`; the engine MAY be rebound to a verified clean node per §4.0.

6. On success, write `HE_SANITIZATION_ATTESTED` referencing `hardware_attestations.attestation_id`. The transition to `STATE_RECLAIM_COMMIT` is gated on this event.

### 4.4 Phase 4: Atomic Epoch Commit & Lineage Appending (Commit-Phase)

1. Transition the engine to `STATE_RECLAIM_COMMIT`.

2. Within a single serializable ACID transaction, atomically with respect to the control-table row, or through a transactionally equivalent protocol in which no intermediate state is externally observable, mirroring `SPECIFICATION.md` §10.7.1 and §10.7.3:

   - Append the closed generation metadata — `generation_epoch`, `profile_version_revision`, `local_start`, `local_end_watermark`, `physical_node_id`, `opened_at_utc`, `closed_at_utc`, `closure_reason`, `closing_audit_event_id` — to the lineage per `QDH-LOGGING-AND-LIFECYCLE.md` §4.
   - Set `generation_epoch = generation_epoch + 1`.
   - Set `local_watermark = next_safe_local`.
   - **Leave `active_profile` unchanged.** Reissue is deterministic under the existing profile (`SPECIFICATION.md` §10.7.1). A profile change is out of scope for reclamation and requires §13.1 of the core.
   - Update the indexed forward-scan structure of `SPECIFICATION.md` §6.4.1.
   - Write the hash-chained `RECLAMATION_COMMITTED` record.

   Reclamation MAY record only the closure reasons `FAIL_HARD_RECLAIMED`, `NODE_REFURBISHMENT`, and `EXHAUSTED`. `PROFILE_UPGRADE` is a core §13.1 closure reason and MUST NOT be recorded by a reclamation cycle.

3. **Crash and uncertain-commit recovery matrix.** Because Phase 4 executes inside a single serializable transaction, an interrupted commit rolls back all control-table and audit changes. Recovery after any crash or uncertain commit timeout MUST reconcile against authoritative database state before acting:

| Crash point | DB state observed | Required recovery action |
|---|---|---|
| During Phases 1–3 | Node or engine in `STATE_QUARANTINED`, old `generation_epoch` | Re-execute Phase 1 idempotently; re-emit quarantine events only if absent (query by `incident_id`) |
| During Phase 2 | Engine in `STATE_DE_VERIFYING`, no new evidence | Re-run Phase 2 from scratch; a partial `DE_WATERMARK_VERIFIED` must be absent |
| During Phase 3 | Engine in `STATE_HE_SANITIZING`, no `HE_SANITIZATION_ATTESTED` | Re-run Phase 3; previously issued nonces are consumed, a fresh nonce MUST be issued |
| Before the Phase 4 commit | DB rolled back, `generation_epoch` unchanged | Return the engine to `STATE_QUARANTINED` and re-execute Phases 1–4 idempotently |
| After the Phase 4 commit, before Phase 5 | `generation_epoch = E + 1`, `RECLAMATION_COMMITTED` persisted, state `STATE_RECLAIM_COMMIT`, `allocator_lease_id IS NULL` | Idempotently complete Phase 5: `ALLOCATOR_LEASE_ISSUED` → `ENGINE_REACTIVATED` → `STATE_ACTIVE` |
| Uncertain commit timeout | — | Query `(class_id, engine_id)` in the control table and by `(class_id, engine_id, event_id)` in the audit trail first; never blindly re-increment `generation_epoch` or duplicate audit records |

### 4.5 Phase 5: Controlled Reactivation

1. Issue a newly signed, epoch-bound allocator lease to the verified host. The lease MUST be persisted in `allocator_leases` with `(class_id, engine_id, generation_epoch)` bound into the signed payload and `lease_signature` verifiable against the trust roots. A new lease MUST NOT be issued while a prior lease for the engine remains unrevoked. Lease-key lifecycle follows NIST SP 800-57 practice.

2. The engine's hosting node MUST be `NODE_ACTIVE`. Reactivation on any other node state is `QDH-E007` and MUST be refused.

3. Transition the engine to `STATE_ACTIVE`; `allocator_lease_id` MUST reference `allocator_leases.lease_id`.

4. Emit `ALLOCATOR_LEASE_ISSUED` then `ENGINE_REACTIVATED`, both mandatory and in that order (`QDH-E017` otherwise).

5. The first newly minted coordinate MUST NOT be less than `next_safe_local`. A coordinate above it MUST be recorded in the same transaction as a consumed range in the durable log and tombstones, consistent with batch allocation under `SPECIFICATION.md` §7.2. Allocation below `next_safe_local` is `S64-E018`. The coordinate inherits the new `generation_epoch` and the unchanged `active_profile`.

### 4.6 Exhaustion and Rollover Sequencing

1. A forward reservation MUST exist before the issuing engine's Local namespace is exhausted, and MUST be established no later than before the final Local coordinate is issued.

2. Where the controller serves an engine with fewer than `K` coordinates remaining, it MUST hold a current reservation and re-verify it on each issue. `K` is operator-defined and MUST be at least `1`.

3. A rollover candidate MUST be `STATE_UNALLOCATED`, or an existing engine whose prior allocator authority has been conclusively invalidated under §7.4 before adoption. An engine under a live lease MUST NOT be a candidate (`S64-E020`).

4. Candidate selection MUST be strictly ascending with no wraparound.

5. Reaching `local_watermark = 536,870,912` in `STATE_ACTIVE` MUST transition to `STATE_EXHAUSTED` and emit `S64-E022` with `ENGINE_EXHAUSTED_ROLLOVER` if a reservation exists, otherwise `S64-E029` with `ENGINE_EXHAUSTED_TERMINAL`. Neither outcome may be silent.

6. The rollover index MUST be a maintained structure, not a query-time scan. Desynchronisation with control-table state is `QDH-E013`.

7. Rollover under this section is exhaustion handling. It is not a `FAIL_HARD` recovery path and MUST NOT be used to resume an interrupted allocation (`SPECIFICATION.md` §7.1).

### 4.7 Audit-gap detection (qdh_audit_gap)

Phase 1 quarantines the node as a fencing primitive and does not write the
per-engine audit event. The control plane MUST insert one
NODE_QUARANTINE_TRIGGERED event per affected engine in the same transaction.

Both reference schemas expose a read-only view, qdh_audit_gap, returning every
engine whose current state is STATE_QUARANTINED with no quarantine event at its
current generation_epoch. The epoch predicate is normative: an event from a
superseded generation MUST NOT count as evidence for the current one.

Scope: only engines currently in STATE_QUARANTINED are reported. Engines that
have advanced to STATE_DE_VERIFYING or later are not, even if the event was never
written; operators requiring continuous detection must alert when a row appears.

## 5. QDH-Internal Diagnostic Codes (Summary)

The full registry is in `QDH-ERROR-CODES.md`. The codes below are added or changed in this revision; all map to frozen core codes and redefine none of them.

| Code | Identifier | Mapped `S64` |
|---|---|---|
| `QDH-E015` | `QDH_EVIDENCE_PROFILE_MISMATCH` | `S64-E030` (was `S64-E021`) |
| `QDH-E016` | `QDH_EVIDENCE_BINDING_MISSING` | `S64-E021` |
| `QDH-E017` | `QDH_PHASE5_ORDERING_VIOLATION` | `S64-E021` |
| `QDH-E018` | `QDH_LIFECYCLE_TRANSITION_INVALID` *(new)* | `S64-E031` |
| `QDH-E019` | `QDH_VIRTUAL_ENGINE_NOT_FOUND` *(new)* | `S64-E013` |
| `QDH-E020` | `QDH_ALLOCATION_RANGE_INVALID` *(new)* | `S64-E023` |

`QDH-E016` is confined to missing required evidence. An otherwise inadmissible transition is `QDH-E018` / `S64-E031`.

## 6. Normative Cross-References

| This document | Frozen core reference |
|---|---|
| §1.1 historical boundary | `SPECIFICATION.md` §7.1, §10.7.1, §11 |
| §2 QDH-D3 | `SPECIFICATION.md` §10.7.2 |
| §2 QDH-D4 | `SPECIFICATION.md` §10.3, §10.6 |
| §2 QDH-D5 | `SPECIFICATION.md` §9.3, §9.4 |
| §3 state machine | `SPECIFICATION.md` §6.4, §6.5, §10.7.3 |
| §3 evidence binding | `SPECIFICATION.md` §10.7.3 |
| §4.0 initial binding | `SPECIFICATION.md` §6.3–6.4, §6.3.2 |
| §4.1 Phase 1 | `SPECIFICATION.md` §7.1, §7.4, §9.3, §10.7.2 |
| §4.2 Phase 2 | `SPECIFICATION.md` §6.4, §6.5, §7.1, §7.3, §10.3 |
| §4.3 Phase 3 | `SPECIFICATION.md` §9.4, §10.7.3 |
| §4.4 Phase 4 | `SPECIFICATION.md` §6.4.1, §10.7.1, §10.7.3 |
| §4.5 Phase 5 | `SPECIFICATION.md` §6.3.2, §7.4, §10.7.2 |
| §4.6 exhaustion and rollover | `SPECIFICATION.md` §6.4, §6.4.1, §6.5 |
| Diagnostic codes | `QDH-ERROR-CODES.md`; `ERROR-CODES.md` (frozen) |
| Audit and lineage | `QDH-LOGGING-AND-LIFECYCLE.md` |
| Schema | `qdh_schema_postgresql.sql`; `qdh_schema_mysql.sql` |

## 7. Non-Repudiation and External Anchoring

A hash chain alone does not provide non-repudiation against a privileged database attacker. It provides tamper-**evidence** only when the head of the chain, or a periodic checkpoint hash, is anchored outside the database's trust boundary.

A conforming implementation MUST:

1. Periodically, at minimum daily or per operator governance, compute a **root hash** over all per-engine stream head `event_hash` values, order-canonical per RFC 8785.
2. Publish that root hash to an external anchor independent of the QDH database — a WORM store, transparency log, timestamping authority, or append-only immutable object store outside the database superuser's control.
3. Record the anchor reference, URI, digest, and timestamp in `audit_anchors`.
4. Require a matching anchor record on any integrity verification request. Absence downgrades the assurance claim from "non-repudiation" to "tamper-evident within the database trust boundary."

An implementation that does not anchor externally MUST NOT claim AU-10 non-repudiation.

## 8. Conformance

A conforming QDH implementation MUST:

- Implement initial binding (§4.0) and reclamation (§4.1–4.6) in the stated order and atomicity.
- Enforce the eight-state lifecycle of §3, including universal quarantine entry, evidence binding, and Phase 5 event ordering.
- Enforce QDH-D1 through QDH-D5 without exception.
- Emit the applicable `QDH-Exxx` code and the mapped `S64-Exxx` code at every external boundary; never use `QDH-E005` for a condition other than lineage or audit mutation.
- Apply the Phase 2 boundary check and invoke rollover per §4.6, emitting `S64-E022` or `S64-E029` as applicable.
- Perform Phase 2 evidence reconciliation and halt with `QDH-E010` or `QDH-E015` on gaps or profile conflict.
- Enforce host fitness for binding, allocation, and reactivation, emitting `QDH-E007` where violated.
- Revoke allocator leases durably at quarantine and refuse a new lease while a prior lease is unrevoked.
- Preserve the append-only, hash-chained audit trail and lineage, including the per-generation profile.
- Apply NIST SP 800-88 vocabulary and the two-stage verification/validation model in Phase 3.
- Persist and verify attestations, nonces, certificate validity windows, revocation freshness, and trust-root allowlisting per §4.3 step 4.
- Anchor audit root hashes externally per §7, or disclaim AU-10 non-repudiation.

An implementation that cannot satisfy an applicable QDH safety, non-reuse, epoch-fencing, audit-integrity, evidence-binding, host-fitness, non-repudiation-anchoring, or sanitization-assurance requirement MUST NOT claim QDH conformance.

## 9. Findings Closed by This Revision

| Finding | Section(s) |
|---|---|
| C-001 – C-006, H-001 – H-010, X-001 – X-010, R-001 – R-006, S-001 – S-005 | As recorded in RC2 |
| N-01 – N-20 | As recorded in RC2 |
| Universal quarantine entry; state table | §3, §4.1 |
| Quarantine atomicity and lease revocation | §4.1 |
| Node fitness for binding, allocation, reactivation | §4.0, §4.5, §8 |
| Attestation allowlist, validity window, revocation freshness, root revocation | §4.3 |
| Rollover sequencing and candidate eligibility | §4.2, §4.6 |
| Tombstone-gap single-code rule | §4.2 |
| Contiguous post-reclamation allocation | §4.5 |
| Core alignment: `S64-E030`, `S64-E031`, `PROFILE_UPGRADE` | §1, §3, §4.4, §5 |
| Legacy key finality outside QDH | §1.1 |

## 10. Change Log

| Revision | Date | Change |
|---|---|---|
| RC1 | 2026-11-18 | Initial QDH specification draft. |
| RC2 | 2026-11-20 | Full remediation of 37 review findings and 20 N-series findings. |
| RC2 (final) | 2026-11-23 | Aligned to finalized core. Universal quarantine entry and extended state table (§3). Quarantine atomicity, audit emission, and durable lease revocation (§4.1). Node fitness gating (§4.0, §4.5). Attestation allowlisting, certificate window, revocation freshness, independent trust-root revocation, sanitization method recording (§4.3). New §4.6 rollover sequencing and candidate eligibility. Single-code tombstone-gap rule (§4.2). Contiguous allocation rule (§4.5). Legacy key finality (§1.1). Added `QDH-E018`–`QDH-E020`; remapped `QDH-E015` to `S64-E030`; confined `QDH-E016` to missing evidence. Standards citations de-dated pending verification. |
| RC2.2 | 2026-11-23 | Added 4.7 defining qdh_audit_gap: the epoch predicate is normative and the coverage scope is stated. Aligned to the RC2.2 package label. |
