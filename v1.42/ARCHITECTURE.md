# SMART 64-Bit ID v1.42 — Architecture

**Status:** Release Candidate 1 — cross-check in progress
**Status note:** Explanatory, non-normative. See SPECIFICATION.md for conformance requirements.

## 1. Architectural boundary

SMART specifies an identifier layout, profile selection, identity semantics, allocation-safety requirements, routing semantics, and retirement and migration constraints. It does not prescribe a particular database, consensus algorithm, replication topology, API, transport, control plane, virtual-engine table implementation, physical placement arrangement, or cloud platform.

## 2. Field layout

| Bits | Width | Field | Meaning |
|---|---|---|---|
| 0–28 | 29 | Local | Allocation-local identifier |
| 29–49 | 21 | Engine | Engine/namespace identifier |
| 50–53 | 4 | Class | Encoded taxonomy value |
| 54–57 | 4 | Reserved | Must be zero in v1.42 |
| 58 | 1 | Role | Self-representing/dependent designation |
| 59–62 | 4 | Revision | Profile selector |
| 63 | 1 | Version | Specification-family selector |

Bit 54 remains Reserved in v1.42. The 5-bit Class expansion is deferred and is not part of v1.42.

## 3. Identity and representation

The 54-bit Identity Core is:

```text
Class (4) + Engine (21) + Local (29) = 54 bits
```

For an allocated identity, the Identity Core is stable. In v1.42, the Class field carries the encoded taxonomy value; this differs from v1.41, where the same field is a zero marker. The structural composition is preserved across profiles, and the semantic difference is stated explicitly.

The upper 10 bits form the representation/control area, but their mutability is not uniform: Role is semantically immutable for the allocated identifier even though it resides in that area. Role is not immutable for the entity itself. A change of designation is expressed by retiring the identifier and allocating a new one, with the Class unchanged. A representation with a conflicting Role is non-conforming.

The identity coordinate used for allocation uniqueness is Engine + Local. Class does not create a separate allocation namespace. Therefore, the same Engine/Local pair must not be treated as two independently allocated identities merely because the encoded Class bits differ.

## 4. Class and Role

The encoded Class is a compact category; it does not establish a universal ontology or decide who has authority to classify an entity. In v1.42, bits 50–53 carry the encoded taxonomy value. Encoded Class 0000 is invalid; 1001–1111 is reserved. The encoded Class must agree with the authoritative Class-property record associated with Engine + Local. Disagreement is a hard stop.

Each Engine is bound to exactly one Class. Multiple Engines may be bound to the same Class, but an Engine must not be bound to more than one Class. Given the Engine, the Class is determined and fixed at allocation time. Reclassification of an existing Engine is not permitted; a Class change requires a new Engine.

Role distinguishes a self-representing designation (1) from a dependent designation (0) in the applicable identification relationship. It does not itself establish legal capacity, ownership, authority, autonomy, human status, or organizational status. Role is fixed for the allocated identifier; the entity's designation may change over time, and each change is expressed by retirement and reallocation. Associations between identities are external relationship data and cannot be inferred from Role alone. Role is consumed by the application domain layer; it is not read by the routing or allocation layers.

## 5. Allocation authority

Each Engine requires an authoritative allocation mechanism. A Local value successfully allocated in an Engine must never be successfully allocated again in that Engine, including after restart, restore, failover, ownership transfer, recovery, or retirement. A stale allocator must not commit after its authority ends. SMART specifies these outcomes, not the mechanism used to guarantee them.

A retired Engine + Local coordinate is permanently consumed and must not be reissued under any profile of the SMART 64-Bit ID family. There is no release point. A coordinate-consumption tombstone must be retained permanently for every consumed coordinate, independent of the retention policy for the full retired record. A retired identifier's full record must be retained for as long as the profile under which it was allocated remains in force.

The Engine and Local fields provide 2^21 and 2^29 possible values respectively. Their combined coordinate space is 2^50 (1,125,899,906,842,624) Engine/Local pairs, subject to actual allocation, retirement, and governance policy. Because a retired coordinate is permanently consumed and a designation change consumes one coordinate in the same Class, the effective allocatable space decreases monotonically over time. When an Engine's Local namespace is exhausted, the controller advances to the next Engine ID within the same Class, with the Class fixed across rollover. When no further Engine ID is available within the Class, allocation fails terminally.

## 6. Routing

The normative routing path in v1.42 is:

```text
SMART ID → extract Class + Engine → virtual-engine ID → physical engine address → extract/lookup Local → entity
```

The virtual-engine ID is the 25-bit concatenation of Class (4 bits) and Engine (21 bits). It is not a hash and is not a surrogate. Each virtual-engine ID is a row in the virtual-engine table, mapping to a physical engine address (IP/MAC).

Engine is a logical namespace/routing selector, not necessarily a physical host or geographic region. Class participates in the routing key in v1.42; this differs from v1.41, where Class-marker is zero and routing uses Engine alone. A Class mismatch between the encoded Class and the authoritative Class-property record is detected before virtual-engine lookup.

Physical placement is operational and may be rearranged by a System Admin for load balancing. The Class binding is fixed; a shift that would move an Engine to a different Class is a violation.

## 7. Retirement and migration

The identifier is self-identifying: bits 63 and 59–62 (Version and Revision) determine the profile before any profile-dependent field is interpreted. A decoder must read Version and Revision first; the profile-specific field mask follows.

Migration means retirement of the old identifier and allocation of a new identifier. Allocation precedes retirement. The old identifier is never migrated, reused, or rewritten. The receiving Engine must allocate a new Local through its authoritative allocator; migration cannot copy or manually assign the source Local. The Class value must remain unchanged across retirement and reallocation; a reallocation into an Engine of a different Class is a violation.

The migration sequence is: allocate new (inactive), create Class-record, link history chain, activate new and retire old such that at most one identifier in the chain is resolvable at any time. State (active/retired) is record-level; workflow status (such as "on hold" during transition) is allocator-level and implementation-specific. If any step before activation fails, the source identifier remains active.

Each identifier record records the identifier it replaced, if any. This is the history chain. At most one identifier in a chain is resolvable by ordinary lookups at any time. A chain in which a pending successor exists and no identifier is resolvable is non-conforming. The history chain is the authoritative record of which coordinates the entity has consumed.

An Engine may become unavailable or be retired; the identifier remains an identifier. SMART does not encode a successor Engine or prescribe resolution behavior for an unavailable namespace.

## 8. Profile and wire boundary

Version and Revision select the profile before profile-dependent fields are interpreted. Version 0, Revision 0000 denotes v1.4; Version 0, Revision 0001 denotes v1.41; Version 0, Revision 0010 denotes v1.42. Unsupported profiles must not be guessed. Canonical binary serialization is unsigned 64-bit big-endian/network byte order.

v1.4, v1.41, and v1.42 coexist. None supersedes another. Mutual invalidity is intentional.

Under normal validation, a cross-profile identifier is rejected at profile identification because its Version/Revision does not select the target profile. This is the decisive rejection. Independently, if the fields are force-interpreted under the other profile's field rules, the Class field also violates that profile's requirements: a v1.42 identifier force-read under v1.41 field rules has nonzero Class-marker bits; a v1.41 identifier force-read under v1.42 field rules has encoded Class 0000. The field-level explanation is informative; profile selection is normative.

An implementation that stores identifiers from more than one profile must retain the decoder for each profile it stores. Deprecating a decoder is only safe when no stored identifier uses that profile.
