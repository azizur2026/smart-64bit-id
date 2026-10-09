# SMART 64-Bit ID v1.41 — Technical Overview

**Document type:** Project technical overview; not peer-reviewed research.  
**Normative source:** [v1.41 Specification](../SPECIFICATION.md)

## Abstract

SMART 64-Bit ID v1.41 defines a fixed-width unsigned 64-bit identifier profile. Its 54-bit Identity Core consists of Class, Engine, and Local. The Engine + Local pair defines the allocation uniqueness coordinate, while the current routing model selects an Engine namespace and performs a Local lookup within it. The upper 10 bits carry Version, Revision, Role, and Reserved fields; Role remains semantically immutable for an allocated identity. The profile specifies non-reusing Local allocation, stale-allocator exclusion, reserved-bit validation, profile-aware legacy boundaries, and canonical big-endian binary serialization. It does not prescribe a particular allocator implementation, database, consensus mechanism, authentication system, or deployment topology.

## 1. Problem boundary

Distributed applications need identifiers that remain stable and resolvable across allocation domains. Identifier layout alone cannot guarantee uniqueness: allocation authority, namespace governance, recovery, and non-reuse must be handled by the implementation. SMART specifies required outcomes for allocation safety without mandating a single mechanism.

## 2. Structure

The fields from least-significant to most-significant bits are Local (29), Engine (21), Class (4), Reserved (4), Role (1), Revision (4), and Version (1). The Identity Core is Class + Engine + Local (54 bits). The allocation coordinate is Engine + Local (50 bits); Class does not partition it.

## 3. Allocation and routing

The Engine identifies a logical namespace and routing destination. Local identifies an allocation within that namespace. A Local value once successfully allocated in an Engine must never be allocated again in that Engine. If an implementation cannot prove safe uniqueness and non-reuse, allocation must fail. A stale allocator must not successfully commit after losing authority.

The normative route is SMART ID → Engine → Local lookup. A future composite Class + Engine routing/sharding key is not a v1.41 requirement and remains deferred.

## 4. Identity stability and migration

Class and the Identity Core are stable for an allocated identity. Role is also semantically immutable. Changing Engine creates a new identity and requires a fresh Local from the receiving Engine's authoritative allocator. Any relationship between old and new identities is external history or relationship data.

## 5. Compatibility and serialization

Version/Revision must be selected before interpreting profile-dependent fields. Version 0 / Revision 0000 identifies legacy v1.4; Version 0 / Revision 0001 identifies v1.41. The v1.4 Region field must not be reinterpreted as v1.41 Class and Reserved. Canonical binary representation is unsigned 64-bit big-endian/network byte order.

## 6. Limitations and evidence

The format contains no timestamp and does not guarantee chronological ordering. It is not an authenticator, credential, or authorization mechanism. SMART does not claim universal performance superiority over alternative identifiers. The archived research files describe specific earlier experiments and must not be treated as proof of v1.41 performance without a study that explicitly tests v1.41 under documented conditions.

## 7. Normative authority

This overview is explanatory. The [v1.41 Specification](../SPECIFICATION.md) controls field definitions, validation, conformance, and interpretation.
