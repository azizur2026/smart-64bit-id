# SMART 64-Bit ID v1.42 — Normative Rules Summary

**Status:** Release Candidate 1 — cross-check in progress

This is a navigational summary, not a replacement for `SPECIFICATION.md`. Where details are needed for conformance, consult the normative specification.

## Encoding and profile selection

- A v1.42 identifier is an unsigned 64-bit value with the bit positions specified in the normative document.

- Bits 54–57 (Reserved) must be zero when generating a v1.42 identifier; a v1.42 decoder must reject nonzero Reserved bits as invalid v1.42. Bit 54 remains Reserved; the 5-bit Class expansion is deferred and is not part of v1.42.

- Bits 50–53 carry the encoded Class in v1.42. Encoded Class `0000` is invalid; encoded Class `1001`–`1111` is reserved. The encoded Class must agree with the authoritative Class-property record associated with Engine + Local. Disagreement is S64-E007 CLASS_MISMATCH and requires a hard stop.

- Local 0 is valid; it is not a null or unassigned sentinel.

- Version/Revision must be interpreted before profile-dependent fields. Unknown profiles must not be guessed. A v1.x implementation must not interpret Version 1 as a v1.x identifier.

- A legacy-only v1.4 boundary must explicitly reject an incompatible v1.41 or v1.42 identifier and must not rewrite, truncate, mask, downgrade, or pass it downstream as valid v1.4.

- A failed validation under one profile must not be treated as proof that the identifier belongs to another profile.

- An implementation that stores identifiers from more than one profile must retain the decoder for each profile it stores. Deprecating a decoder is only safe when no stored identifier uses that profile.

## Identity semantics

- The logical identity is associated with its encoded Class, Engine, and Local. In v1.42, the Class field carries the encoded taxonomy value; it is not a marker.

- Role must remain stable for the allocated identifier. The Role bit is immutable for the identifier; it is not immutable for the entity. A change of designation is expressed by retiring the identifier and allocating a new one, with the Class value unchanged. Role is consumed by the application-domain layer; it is not read by the routing or allocation layers.

- The encoded Class and its authoritative Class-property record must remain stable for an allocated identity. Reclassification of an existing identity is not permitted; a Class change requires a new Engine.

- Each Engine is bound to exactly one Class. Multiple Engines may be bound to the same Class, but an Engine must not be bound to more than one Class. Given the Engine, the Class is determined and fixed at allocation time.

- The allocation uniqueness coordinate is Engine + Local; Class does not partition this namespace.

## Allocation safety

- A Local ID successfully allocated in an Engine must never be successfully allocated again within that Engine, whether the allocated identifier remains active or has been retired.

- Exactly one canonical allocation record must exist for each Engine + Local coordinate ever allocated. Two or more canonical allocation records for the same coordinate constitute S64-E009 ALLOCATION_CONFLICT, regardless of their lifecycle States. Retirement must update the existing canonical record rather than create another. Append-only audit events may be stored separately but must not be treated as additional canonical allocation records.

- No two successful allocations in the same Engine may return the same Local value.

- At most one authoritative active allocator may successfully allocate in an Engine namespace at a time; a stale allocator must not commit after its authority ends.

- If an implementation cannot establish safe uniqueness, non-reuse, authoritative state, exclusive allocator authority, or required target-reservation safety, allocation must fail closed.

- When the Local namespace is exhausted, the allocator must not reuse a previously allocated value or revisit a lower Engine ID. It must search Engine IDs numerically greater than the exhausted Engine ID, in ascending order, and select the lowest eligible candidate.

- An Engine ID is eligible only if it is in range, is not bound to a different Class, and either:
  - is already bound to the requested Class and has at least one safely allocatable Local ID remaining; or
  - is unbound and can be bound atomically to the requested Class before allocation.

- An Engine ID bound to another Class must be skipped and must never be reclassified or reassigned. An Engine ID already bound to the requested Class but with no remaining Local IDs must also be skipped.

- Before an identifier is issued through rollover, the target Engine reservation and any required Class binding must be established atomically, with exclusive allocation authority and safe uniqueness/non-reuse. Concurrent controllers must not bind the same unbound Engine to different Classes or allocate duplicate coordinates.

- S64-E022 ENGINE_EXHAUSTED applies when the Local namespace is exhausted and the lowest eligible Engine ID numerically greater than the exhausted Engine ID has been found and safely reserved for rollover. It is not proof of terminal Engine-ID exhaustion.

- S64-E029 ENGINE_ID_SPACE_EXHAUSTED applies only when an authoritative search establishes that no eligible Engine ID numerically greater than the exhausted Engine ID remains. This condition may occur before the maximum numeric Engine ID if every remaining higher ID is ineligible. No wraparound to lower Engine IDs is permitted.

- If a required authoritative query cannot complete, the applicable authoritative-state error, S64-E012 VALIDATION_UNAVAILABLE, must be used rather than reporting a confirmed missing or mismatched record. If target reservation or allocation safety cannot be established, S64-E021 ALLOCATION_SAFETY_UNESTABLISHED applies where appropriate. Neither E022 nor E029 may be used without the evidence required by the specification.

