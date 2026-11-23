# SMART 64-Bit ID v1.42 — Normative Rules Summary

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010

This is a navigational summary, not a replacement for `SPECIFICATION.md`. Where details are needed
for conformance, consult the normative specification.

## Encoding and profile selection

- A v1.42 identifier is an unsigned 64-bit value with the bit positions specified in the normative
  document: Version 63, Revision 59–62, Role 58, Reserved 54–57, Class 50–53, Engine 29–49,
  Local 0–28.

- Version and Revision must be interpreted before any profile-dependent field. Unsupported profiles
  must not be guessed. A v1.x implementation must not interpret Version 1 as a v1.x identifier.

- Version 0, Revision `0010` is v1.42. Revision `0001` is v1.41. Revision `0000` (v1.4) is obsolete
  and unsupported (`S64-E002`).

- Bits 54–57 must be zero when generating a v1.42 identifier; a v1.42 decoder must reject nonzero
  Reserved bits. Bit 54 remains Reserved; the 5-bit Class expansion is deferred.

- Bits 50–53 carry the encoded Class. `0000` is invalid; `1001`–`1111` is reserved. The encoded
  Class must agree with the authoritative Class-property record; disagreement is `S64-E007` and a
  hard stop.

- Local 0 is valid; it is not a null or unassigned sentinel.

- A profile-restricted boundary must reject an incompatible identifier and must not rewrite,
  truncate, mask, downgrade, or pass it downstream as valid for the target profile.

- A failed validation under one profile must not be treated as proof that the identifier belongs
  to another profile.

- An implementation that stores identifiers from more than one profile must retain the decoder for
  each profile it stores.

## Identity semantics

- The 54-bit Identity Core is Class + Engine + Local, and it is the uniqueness key. A Virtual
  Engine is Class + Engine. A Local coordinate is unique only within its Virtual Engine, so
  `(1, 120, 500)` and `(2, 120, 500)` are distinct identities.

- Each supported Class has its own independent 21-bit Engine pool. The same numerical Engine value
  in two Classes is two different Virtual Engines. Engine numbers are unique only within a Class
  pool.

- A Virtual Engine is permanently bound to one Class. The Class binding must not be changed; a
  change of Class requires a new identity, and the old Identity Core remains permanently consumed
  (`S64-E015`).

- Role is immutable for the allocated identifier, and is consumed by the application-domain layer,
  not by routing or allocation. A designation change is expressed by retirement and reallocation,
  with the Class unchanged.

- Profile provenance is recorded per identity and per generation. The profile recorded for an
  identity must match the profile of the generation epoch in which it was allocated, as recorded in
  the control-table lineage; mismatch is `S64-E030`. The engine's current profile governs new
  allocations only. An identity record's recorded profile must not be rewritten.

## Allocation safety

- A Local coordinate successfully allocated in a Virtual Engine must never be successfully
  allocated again in that Virtual Engine, whether the identifier remains active or has been
  retired.

- Exactly one canonical allocation record must exist for each Identity Core ever allocated. Two or
  more is `S64-E009` regardless of lifecycle state. Retirement updates the existing record; it must
  not create a second one. Append-only audit events are not canonical records.

- No two successful allocations may return the same Identity Core.

- At most one authoritative active allocator may commit within a Virtual Engine at a time, and a
  stale allocator must not commit after its authority ends (`S64-E019`, `S64-E020`).

- Allocation may proceed only while the Virtual Engine is `STATE_ACTIVE` and its hosting node is
  operational. Allocation on a non-active node is `S64-E021` and, in QDH terms, `QDH-E007`.

- If uniqueness, non-reuse, authoritative state, exclusive authority, host fitness, or target
  reservation cannot be established, allocation fails closed with `S64-E021`.

- Validation order for allocation and administrative operations is: authority, fencing and epoch;
  then coordinate and lifecycle; then administrative invariants; then rollover and exhaustion.
  No ordering may permit a stale allocator or prior-generation writer to commit.

## Engine exhaustion and rollover

- When a Local namespace is exhausted, the allocator must not reuse a previously allocated value
  and must not revisit a lower Engine number. It searches Engine numbers numerically greater than
  the exhausted Engine, ascending, within the same Class pool.

- A candidate is a Virtual Engine in `STATE_UNALLOCATED`, or an existing engine whose prior
  allocator authority has been conclusively invalidated before adoption. An engine under a live
  lease must not be adopted (`S64-E020`).

- A forward reservation must exist before the final Local coordinate is issued. Rollover is
  exhaustion handling, not a failure-recovery path.

- `S64-E022` applies when the namespace is exhausted and the lowest eligible higher Engine has been
  found and safely reserved. It reports a completed rollover; it is not a failure.

- `S64-E029` applies only when an authoritative search establishes that no eligible higher Engine
  remains in the Class pool. It can occur before Engine 2,097,151. No wraparound is permitted.

- If the authoritative search cannot complete, or reservation safety cannot be established, the
  applicable authority or safety failure is reported instead of `S64-E022` or `S64-E029`.

- Expansion of the Engine space requires a new profile or a separately defined Class assignment.
  Existing identifiers are never renumbered.

