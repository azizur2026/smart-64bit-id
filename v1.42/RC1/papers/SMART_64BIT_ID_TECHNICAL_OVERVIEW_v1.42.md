# SMART 64-Bit ID v1.42 — Technical Overview

**Status:** Release Candidate 1 — cross-check in progress
**Document type:** Project technical overview; not peer-reviewed research.
**Normative source:** SPECIFICATION.md

## Abstract

SMART 64-Bit ID v1.42 defines a fixed-width unsigned 64-bit identifier profile. Its 54-bit Identity Core consists of Class, Engine, and Local. In v1.42 the Class field carries the encoded taxonomy value, and the encoded Class must agree with the authoritative Class-property record. Each Engine is bound to exactly one Class; multiple Engines may share a Class. The allocation uniqueness coordinate is Engine + Local, while routing uses Class + Engine through a virtual-engine table that maps to a physical engine address. The upper 10 bits carry Version, Revision, Role, and Reserved fields; Role remains immutable for the allocated identifier. The profile specifies non-reusing Local allocation, permanent consumption of retired coordinates, permanent coordinate tombstones, retention of retired records, a per-entity history chain with at most one resolvable identifier at any time, stale-allocator exclusion, reserved-bit validation, profile-aware legacy boundaries, and canonical big-endian binary serialization. It does not prescribe a particular allocator implementation, database, consensus mechanism, authentication system, virtual-engine table implementation, or deployment topology.

## 1. Problem boundary

Distributed applications need identifiers that remain stable and resolvable across allocation domains. Identifier layout alone cannot guarantee uniqueness: allocation authority, namespace governance, recovery, and non-reuse must be handled by the implementation. SMART specifies required outcomes for allocation safety without mandating a single mechanism.

## 2. Structure

The fields from least-significant to most-significant bits are Local (29), Engine (21), Class (4), Reserved (4), Role (1), Revision (4), and Version (1). In v1.42 the Class bits 50–53 carry the encoded taxonomy value. Encoded Class 0000 is invalid; 1001–1111 is reserved. The encoded Class must agree with the authoritative Class-property record associated with Engine + Local. The allocation uniqueness coordinate is Engine + Local (50 bits); Class does not partition it. Each Engine is bound to exactly one Class, fixed at allocation time; multiple Engines may share a Class. The identifier is self-identifying: Version and Revision determine the profile before any profile-dependent field is interpreted.

## 3. Allocation and routing

The Engine identifies a logical namespace and, together with the Class, the virtual-engine routing target. Local identifies an allocation within that namespace. A Local value once successfully allocated in an Engine must never be allocated again in that Engine, including after retirement. If an implementation cannot prove safe uniqueness and non-reuse, allocation must fail. A stale allocator must not successfully commit after losing authority. When an Engine's Local namespace is exhausted, the controller advances to the next Engine ID within the same Class; existing identifiers remain valid and routable and are not migrated. When no further Engine ID is available within the Class, allocation fails terminally.

The normative route is SMART ID → Class + Engine → virtual-engine ID → physical engine address → Local lookup. The virtual-engine ID is the 25-bit concatenation of Class and Engine, not a hash. This differs from v1.41, which routes on Engine alone.

## 4. Identity stability, retirement, and migration

Class and the Identity Core are stable for an allocated identity. Role is immutable for the allocated identifier but not for the entity; a change of designation is expressed by retiring the identifier and allocating a new one, with the Class unchanged. Retirement is a record-level transition; State is not encoded in the identifier. Workflow status during a transition is allocator-level and implementation-specific.

Allocation precedes retirement. The sequence is: allocate new (inactive), create Class-record, link history chain, activate new and retire old such that at most one identifier in the chain is resolvable at any time. If any step before activation fails, the source identifier remains active.

A retired coordinate is permanently consumed and is not reissued under any profile of the SMART 64-Bit ID family. A coordinate-consumption tombstone is retained permanently. A retired record is retained indefinitely, for as long as the profile under which it was allocated remains in force. Each identifier's history chain records the identifier it replaced, if any. Any relationship between old and new identities is recorded in the chain, not inferred from numerical proximity.

This retirement model is consistent with GS1's permanent GTIN non-reuse rule and NIST SP 800-53 IA-4's non-reuse requirement; see BIBLIOGRAPHY.md.

## 5. Compatibility and serialization

Version/Revision must be selected before interpreting profile-dependent fields. Version 0 / Revision 0000 identifies legacy v1.4; Version 0 / Revision 0001 identifies v1.41; Version 0 / Revision 0010 identifies v1.42. The v1.4 Region field must not be reinterpreted as v1.41 Class-marker and Reserved or as v1.42 encoded Class and Reserved. v1.4, v1.41, and v1.42 coexist.

Under normal validation, mutual invalidity between v1.41 and v1.42 produces rejection at profile identification, because each identifier's Revision does not select the other profile. If the fields were force-interpreted under the other profile's field rules, additional field-level incompatibilities would appear; that observation is informative, not the rejection reason. Canonical binary representation is unsigned 64-bit big-endian/network byte order.

## 6. Deferred expansion

A 5-bit Class expansion — reallocating bit 54 from Reserved to Class — is a future option and is not part of v1.42. Bit 54 remains Reserved and must be zero in v1.42. Implementations must not interpret bit 54 as part of Class.

## 7. Limitations and evidence

The format contains no timestamp and does not guarantee chronological ordering. It is not an authenticator, credential, or authorization mechanism. The Class field directly exposes the entity category; applications with confidentiality requirements should account for that. Coordinate permanence, retired-record retention, and permanent tombstones impose a real operational cost that grows monotonically with the number of retirements. Because Class and Engine occupy the most-significant bits, concurrent inserts across different Classes produce scattered B-Tree page writes; this is an inherent trade-off of spatial prefix routing, mitigated at the database layer. SMART does not claim universal performance superiority over alternative identifiers. The archived research files describe specific earlier experiments and must not be treated as proof of v1.42 performance without a study that explicitly tests v1.42 under documented conditions.

## 8. Normative authority

This overview is explanatory. The SPECIFICATION.md controls field definitions, validation, conformance, and interpretation.
