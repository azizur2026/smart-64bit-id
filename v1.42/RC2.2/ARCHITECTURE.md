# SMART 64-Bit ID v1.42 — Architecture

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010
**Status note:** Explanatory, non-normative. See `SPECIFICATION.md` for conformance requirements.

## 1. Architectural boundary

SMART specifies an identifier layout, profile selection, identity semantics, allocation-safety
requirements, routing semantics, and retirement and migration constraints. It does not prescribe a
particular database, consensus algorithm, replication topology, API, transport, control plane,
physical placement arrangement, or cloud platform. It does define the logical structure of the
Virtual Engine control table, because allocation, routing and recovery all depend on it.

## 2. Field layout

| Bits | Width | Field | Meaning |
|---|---|---|---|
| 0–28 | 29 | Local | Allocation-local identifier |
| 29–49 | 21 | Engine | Engine number within a Class pool |
| 50–53 | 4 | Class | Encoded taxonomy value |
| 54–57 | 4 | Reserved | Must be zero in v1.42 |
| 58 | 1 | Role | Self-representing / dependent designation |
| 59–62 | 4 | Revision | Profile selector |
| 63 | 1 | Version | Specification-family selector |

Bit 54 remains Reserved in v1.42. The 5-bit Class expansion is deferred and is not part of v1.42.

## 3. Identity and representation

The 54-bit Identity Core is Class + Engine + Local (4 + 21 + 29).

For an allocated identity the Identity Core is stable, and it is the uniqueness key of the whole
system. A Virtual Engine is identified by Class + Engine. Its Local namespace is unique only within
that Virtual Engine.

The distinction matters because each Class has its own independent 21-bit Engine pool. The same
numerical Engine value in two Classes denotes two different Virtual Engines with separate Local
namespaces. `(1, 120, 500)` and `(2, 120, 500)` are therefore distinct identities, not two views of
one coordinate.

A v1.41 identifier is the exception in appearance only: bits 50–53 are a zero Class marker there,
and Class is resolved from the authoritative table, so its coordinate space is structurally
disjoint from v1.42's. That disjointness is what allows the two profiles to coexist without
coordinate translation.

The upper 10 bits form the representation/control area, but their mutability is not uniform: Role
resides in that area yet is semantically immutable for the allocated identifier. Role is not
immutable for the entity; a designation change is expressed by retirement and reallocation with the
Class unchanged.

## 4. Class and Role

The encoded Class is a compact category; it does not establish a universal ontology or decide who
has authority to classify an entity. Encoded Class `0000` is invalid; `1001`–`1111` is reserved. The
encoded Class must agree with the authoritative Class-property record.

Each Virtual Engine is bound to exactly one Class, permanently. Multiple Engines may share a Class.
Reclassification is not permitted; a Class change requires a new identity, and the old Identity Core
remains permanently consumed.

The Class-property record stores Class and profile as explicit, queryable columns. Neither is
inferred from bit patterns, thresholds, or identifier ranges, so provenance survives data
corruption, restore, and future profile assignment.

Role distinguishes a self-representing designation (1) from a dependent designation (0). It does
not establish legal capacity, ownership, authority, autonomy, human status, or organizational
status. It is consumed by the application domain layer, not by routing or allocation.

## 5. Allocation authority

Each Virtual Engine requires an authoritative allocation mechanism. A Local coordinate allocated
once must never be allocated again in that Virtual Engine, including after restart, restore,
failover, ownership transfer, recovery, or reclamation.

Safety rests on three properties: durable allocation evidence independent of the allocator node; a
lease watermark recorded before the allocator issues from a range; and epoch-fenced writes at the
database layer. The specification states the properties, not the mechanism.

The Engine and Local fields provide 2^21 and 2^29 values respectively, so each Virtual Engine has a
2^29 coordinate space, and each Class pool has 2^50. Because retired coordinates are permanently
consumed, the allocatable space decreases monotonically. When a Local namespace is exhausted the
controller advances to the next Engine within the same Class; when the pool is exhausted, allocation
fails terminally.