- A retired Engine + Local coordinate is permanently consumed and must not be reissued under any profile of the SMART 64-Bit ID family. There is no release point.

- A coordinate-consumption tombstone must be retained permanently for every consumed coordinate. The tombstone is independent of the retention policy for the full retired record.

## Failure handling

- A detected power cut or hardware failure affecting the allocator, its authoritative state, or the integrity of allocation requires `FAIL_HARD`.

- `FAIL_HARD` is an operational outcome, not an S64 error code. It takes precedence over ordinary allocation-error selection when the specified failure condition applies.

- Under `FAIL_HARD`, the affected allocator must stop issuing identifiers. It must not perform a last-ID lookup, infer the last issued Local or Engine ID, resume from a guessed position, roll back to a potentially reused coordinate, or use rollover as a fallback.

- The allocator must remain unavailable until authoritative state and allocation safety have been established through the explicitly authorized procedure described by the specification. If that cannot be established, allocation remains disabled.

- A power cut or hardware failure must not trigger an automatic retry, resume, or restart of an interrupted migration or allocation operation.

- For an interface that requires an S64 code, S64-E021 ALLOCATION_SAFETY_UNESTABLISHED MAY be reported as the interface-level result when no more specific ordinary condition applies. Reporting an S64 code MUST NOT replace or weaken the operational `FAIL_HARD` requirement.

## Routing and migration

- Normative routing in v1.42 uses Class + Engine. The virtual-engine ID is the 25-bit concatenation of Class (4 bits) and Engine (21 bits), and is a row in the virtual-engine table mapping to a physical engine address.

- A Class mismatch between the encoded Class and the authoritative Class-property record must be detected before physical-engine resolution. S64-E007 CLASS_MISMATCH is a hard stop.

- Physical engine placement may be rearranged administratively for load balancing. The Class binding is fixed. A shift that would move an Engine to a different Class is a violation reported as S64-E015 ENGINE_CLASS_BINDING_VIOLATION.

- Changing Engine creates a new SMART identity. Migration means retirement of the old identifier and allocation of a new identifier. The old identifier is never migrated, reused, or rewritten. The Class value must remain unchanged across retirement and reallocation.

- Migration follows the normative sequence:
  1. The receiving Engine allocates a new Local ID through its authoritative allocation mechanism. The coordinate is consumed, and the new record is created inactive and is not resolvable by ordinary lookups.
  2. The receiving Engine creates the new identifier's authoritative Class-property record.
  3. The new identifier's history chain is linked to the source identifier.
  4. The source record is transitioned to retired and the successor record to active in one atomic transition, or through an equivalent protocol that guarantees the same externally observable result.
  5. Both records are retained, and the source coordinate remains permanently consumed.

- The successor must remain non-resolvable until the atomic transition commits. At no point may both identifiers be resolvable as current identities. A successful ordinary operation must not leave neither identifier resolvable. A separate workflow or on-hold state may be used before commit.

- If the initial allocation fails without a power cut or hardware failure, nothing is retired and the source identifier remains active. If creation of the Class-property record or history-chain link fails, the operation aborts, the source remains active, and the allocated but uncommitted coordinate remains consumed; it is not released.

- If the atomic transition fails without a power cut or hardware failure, the source remains resolvable and the successor remains non-resolvable. The operation may be retried only while authoritative state and allocator authority are positively established.

- Any power cut or hardware failure during migration requires `FAIL_HARD`. The interrupted sequence must not automatically resume or retry, perform a last-ID lookup, or issue an identifier until authoritative state and allocation safety have been established through the authorized procedure.

- The receiving Engine must allocate a new Local ID through its authoritative allocation mechanism. Migration must not copy, preserve, request, or manually assign the source Local ID outside that mechanism.

- The receiving Engine must belong to the same Class as the source identity. A migration into an Engine of a different Class violates the binding rule and is not permitted.

- Each allocated identifier record must record the identifier it replaced, if any, or an explicit marker that it is a first allocation. The history chain must be retained for as long as any identifier in the chain is retained.

- At most one identifier in a history chain may be resolvable by ordinary lookups at any time. A pending successor must remain non-resolvable while the source remains active. The implementation must not declare the transition complete unless the atomic transition has committed.

- A retired identifier's record must be retained indefinitely under the profile that allocated it, as required by that profile. Retention obligations for identifiers allocated under other profiles arise from those profiles, not from v1.42.

- Any old-to-new relationship is recorded in the history chain and must not be inferred from numerical proximity, Engine contiguity, or Local adjacency.

## Serialization and conformance

- Canonical binary serialization is unsigned 64-bit big-endian/network byte order.

- Field extraction must use the defined bit positions and unsigned/logical-shift semantics.

- A required authoritative query that cannot complete must not be treated as evidence that a record is missing, mismatched, or duplicated.

- Duplicate canonical records for the same Engine + Local coordinate are prohibited regardless of lifecycle state. Duplicates must be rejected before any record is selected for Class comparison or routing.

- An implementation that cannot satisfy applicable safety, uniqueness, non-reuse, validation, Class-property, retention, history-chain, or interoperability requirements must not claim v1.42 conformance.

The normative specification remains the controlling source for exact requirements, scope, and interpretation.