## Permanent consumption and retention

- A retired Identity Core is permanently consumed and must not be reissued under any profile of the
  family (`S64-E016`). There is no release point.

- A coordinate-consumption tombstone must be retained permanently for every consumed coordinate,
  independent of the retention period for the full retired record.

- A retired record must be retained for as long as the profile under which it was allocated
  remains in force (`S64-E017`). It must preserve the Identity Core, encoded Class, recorded
  profile, allocating generation epoch, Role, coordinate, retirement status, and history-chain
  link.

- A retired record's immutable fields must not be modified (`S64-E024`), and a retired identity
  must not be reactivated or treated as free (`S64-E025`).

## Failure handling

- A detected power cut or hardware failure affecting the allocator, its authoritative state, or the
  integrity of allocation requires `FAIL_HARD`.

- `FAIL_HARD` is an operational outcome, not an S64 code. It takes precedence over ordinary
  allocation-error selection.

- Under `FAIL_HARD` the allocator must stop issuing identifiers and must not perform a last-ID
  lookup, infer a position, resume from a guess, roll back to a potentially reused coordinate, use
  rollover as a fallback, or automatically retry or resume.

- Under v1.42 the allocator remains unavailable until the QDH lifecycle establishes authoritative
  state and allocation safety. Under pre-v1.42 rules no recovery existed and the engine was retired
  permanently; such engines are not eligible for QDH reclamation.

- For an interface that requires an S64 code, `S64-E021` may be reported as the interface-level
  result when no more specific ordinary condition applies. Reporting an S64 code must not replace
  or weaken `FAIL_HARD`.

## Retirement, migration, and profile change

- Migration means retirement of the old identifier and allocation of a new one. The old identifier
  is never migrated, reused, or rewritten. Allocation precedes retirement.

- The sequence is: allocate the successor inactive; create its Class-property record; link the
  history chain, inheriting the source chain root; then transition the source to retired and the
  successor to active atomically, or by a protocol with the same observable result.

- At most one identifier in a history chain may be resolvable at any time. A pending successor
  remains non-resolvable while the source is active. A successful ordinary operation must not leave
  neither identifier resolvable.

- If allocation fails without a power cut or hardware failure, the source remains active. A consumed
  but uncommitted coordinate remains consumed; it is not released.

- The receiving Virtual Engine must allocate through its authoritative mechanism and must belong to
  the same Class. It must not copy or manually assign the source Local coordinate.

- A first allocation self-roots its history chain; a successor must inherit its predecessor's root.
  A successor that does not is non-conforming.

- A profile change is a distinct explicit operation under the specification's upgrade procedure. It
  opens a new generation, records the `PROFILE_UPGRADE` closure reason, does not alter the Class
  binding, and does not rewrite any identity record's recorded profile.

## Routing

- Normative routing uses Class + Engine. The Virtual Engine ID is the 25-bit concatenation of Class
  and Engine, resolving through the control table to the network address of the hosting node.

- A network or hardware address is a locator. It is not identity, not evidence for reconstructing
  Class, and must not be used to authenticate a host.

- A Class mismatch between the encoded Class and the authoritative record must be detected before
  physical resolution (`S64-E007`).

- Physical placement may be rearranged for operational purposes provided the Class binding, active
  profile, generation epoch, watermark, and lineage are unchanged, and the target node is
  operational.

## QDH

- QDH is the recovery programme: Quarantine, Database Engineering, Hardware Engineering.

- A `(Class, Engine)` occupies exactly one of eight states. Quarantine is a universal entry
  transition: every non-terminal state can enter `STATE_QUARANTINED`.

- Reclamation requires, in order: quarantine with durable lease revocation; verification of the
  first never-consumed Local coordinate from durable evidence; hardware sanitization with
  attestation, nonce freshness, certificate validity, revocation freshness and allowlist match;
  atomic generation commit; then reactivation with a new epoch-bound lease.

- Reclamation never reuses a coordinate, never resets the watermark to zero, and never changes the
  engine's profile.

- A key retired outside QDH is final and must not be re-entered.

## Serialization and conformance

- Canonical binary serialization is unsigned 64-bit big-endian network byte order, preserving all
  64 bits.

- Field extraction must use the defined bit positions and logical right-shift semantics.

- A required authoritative query that cannot complete must not be treated as evidence that a record
  is missing, mismatched, duplicated, or that provenance disagrees.

- An implementation that cannot satisfy applicable safety, uniqueness, non-reuse, validation,
  Class-property, provenance, retention, history-chain, host-fitness, epoch-fencing, or
  interoperability requirements must not claim v1.42 conformance.

## Compatibility with Release Candidate 1

RC1 remains supported; identifiers allocated under it remain valid, and both candidates carry
Revision `0010`. Two emissions differ: profile provenance is `S64-E030` here and was `S64-E015` in
RC1, and `S64-E031` for an inadmissible transition had no RC1 equivalent. A peer may report a
different code for the same condition while both claim `0010`. Implementations built against RC1
must adopt both codes before claiming conformance to this revision.

The normative specification remains the controlling source for exact requirements, scope, and
interpretation.