## 6. Virtual Engine control table

The control table is keyed by Class + Engine and holds at minimum the active profile, generation
epoch, lifecycle state, Local watermark, hosting-node reference, allocator-authority reference, and
append-only lineage. It is authoritative for binding, profile, epoch and state; it is not
authoritative for consumption, which rests on durable evidence and permanent tombstones.

Two entity levels exist: a physical node, identified independently of its addresses, and Virtual
Engines referencing a node. A flat engine-to-address mapping is insufficient, because node-wide
quarantine needs the node as an entity.

Network and hardware addresses are locators. They are not identity, not evidence for reconstructing
Class, and not authenticators; host trust comes from hardware attestation and a signed, epoch-bound
lease.

Four roles are separated: the controller writes the control table, the allocator writes Local
coordinates, the QDH policy engine advances epochs and lifecycle states, and the auditor is
read-only. The control table must be replicated to a store independent of any single node, because
for a v1.41 engine the row is the sole record of its Class.

## 7. Routing

The routing path is: SMART identifier → Version/Revision → Class + Engine → Virtual Engine row →
network address of the hosting node → Local lookup → identity.

The Virtual Engine ID is the 25-bit concatenation of Class and Engine. It is not a hash and not a
surrogate: it is the composite primary key of a control-table row.

Engine is a logical namespace and routing selector, not necessarily a physical host or region.
Class participates in the routing key in v1.42, unlike v1.41's Engine-alone rule. A Class mismatch is
detected before physical resolution.

Physical placement is operational and may be rearranged, provided the Class binding, profile, epoch
and watermark are unchanged, and the target node is operational.

## 8. Retirement and migration

Migration means retirement of the old identifier and allocation of a new one. Allocation precedes
retirement; the old identifier is never migrated, reused, or rewritten.

Sequence: allocate the successor inactive through the receiving engine's authoritative allocator;
create its Class-property record; link the history chain, inheriting the source chain root; then
activate the successor and retire the source atomically, or by a protocol with the same observable
result. At most one identifier in a chain is resolvable at any time.

A first allocation self-roots its chain. A successor that does not inherit its predecessor's root
is non-conforming, because the one-resolvable index would then enforce nothing.

Profile change is not migration. It is a separate explicit operation that opens a new generation,
records the `PROFILE_UPGRADE` closure reason, leaves the Class binding untouched, and does not
rewrite any recorded profile. Identity validation compares an identity against the profile of its
allocation generation, so pre-upgrade identities remain valid.

## 9. QDH

`FAIL_HARD` remains an operational outcome under v1.42; what the profile adds is a governed
recovery path. QDH is Quarantine, Database Engineering, Hardware Engineering.

A faulty node places the node and every hosted Virtual Engine into quarantine. Each engine then
passes independently through: database-engineering verification of the first never-consumed
coordinate from durable evidence; hardware sanitization and attestation; atomic epoch commit with
lineage append; and controlled reactivation with a new epoch-bound lease.

Reclamation never reuses a coordinate, never resets the watermark, and never changes the profile.
It increments the generation epoch so that stale writers are fenced out at the database boundary.
An engine permanently retired under pre-v1.42 rules is not eligible, and a key retired outside QDH
is final.

## 10. Profile and wire boundary

Version and Revision select the profile before profile-dependent fields are interpreted. Version 0,
Revision `0010` is v1.42; Revision `0001` is v1.41; Revision `0000` (v1.4) is obsolete and
unsupported. Unsupported profiles must not be guessed.

Canonical binary serialization is unsigned 64-bit big-endian network byte order.

v1.41 and v1.42 coexist. Mutual invalidity is intentional: under normal validation a cross-profile
identifier is rejected at profile identification, which is the decisive rejection. Field-level
incompatibilities are informative only.

An implementation that stores identifiers from more than one profile must retain the decoder for
each profile it stores.
