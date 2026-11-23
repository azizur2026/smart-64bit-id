# SMART 64-Bit ID v1.42 — Specification

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Supersedes:** No — v1.4 and v1.41 remain separate profiles
**Document purpose:** Normative technical specification for SMART 64-Bit ID v1.42

## 1. Scope

SMART 64-Bit ID v1.42 defines a 64-bit identifier format for persistent identification of entities and associated or dependent identities.

This specification defines:

- the 64-bit binary layout;
- the encoded Class field and its relationship to the authoritative Class-property record;
- identity-core semantics;
- the binding of an Engine to exactly one Class;
- virtual-engine composition and its role in routing;
- Role semantics and the retirement-and-reallocation path for a change of designation;
- Version and Revision profile selection;
- reserved-bit requirements;
- Engine and Local ID allocation semantics;
- Engine exhaustion and rollover behavior;
- retirement, migration, the permanence of retired records, and the identifier history chain;
- routing semantics;
- compatibility boundaries with legacy v1.4 and with v1.41;
- canonical binary serialization;
- decoding and validation requirements; and
- implementation conformance requirements.

This specification defines the 64-bit identifier format, the meaning of its fields, the invariants that must hold for an allocated identifier across its lifetime, the conditions under which an identifier is valid under this profile, and the properties that routing and allocation must preserve. It does not define the operational systems that implement it, the ontology that Class labels presuppose, the criteria by which an entity is designated self-representing or dependent, the physical or administrative machinery of routing and allocation, or the governance under which any of these are determined. Those are matters for the systems and authorities that adopt this profile; the profile states the properties those systems must preserve when they operate on identifiers allocated under it.

An identifier valid under this profile carries an encoded Class value in bits 50–53. That encoded value is the primary source of Class at validation; the authoritative Class-property record is the verification source. This differs from v1.41, where bits 50–53 are a zero-valued representation marker and the effective Class is resolved entirely through the authoritative record.

The identifier is self-identifying: bits 63 and 59–62 (Version and Revision) determine the profile before any profile-dependent field is interpreted. A decoder MUST read Version and Revision first; the profile-specific field mask follows.

## 2. 64-Bit Layout

A v1.42 identifier is an unsigned 64-bit value.

Bits are numbered from bit 0, the least-significant bit (LSB), through bit 63, the most-significant bit (MSB).

```text
63 62 61 60 59 58 57 56 55 54 53 52 51 50 49 ........ 29 28 ........ 0
┌──────────┬───────────────┬──────────┬──────────────────┬──────────────────┬─────────────────────────┬─────────────────────┐
│ Version  │ Revision      │ Role     │ Reserved         │ Class            │ Engine                  │ Local               │
│ 1 bit    │ 4 bits        │ 1 bit    │ 4 bits           │ 4 bits           │ 21 bits                 │ 29 bits             │
└──────────┴───────────────┴──────────┴──────────────────┴──────────────────┴─────────────────────────┴─────────────────────┘
```

### 2.1 Field allocation

| Bits | Width | Field | Requirement |
|---|---:|---|---|
| 0–28 | 29 | Local | Allocation-local identifier |
| 29–49 | 21 | Engine | Engine / namespace identifier |
| 50–53 | 4 | Class | Encoded taxonomy value; 0001–1000 assigned; 0000 invalid; 1001–1111 reserved |
| 54–57 | 4 | Reserved | MUST be 0000 in v1.42 |
| 58 | 1 | Role | Self-representing / dependent designation |
| 59–62 | 4 | Revision | Profile selector; 0010 for v1.42 |
| 63 | 1 | Version | Specification-family selector; 0 for v1.42 |

### 2.2 Meaning of the Class field

For v1.42, bits 50–53 carry the encoded taxonomy value of the identity.

The encoded Class is the primary source of Class at validation. It MUST agree with the authoritative Class-property record associated with the identity's Engine + Local coordinate. Disagreement is S64-E007 CLASS_MISMATCH and is a hard stop.

The value 0000 is invalid and MUST NOT appear in an allocated v1.42 identifier (S64-E004 CLASS_ZERO). Values 1001–1111 are reserved and MUST NOT appear in an allocated v1.42 identifier (S64-E005 CLASS_RESERVED).

The field meaning is profile-specific. Implementations MUST identify the profile from Version and Revision before interpreting profile-dependent fields.

The v1.42 encoded-Class rule MUST NOT be applied to v1.41 or to legacy v1.4. Under v1.41, bits 50–53 are a zero-valued Class marker and the effective Class is resolved through the authoritative record. Under v1.4, bits 50–57 retain their legacy Region-field interpretation.

### 2.3 Structural continuity with v1.41

The physical position of the field at bits 50–53 is structurally continuous with v1.41. The semantic content differs: in v1.41 the field is a zero marker, and in v1.42 it carries the encoded taxonomy value. Implementations MUST NOT infer the applicable interpretation from the field's contents alone; Version and Revision MUST be checked first.

## 3. Identity Core

The 54-bit Identity Core is structurally composed of the four-bit Class field, the 21-bit Engine field, and the 29-bit Local field.

```text
Class + Engine + Local
4 + 21 + 29
= 54 bits
```

In v1.42, the Class field carries the encoded taxonomy value. This is a semantic difference from v1.41, where the corresponding field is a zero marker. The structural continuity is preserved: the Identity Core is the same 54-bit composition across v1.41 and v1.42, and the semantic difference is stated explicitly rather than implied.

The Identity Core defines the persistent identifier representation for the allocated identity. Once an identity is allocated, its Identity Core MUST NOT be changed.

The authoritative Class-property record MUST be associated unambiguously with the allocated identity. Its Class value MUST agree with the encoded Class and MUST remain stable for the lifetime of that identity.

The upper 10 bits form the representation and control area. These fields do not all have identical mutability semantics. Role is an immutable semantic attribute of the allocated identity even though it is located within this area. Immutability of Role is a property of the allocated identifier; it is not a claim that the entity cannot have a different designation under a different identifier (see Section 4).

The governing distinction is:

The 54-bit Identity Core defines the persistent identity representation. In v1.42, the Class field carries the encoded taxonomy value, and the encoded value MUST agree with the authoritative Class-property record. The upper 10 bits define the representation and control area, with Role remaining an immutable identity attribute for the allocated identifier.

## 4. Role

Bit 58 is the Role field.

| Value | Meaning |
|---|---|
| 0 | Dependent |
| 1 | Self-representing |

Role indicates whether the identified entity is designated as a self-representing identity or as an associated or dependent identity within the applicable identification relationship.

SMART does not define the legal, organizational, technical, or governance criteria used to determine this designation. The profile encodes the designation; it does not define the criteria by which a designation is made, and a conformance claim under this profile is not an assertion that a particular designation is correct for a particular entity.

Role MUST NOT be interpreted as a statement of:

- legal capacity;
- legal agency;
- ownership;
- authority;
- autonomy;
- human status; or
- organizational status.

Every valid representation of a given allocated identity MUST carry the same Role value. A representation containing a conflicting Role value is non-conforming.

Role is consumed by the application domain layer for designation logic. It is not read by the routing or allocation layers.

### 4.1 Role immutability and change of designation

Role is immutable for the allocated identifier. Once allocated, the Role value carried by that identifier MUST NOT be changed.

A change in the designation associated with an entity is expressed by retirement and reallocation, not by rewriting the existing identifier:

- A new identifier MUST be allocated through the authoritative allocation mechanism of the receiving Engine (see Section 10.5). The new identifier is created in an inactive State and is not resolvable by ordinary lookups.
- The new identifier's authoritative Class-property record MUST be created.
- The new identifier's history chain MUST be linked to the source identifier (see Section 10.6).
- The successor's canonical record MUST remain inactive and non-resolvable until the source's canonical record is ready to transition. Successor activation and source retirement MUST commit atomically from the perspective of ordinary lookups, or through an equivalent protocol guaranteeing the same externally observable result. At most one identifier in the history chain may be resolvable at any time. Any power cut or hardware failure invokes `FAIL_HARD`; no last-ID lookup or automatic resume is permitted (Section 7).
- The retired identifier's Engine + Local coordinate is permanently consumed (Section 10.2).
- Both records are retained (Sections 10.3 and 10.4).

The Class value MUST remain unchanged across the retirement-and-reallocation. The new identifier MUST carry the same Class as the retired identifier. A reallocation that would place the new identifier in an Engine of a different Class is S64-E015 ENGINE_CLASS_BINDING_VIOLATION.

The relationship between the retired identifier and the new identifier is recorded in the new identifier's history chain (Section 10.6) and is not encoded in the 64-bit identifier. The profile does not encode the relationship, and it MUST NOT be inferred from numerical proximity, Engine contiguity, or Local adjacency.

Because Engine determines Class (see Section 6), the new identifier MUST be allocated in an Engine of the same Class as the retired identifier. Subject to that constraint, the new identifier MAY be allocated in the same Engine as the retired identifier if that Engine has capacity and remains authoritative; otherwise, it MUST be allocated in another Engine of the same Class.

Role is not a routing attribute. Routing uses Class + Engine (see Section 8). Role does not participate in routing.

Examples, informative:

- Human identity: Role = 1
- Android phone: Role = 0
- SIM: Role = 0
- Coffee-maker IoT device: Role = 0

These examples illustrate possible designations; they do not establish a universal legal or organizational classification rule.

## 5. Class

### 5.1 Encoded Class

Bits 50–53 form the Class field in v1.42.

A conforming v1.42 identifier MUST contain an encoded Class value in the assigned range 0001–1000. The value 0000 is invalid. The values 1001–1111 are reserved.

The encoded Class is the primary source of Class at validation. A conforming implementation MUST verify that the encoded Class agrees with the authoritative Class-property record associated with the identity's Engine + Local coordinate. Disagreement is S64-E007 CLASS_MISMATCH and is a hard stop.

### 5.2 Class values

| Binary value | Class |
|---|---|
| 0000 | Invalid / Unassigned — MUST NOT appear in an allocated v1.42 identifier |
| 0001 | Human |
| 0010 | Other Living Being |
| 0011 | IoT / Device |
| 0100 | AI |
| 0101 | Organization |
| 0110 | Artifact / Object |
| 0111 | Android / Humanoid Artificial Entity |
| 1000 | Natural / Celestial Object |
| 1001–1111 | Reserved for future assignment |

The Class values in this table are encoded taxonomy identifiers. This specification assigns the binary values and their labels. It does not define an ontology, does not establish criteria for Class membership, and does not confer authority on any party to determine an entity's Class. The assignment of a Class to an allocated identity is an external governance act. The profile requires only that the encoded Class agree with the authoritative Class-property record.

The value 0000 MUST NOT be assigned as a Class. Encoded Class values 1001–1111 are reserved unless a later specification explicitly assigns them.

### 5.3 Authoritative Class-property record

For v1.42, a conforming implementation MUST maintain an authoritative Class-property record for every allocated identity.

The allocation registry MUST contain exactly one canonical allocation record for each Engine + Local coordinate ever allocated, regardless of lifecycle State. Two or more canonical allocation records for the same Engine + Local coordinate constitute S64-E009 ALLOCATION_CONFLICT whether their record States are identical or different. Retirement MUST update the existing canonical record; it MUST NOT create a second canonical record for the same coordinate. Append-only audit events MAY be stored separately, but MUST NOT be treated as canonical allocation records. History-chain links connect records for different coordinates; they do not permit duplicate canonical allocation records for one coordinate. Duplicates MUST be rejected before any record is selected for Class comparison or routing.

The record is mandatory for query, indexing, auditing, interoperability, administrative verification, and taxonomy binding. The encoded Class is the primary source at validation; the authoritative record is the verification source.

The record MAY be stored in the identity's primary record, in a separate table, or in an equivalent authoritative data store. The storage arrangement is implementation-defined, but the association and Class value MUST satisfy this specification's validity and stability requirements.

A cached or replicated copy MAY be used operationally, provided that it does not introduce a conflicting Class value or undermine the authoritative association.

### 5.4 Class stability and Engine binding

The Class value MUST remain stable after allocation.

Reclassification of an existing Engine is not permitted. Each Engine is bound to exactly one Class (see Section 6.3). A Class change requires a new Engine.

The Class value MUST remain unchanged across any retirement-and-reallocation cycle, including a Role change (see Section 4.1). An operation that would reallocate an identifier into an Engine of a different Class is S64-E015 ENGINE_CLASS_BINDING_VIOLATION.

The Class value of a retired identifier is preserved in the retired record.

### 5.5 Artificial spacecraft

Artificial or manufactured spacecraft, including Earth-orbiting artificial satellites and other spacecraft, use the encoded Class 0011 = IoT / Device.

### 5.6 Natural celestial entities

Naturally occurring celestial entities, including natural satellites, planets, stars, comets, asteroids, and meteoroids, use the encoded Class 1000 = Natural / Celestial Object.

## 6. Engine, Local, and Engine–Class Binding

The Engine field occupies bits 29–49 and is 21 bits wide.

The Local field occupies bits 0–28 and is 29 bits wide.

The allocation namespace is:

```text
Engine + Local
```

Class does not partition the allocation namespace. Uniqueness coordinate is Engine + Local.

Two records with different encoded Class values but identical Engine and Local values MUST NOT be treated as independently allocated SMART identities. They refer to the same allocation coordinate.

The combined Engine + Local namespace contains:

```text
2^50 = 1,125,899,906,842,624
```

possible coordinates.

### 6.1 Engine range

Engine is an unsigned 21-bit value:

```text
0 .. 2^21 - 1
0 .. 2,097,151
```

### 6.2 Local range

Local is an unsigned 29-bit value:

```text
0 .. 2^29 - 1
0 .. 536,870,911
```

Local value 0 is valid and MUST NOT be treated as a sentinel, null, or unassigned value.

### 6.3 Engine–Class binding

Each Engine is bound to exactly one Class. Multiple Engines MAY be bound to the same Class, but an Engine MUST NOT be bound to more than one Class.

Class is determined by Engine and is fixed at allocation time. Class + Engine is therefore not a free pair; given the Engine, the Class is determined.

Reclassification of an existing Engine is not permitted. A Class change requires a new Engine.

A System Admin MUST verify the virtual engine's Class property before shifting any physical engine. A shift that would move an Engine to a different Class is S64-E015 ENGINE_CLASS_BINDING_VIOLATION.

### 6.4 Engine exhaustion and rollover

When an Engine's Local namespace is exhausted — all 2²⁹ Local IDs consumed — the controller MUST search Engine IDs numerically greater than the exhausted Engine ID, in ascending order, and select the lowest eligible Engine ID under the rules below. It MUST NOT wrap around to a lower Engine ID.

An Engine ID is eligible only if it is in range, is not bound to a different Class, and either:

- it is already bound to the same Class and has at least one safely allocatable Local ID remaining; or
- it is unbound and can be bound atomically to this Class before allocation.

An Engine bound to another Class MUST be skipped and MUST NOT be reclassified. An Engine bound to the same Class but with no remaining Local IDs MUST be skipped.

Before any identifier is issued, the controller MUST safely reserve the lowest eligible forward Engine and establish any required Class binding atomically, with exclusive allocation authority and safe uniqueness and non-reuse. Concurrent controllers MUST NOT bind the same unbound Engine to different Classes or allocate duplicate coordinates.

S64-E022 ENGINE_EXHAUSTED applies when the current Engine's Local namespace is exhausted and the lowest eligible forward Engine has been safely reserved for rollover. Merely finding a potentially eligible Engine MUST NOT trigger S64-E022 as a successful rollover outcome or authorize allocation.

If authoritative state or reservation safety cannot be established, allocation MUST fail closed without issuing an identifier. The controller MUST NOT infer eligibility. A detected power cut or hardware failure affecting allocation state or integrity MUST produce `FAIL_HARD`, which takes precedence over ordinary allocation-error selection and rollover, as specified in Section 7.

Existing identifiers in the exhausted Engine remain valid and routable. Existing identifiers are not migrated to the new Engine. Retirement and reallocation remain the only path by which an identity may acquire a coordinate in a new Engine.

Because a retired coordinate is permanently consumed (Section 10), and because a Role change consumes one coordinate in the same Class (Section 4.1), Local exhaustion within an Engine advances by one coordinate per Role change. This is a known and accepted consequence of the coordinate-permanence rule. The rollover mechanism handles exhaustion by selecting the lowest eligible forward Engine ID under this section; the Class binding remains fixed across rollover.

### 6.5 Terminal Engine-ID exhaustion

If an authoritative search establishes that no eligible Engine ID numerically greater than the exhausted Engine ID remains, allocation MUST fail with S64-E029 ENGINE_ID_SPACE_EXHAUSTED.

This condition can occur before Engine ID 2²¹ − 1 if every remaining higher Engine ID is bound to another Class, exhausted for this Class, or otherwise ineligible under Section 6.4. No wraparound to lower Engine IDs is permitted.

If the search cannot be completed because authoritative state or reservation safety is unavailable, the result is not E029. The implementation MUST fail without issuing an identifier and report the applicable ordinary availability, authority, or safety error. A power cut or hardware failure invokes `FAIL_HARD`.

This condition is distinct from Local exhaustion (S64-E022 ENGINE_EXHAUSTED, which triggers rollover) and is reported as S64-E029 ENGINE_ID_SPACE_EXHAUSTED.

Expansion of the Engine ID space requires a new profile with a wider Engine field, or a new Class assignment under a separately defined profile. Existing identifiers are not renumbered.

## 7. Allocation and Non-Reuse

Each Engine MUST have an authoritative allocation mechanism for Local IDs.

**Power-cut and hardware-failure policy (`FAIL_HARD`).** Any detected power cut or hardware failure affecting the allocator, its authoritative state, or the integrity of allocation MUST produce the operational outcome `FAIL_HARD`.

The affected allocator MUST stop issuing identifiers and MUST NOT:

- perform a last-ID lookup;
- infer the last issued Local or Engine ID;
- resume from a guessed position;
- roll back to a potentially reused coordinate;
- use rollover as a fallback;
- automatically retry the interrupted allocation; or
- automatically resume an interrupted allocation or migration.

The allocator MUST remain unavailable until authoritative state and allocation safety are established through an explicitly authorized procedure outside this failure path. If that cannot be established, allocation remains disabled. This procedure MUST NOT use a last-ID lookup as a substitute for establishing authoritative state.

`FAIL_HARD` is an operational outcome, not a new S64 error code. When an interface requires an S64 code and no more specific ordinary condition applies, S64-E021 ALLOCATION_SAFETY_UNESTABLISHED MAY be reported as the interface-level result. Reporting an S64 code MUST NOT replace or weaken `FAIL_HARD`.

This rule takes precedence over ordinary allocation-error selection, validation errors, migration retries, and rollover.

For every Engine, a Local ID that has once been successfully allocated MUST NEVER be successfully allocated again within that Engine, whether the allocated identifier remains active or has been retired.

This prohibition applies across:

- process restart;
- system restart;
- database restart;
- crash recovery;
- database restore;
- allocator replacement;
- failover;
- ownership transfer;
- network partition;
- delayed recovery; and
- equivalent failure conditions.

No two successful allocations for the same Engine may return the same Local ID.

Local IDs are persistent and MUST NOT be reused.

Local allocation MAY be monotonic.

Batch allocation MAY be used.

If an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail.

A stale allocator MUST NOT be capable of successfully committing a new allocation after its authority has ended.

At most one authoritative active allocator may successfully allocate within a given Engine namespace at a time.

Ownership transfer between allocators MUST prevent the former allocator from successfully allocating after authority has transferred.

SMART does not prescribe the implementation mechanism used to provide these guarantees. The profile requires that allocation preserve the stated properties; it does not prescribe the mechanism by which it does so.

## 8. Routing Semantics

Routing in v1.42 uses Class + Engine.

A virtual-engine ID is the 25-bit concatenation of the 4-bit Class and the 21-bit Engine:

```text
virtual-engine ID = Class (4) + Engine (21)
```

The virtual-engine ID is not a hash and is not a surrogate. Each virtual-engine ID is a row in a virtual-engine table, mapping to a physical engine address (IP or MAC).

A typical resolution path is:

```text
SMART ID
|
v
Identify profile from Version + Revision
|
v
Extract Class + Engine
|
v
Look up virtual engine
|
v
Resolve physical engine address
|
v
Extract Local
|
v
Look up Local ID
|
v
Resolve identity and authoritative Class-property record
```

A Class mismatch between the encoded Class and the authoritative Class-property record MUST be detected before physical engine resolution. S64-E007 CLASS_MISMATCH is a hard stop. It is not deferred to the physical-engine stage.

A virtual-engine ID not present in the virtual-engine table is S64-E013 VIRTUAL_ENGINE_NOT_FOUND. A physical engine address that is unreachable is S64-E014 PHYSICAL_ENGINE_UNREACHABLE.

Routing in v1.42 differs from routing in v1.41. In v1.41, routing uses Engine alone; the Class marker is zero and does not participate in the routing key. In v1.42, routing uses Class + Engine because the Class is encoded and because the Engine–Class binding means that the pair is the appropriate routing key. Implementations MUST NOT apply the v1.41 Engine-alone routing rule to a v1.42 identifier.

Physical placement is operational and may be rearranged by a System Admin for load balancing. The Class value is mandatory and unchanged across rearrangements; the Class binding is fixed (see Section 6.3).

Local alone is not globally unique. Cross-Engine references MUST include sufficient information to identify Engine together with Local, or use the complete SMART identifier.

A resolver that needs the Class MUST resolve the encoded Class and verify it against the authoritative Class-property record. It MUST NOT infer the Class from a cached copy without verification, and it MUST NOT proceed to physical engine resolution on a Class mismatch.

## 9. Database Representation

A conforming implementation MAY use Engine-local database tables or equivalent namespaces in which Local is the primary key.

The full 64-bit SMART identifier MAY be stored as a public or current representation.

The full 64-bit identifier does not have to be the relational database primary key.

Changes to the representation or control area MUST NOT require relocation or mutation of the persistent identity record when the Identity Core remains unchanged.

### 9.1 Class storage

For v1.42, a conforming implementation MUST maintain an authoritative Class-property record for every allocated identity, and MUST verify that the encoded Class agrees with that record.

The record MAY be stored in the identity's primary record, in a separate table, or in an equivalent authoritative data store. The storage arrangement is implementation-defined, but the association and Class value MUST satisfy this specification's validity and stability requirements.

The encoded Class MUST NOT be used as a substitute for the authoritative record. The encoded Class is the primary source at validation; the authoritative record is the verification source.

A cached or replicated copy MAY be used operationally, provided that it does not introduce a conflicting Class value or undermine the authoritative association.

SMART does not prescribe:

- SQL or NoSQL;
- database vendor;
- replication model;
- partitioning technology;
- consensus mechanism;
- caching;
- change-data capture;
- authentication;
- authorization; or
- transport protocol.

These implementation choices MUST preserve the normative requirements of this specification. The profile requires that the implementation preserve the stated properties; it does not prescribe the mechanism by which it does so.

## 10. Retirement, Migration, and Record Retention

### 10.1 Retirement and workflow status

Retirement is a record-level transition. State (active or retired) is a property of the authoritative allocation record; it is not encoded as a bit in a v1.41 or v1.42 identifier. Legacy v1.4 encoded an active/retired State bit; that encoded bit is a v1.4 construct and MUST NOT be reinterpreted as v1.41 or v1.42 identity state.

An identifier is retired by transitioning its allocation record from active to retired. Retirement is not expressed by modifying the 64-bit identifier.

State (active / retired) is normative and record-level. Workflow status (for example, "on hold" during a transition) is operational and allocator-level. The profile requires the resolvability invariant stated in Section 10.6: at most one identifier in a history chain is resolvable by ordinary lookups at any time. The workflow mechanism by which the allocator enforces this is implementation-specific and is not prescribed by this specification.

Activation is a separate transition from allocation. An identifier is allocated when its coordinate is consumed and its record created. It becomes active only when its State is set to active. An allocated identifier whose State is not yet active is searchable by administrative tooling but is not resolvable by ordinary lookups.

### 10.2 Permanent consumption of the coordinate

A retired identifier's Engine + Local coordinate MUST NOT be reissued under any profile of the SMART 64-Bit ID family. The coordinate remains permanently consumed. There is no release point.

A retired identifier MUST NOT be reused, reactivated, reallocated, or treated as a free coordinate.

The prohibition on reissue is independent of the profile under which a later allocation would occur. A coordinate consumed by a v1.42 identifier remains consumed for the purposes of any profile that allocates within the SMART 64-Bit ID family's coordinate space.

This rule is consistent with the direction taken by GS1 (permanent GTIN non-reuse after 2018) and NIST SP 800-53 IA-4 (prevent reuse of identifiers). See BIBLIOGRAPHY.md.

### 10.3 Retention

A retired identifier's record MUST be retained indefinitely, for as long as the SMART 64-Bit ID family profile under which the identifier was allocated remains in force.

The profile requires that the retired record be retained. It does not prescribe the mechanism of retention.

The retained record MUST preserve the identifier's Identity Core, its encoded Class, its Role, its allocation coordinate, its retirement status, and its history chain link (Section 10.6).

In addition to the full retired record, a coordinate-consumption tombstone MUST be retained permanently for every consumed Engine + Local coordinate. The tombstone is the minimal durable record—coordinate, Class, allocating profile, retirement status—and is the fallback by which the reissue prohibition in Section 10.2 is enforced when the full retired record is no longer retained. The tombstone's retention is not conditional on the allocating profile remaining in force.

### 10.4 Per-profile retention

A v1.42 retired identifier's record MUST be retained under v1.42.

Retention obligations for identifiers allocated under other profiles arise from the profile under which those identifiers were allocated, or from applicable law or governance, and not from v1.42. A v1.42-conforming implementation that encounters a retired identifier from another profile MUST NOT infer retention obligations from v1.42, and MUST NOT claim v1.42 conformance as the basis for any treatment of that record.

The silence of v1.42 on the treatment of another profile's records is not permission to discard them.

### 10.5 Migration and designation change

Migration means retirement of an old identifier and allocation of a new identifier. The old identifier is never migrated, reused, or rewritten.

Allocation precedes retirement. The sequence is:

1. The receiving Engine allocates a new Local ID through its authoritative allocation mechanism. The coordinate is consumed; the record is created in an inactive State. The new identifier is not yet resolvable by ordinary lookups.
2. The receiving Engine creates the new identifier's authoritative Class-property record.
3. The new identifier's history chain is linked to the source identifier (Section 10.6).
4. The source identifier's canonical record is transitioned to retired and the successor's canonical record is transitioned to active in one atomic transition, or by an equivalent protocol that guarantees the same externally observable result. The successor MUST remain non-resolvable until that transition commits. At no point may both identifiers be resolvable, and a transition MUST NOT leave neither resolvable after a successful ordinary operation. A separate workflow/on-hold state MAY be used before commit. The implementation mechanism is implementation-specific; the atomic externally observable invariant is normative.
5. The retired identifier's coordinate is permanently consumed (Section 10.2).
6. Both records are retained (Sections 10.3 and 10.4).

**Failure handling:** If step 1 fails without a power cut or hardware failure, nothing is retired and the source identifier remains active. If steps 2 or 3 fail, the operation aborts; the source identifier remains active; the allocated but uncommitted coordinate is treated as consumed and is not released. If the atomic transition fails without a power cut or hardware failure, the source remains resolvable and the successor remains non-resolvable. The operation MAY be retried only while authoritative state and allocator authority are positively established.

Any power cut or hardware failure at any point invokes `FAIL_HARD`: stop allocation, do not perform a last-ID lookup, do not automatically resume or retry the interrupted sequence, and do not issue any identifier until authoritative state and allocation safety have been established through the explicitly authorized procedure described in Section 7. The sequence is complete only when the atomic transition succeeds.

The receiving Engine MUST allocate the new Local ID through its authoritative allocation mechanism. The receiving Engine MUST NOT:

- preserve the source Local ID merely for convenience;
- copy the source Local ID;
- request the source Local ID as the new allocation; or
- manually assign a Local ID outside the authoritative allocation mechanism.

The new Local ID MUST satisfy all applicable allocation, uniqueness, non-reuse, and allocator-authority requirements.

Migration MUST NOT bypass normal allocation safety. If the receiving Engine cannot safely allocate a new Local ID, the migration MUST NOT create the new identifier. The source identifier remains unchanged and active.

Because Engine determines Class, the receiving Engine MUST be an Engine of the same Class as the source identifier, unless the migration is explicitly a Class change, which is not a migration under this section and requires a new Engine (Section 6.3).

An implementation MAY maintain additional external lifecycle data. The history chain in Section 10.6 is the normative record.

### 10.6 Identifier history chain

Each allocated identifier record MUST record the identifier it replaced, if any, or an explicit marker that it is a first allocation. This record is the identifier's history chain.

The history chain MUST be retained for as long as any identifier in the chain is retained.

At most one identifier in a history chain is resolvable by ordinary lookups at any time. "Resolvable" is the operational property. Successor activation and source retirement MUST be atomic from the perspective of ordinary lookups, or use an equivalent protocol that guarantees the same property.

A pending successor MUST remain non-resolvable while the source remains active. A power cut or hardware failure MUST invoke `FAIL_HARD`; it MUST NOT trigger a last-ID lookup or automatic restart of the pending transition. The implementation MUST NOT expose both identifiers as resolvable, and MUST NOT declare the transition complete unless the atomic transition has committed.

The history chain is the authoritative record of which coordinates the entity has consumed. The coordinate-consumption tombstone (Section 10.3) is the permanent fallback for chains whose full records are no longer retained.

## 11. Engine Retirement

SMART does not require an Engine to remain available indefinitely.

An identifier whose Engine becomes unavailable, retired, transferred, or otherwise inaccessible remains an identifier, and its record remains subject to the retention requirements of Section 10.3.

Resolution behavior for unavailable Engines is not defined by the identifier format.

SMART does not encode or infer a successor Engine.

An association between an old identity and a new identity cannot be inferred solely from the numerical relationship between their identifiers.

Engine retirement is distinct from identifier retirement. An Engine may be retired while identifiers allocated within it remain active records, subject to the retention and resolution requirements that apply to those identifiers. Conversely, an identifier may be retired while its Engine remains active.

## 12. Version and Revision

Bit 63 is Version.

Bits 59–62 are Revision.

Together they select the applicable SMART profile.

For Version 0:

| Version | Revision | Profile |
|---|---|---|
| 0 | 0000 | SMART v1.4 |
| 0 | 0001 | SMART v1.41 |
| 0 | 0010 | SMART v1.42 |
| 0 | Other assigned value | Future v1.x |

Version 1 identifies the v2+ family.

A v1.x implementation encountering Version 1 MUST NOT interpret the identifier as a v1.x identifier. It MUST reject or delegate the identifier according to the implementation boundary.

An implementation encountering an unsupported Revision MUST NOT guess its meaning. It MUST reject or delegate the identifier according to the implementation boundary.

Revision is a profile selector. It is not a literal textual representation of the release number.

The Version 0 family has 16 possible Revision values. If the available Revision values are exhausted, incompatible future evolution requires a new Version family.

A failed validation under one profile MUST NOT be treated as proof that the identifier belongs to another profile. The profile MUST be identified from Version and Revision before profile-dependent fields are interpreted.

## 13. Profile Coexistence: v1.4, v1.41, and v1.42

SMART v1.4, SMART v1.41, and SMART v1.42 are distinct profiles. They coexist. None supersedes, obsoletes, or replaces another.

A v1.42 identifier is not a v1.41 identifier, and a v1.41 identifier is not a v1.42 identifier. A v1.4 identifier is neither.

### 13.1 Mutual invalidity

Mutual invalidity is intentional and is stated explicitly.

Under normal validation, a cross-profile identifier is rejected at profile identification because its Version/Revision does not select the target profile. This is the decisive rejection.

Independently, if the identifier's fields are force-interpreted under the other profile's field rules, the Class field also violates that profile's field requirements:

- A v1.42 identifier force-read under v1.41 field rules has nonzero Class-marker bits and would be invalid v1.41 on that ground.
- A v1.41 identifier force-read under v1.42 field rules has encoded Class 0000 and would be invalid v1.42 on that ground.

The field-level explanation is informative. Profile selection is normative. Forced field interpretation MUST NOT replace profile selection.

No automatic migration between profiles is implied or permitted. Any conversion is an explicit operation that preserves identity relationships and follows the applicable specification and allocation rules.

### 13.2 Profile identification

An implementation MUST identify the profile from Version and Revision before interpreting profile-dependent fields.

A failed validation under one profile MUST NOT be treated as proof that the identifier belongs to another profile.

Implementations MUST NOT infer the applicable interpretation solely from the bits at positions 50–53, 54–57, or 58. Version and Revision MUST be checked first.

### 13.3 Profile-specific field handling

The v1.42 rule that bits 50–53 carry the encoded taxonomy value applies only after an identifier has been identified as v1.42.

In v1.41, bits 50–53 are a Class marker and MUST be 0000; the effective Class is resolved through the authoritative Class-property record.

In v1.4, bits 50–57 retain their legacy Region-field interpretation. Implementations MUST NOT reinterpret the v1.4 Region field as an encoded Class, as a v1.41 Class marker, or as the v1.41 Reserved field.

The v1.41 zero-marker rule does not carry forward to v1.42. The v1.42 encoded-Class rule does not carry backward to v1.41 or v1.4. Future profiles MUST be validated according to their own specifications.

### 13.4 Legacy-only boundary

At a boundary configured to accept only legacy v1.4 identifiers, a v1.41 or v1.42 identifier MUST NOT be accepted, silently discarded, stripped, mutated, downgraded, or passed downstream as though it were a valid v1.4 identifier.

The boundary MUST explicitly reject the incompatible identifier or operation and report the incompatibility to the calling or upstream system.

A boundary implementation MUST NOT convert a v1.41 or v1.42 identifier into a v1.4 identifier by rewriting, truncating, masking, or otherwise modifying its bits.

SMART does not prescribe transport protocol, error code, logging behavior, or retry behavior. The required property is deterministic rejection rather than silent reinterpretation.

An implementation that stores identifiers from more than one profile MUST retain the decoder for each profile it stores. Deprecating a decoder is only safe when no stored identifier uses that profile.

## 14. Reserved Bits

Bits 54–57 are Reserved in v1.42.

At generation, all four Reserved bits MUST be:

```text
0000
```

A v1.42 identifier containing any nonzero Reserved bit is non-conforming.

A v1.42 implementation MUST NOT accept such an identifier as a valid v1.42 identifier (S64-E003 RESERVED_BITS_NONZERO).

Reserved bits MUST NOT be used for:

- private application data;
- hidden flags;
- implementation-specific state; or
- undocumented extensions.

Future specifications MAY assign currently reserved values under their own profile definitions. Such future assignments do not change the requirements for v1.42 identifiers.

The Class field at bits 50–53 and the Reserved field at bits 54–57 are separate fields and MUST be validated independently.

### 14.1 Deferred expansion

A 5-bit Class expansion—reallocating bit 54 from Reserved to Class, so that Class occupies bits 50–54 and Reserved occupies bits 55–57—is a future option. It is explicitly not part of v1.42.

In v1.42, bit 54 remains Reserved and MUST be zero. Implementations MUST NOT interpret bit 54 as part of the Class field in a v1.42 identifier.

## 15. Binary Serialization

A SMART v1.42 identifier is an unsigned 64-bit integer.

The canonical binary wire representation MUST use:

```text
unsigned 64-bit
big-endian
network byte order
```

Bit 0 is the least-significant bit. Bit 63 is the most-significant bit.

Textual representations MAY be defined by applications or future specifications, provided that they preserve the same underlying unsigned 64-bit value.

An implementation MUST NOT use signed integer interpretation in a way that changes the identifier's numerical value or causes incorrect field extraction.

Implementations using signed host-language types MUST provide equivalent unsigned 64-bit semantics.

Serialization and deserialization MUST preserve all 64 bits exactly. An implementation MUST NOT rewrite the Class field, Reserved field, Role, Version, or Revision merely to make an identifier acceptable to another profile.

## 16. Field Extraction and Validation

For an unsigned 64-bit identifier ID, the v1.42 fields are extracted as follows:

```text
Local = ID & 0x1FFFFFFF
Engine = (ID >> 29) & 0x1FFFFF
Class = (ID >> 50) & 0x0F
Reserved = (ID >> 54) & 0x0F
Role = (ID >> 58) & 0x01
Revision = (ID >> 59) & 0x0F
Version = (ID >> 63) & 0x01
```

Logical right-shift semantics MUST be used.

The extraction operations MUST correspond exactly to the bit positions defined in Section 2.

### 16.1 Identifier validation order

An implementation MUST identify Version and Revision before applying profile-specific validation.

For a v1.42 identifier, the identifier-validation precedence is:

1. **Input format.** Input MUST be exactly 16 hexadecimal characters (0–9, a–f, A–F). Prefixes, whitespace, separators, and other formatting are not permitted. Within this stage, formatting is validated before length. A disallowed character, prefix, whitespace, or separator is S64-E011 MALFORMED_INPUT. A correctly formatted input of incorrect length is S64-E001 INVALID_LENGTH. These rules define the validation-interface input representation; they do not change the binary identifier layout.

2. **Profile identification.** Version MUST equal 0; Revision MUST equal 0010. An unsupported Version/Revision is S64-E002 UNSUPPORTED_PROFILE.

3. **Field validity.** Reserved MUST equal 0000 (S64-E003 RESERVED_BITS_NONZERO). Class MUST not be 0000 (S64-E004 CLASS_ZERO). Class MUST not be in 1001–1111 (S64-E005 CLASS_RESERVED). Role is validated as a single bit; both values are valid in v1.42. S64-E010 ROLE_INVALID is not a field-validation error; it applies to an operation that attempts to change Role in place, or that would express a Role change without retirement and reallocation (see Section 4.1).

4. **Authoritative checks.** Required authoritative queries MUST complete successfully before a missing-record, duplicate-record, or Class-comparison result is reported. If any required query cannot complete, report S64-E012 VALIDATION_UNAVAILABLE during ordinary operation; do not infer that a record is missing or mismatched from an unavailable query. If all required queries complete, the Engine + Local coordinate MUST be present in the allocation registry (S64-E008 ALLOCATION_NOT_FOUND). More than one canonical allocation record for the coordinate MUST be reported as S64-E009 ALLOCATION_CONFLICT, regardless of whether the records have identical or different lifecycle States. Duplicates MUST be rejected before any record is selected for Class comparison or routing, and Class agreement MUST NOT be used to choose between conflicting records. The authoritative Class-property record MUST exist (S64-E006 CLASS_RECORD_MISSING). The encoded Class MUST agree with the authoritative record (S64-E007 CLASS_MISMATCH, hard stop). A detected power cut or hardware failure invokes `FAIL_HARD` under Section 7, overriding ordinary validation and allocation error selection.

5. **Routing resolution.** Class + Engine MUST resolve to a virtual-engine row (S64-E013 VIRTUAL_ENGINE_NOT_FOUND). The physical engine address MUST be reachable (S64-E014 PHYSICAL_ENGINE_UNREACHABLE).

The identifier-validation precedence above is the normative order. An implementation MUST NOT proceed past a failure at an earlier stage, and MUST NOT report a later-stage condition as though the earlier stages had succeeded.

### 16.2 Administrative operation validation

Administrative operations—shifting a physical engine, reallocating an identifier, or migrating an identifier—are validated by a procedure distinct from identifier validation. The procedure is:

- Evaluate the proposed operation against the Engine-to-Class binding and the applicable allocation-safety requirements.
- If the operation would associate an identifier with an Engine of a different Class, reject with S64-E015 ENGINE_CLASS_BINDING_VIOLATION.
- For rollover, apply the lowest-eligible-forward-Engine policy in Section 6.4 and reserve the target before issuing an identifier.
- If authoritative state or safe uniqueness cannot be established, fail without issuing an identifier. A power cut or hardware failure invokes `FAIL_HARD`; no last-ID lookup or automatic resume is permitted.
- Otherwise, commit the operation.

Administrative validation is not a stage of identifier validation. An ordinary read of an identifier does not execute administrative validation.

### 16.3 Error-code registry reference

`errors/ERROR-CODES.md` is the authoritative registry for v1.42 error identifiers.

While v1.42 is an unpublished release candidate, its specification and error-code registry MAY be corrected and finalized before release, including changing a proposed code definition or removing a proposed code that is not part of a previously published v1.42 profile. Such pre-release edits do not, by themselves, require a new Revision.

After a profile has been published, removing an established error code or redefining its normative meaning MUST be handled through the profile's versioning and compatibility rules. Where this specification requires a new Revision for that change, the published profile MUST NOT be silently redefined.

The codes listed in this specification are those cited normatively by the profile. The registry MAY contain additional codes for diagnostic conditions not normatively cited by the profile. The registry MUST NOT define a separate code for a condition already covered by a corrected normative code unless the specification explicitly requires that distinction.

## 17. Representation and Identity Stability

For a given allocated v1.42 identity:

- the Identity Core MUST remain stable;
- the encoded Class MUST remain stable;
- the authoritative Class-property record and its association with the identity MUST remain stable;
- Role MUST remain stable for the allocated identifier; and
- Engine and Local together identify the allocation coordinate.

Changes to the representation or control area MUST NOT silently create a different interpretation of the Identity Core.

If an operation changes Engine, it creates a new SMART identity rather than mutating the existing identity.

If an operation changes Class or Role, the existing identity MUST NOT simply be rewritten to represent the new semantic designation. Class change requires a new Engine and is not a reallocation. Role change is retirement and reallocation (Section 4.1).

An implementation MUST NOT change the Class property of an existing allocated identity without following the applicable lifecycle or identity-replacement process.

External lifecycle or history mechanisms MAY record relationships between identities. The history chain (Section 10.6) is the normative record of the relationship.

A retired identifier's record MUST remain stable and retained under Section 10.3. Its encoded Class and Role are preserved in the historical record and MUST NOT be changed.

## 18. Conformance

A conforming SMART v1.42 implementation MUST:

- implement the specified bit positions;
- preserve the 54-bit Identity Core for an allocated identity;
- generate encoded Class values in the assigned range 0001–1000;
- reject encoded Class 0000 and encoded Class values in 1001–1111;
- preserve the Class value and its association with the allocated identity;
- maintain an authoritative Class-property record for every allocated identity;
- verify that the encoded Class agrees with the authoritative Class-property record, and treat disagreement as a hard stop;
- enforce the binding of each Engine to exactly one Class, while permitting multiple Engines to share a Class;
- preserve Role for an allocated identifier, and reject any attempt to change Role in place or to express a Role change without retirement and reallocation (S64-E010 ROLE_INVALID);
- express a Role change by retirement and reallocation, not by rewriting the identifier;
- preserve the Class value unchanged across retirement and reallocation;
- permanently consume the retired Engine + Local coordinate and not reissue it;
- retain the retired record under Section 10.3, and retain a permanent coordinate-consumption tombstone under Section 10.3;
- maintain the identifier history chain under Section 10.6, and enforce the resolvability invariant: at most one identifier in a chain is resolvable at any time;
- enforce Engine + Local uniqueness;
- guarantee Local non-reuse within an Engine, including across retirement;
- generate Reserved bits 54–57 as zero;
- reject v1.42 identifiers with nonzero Reserved bits;
- treat Local 0 as a valid Local ID;
- correctly interpret Version and Revision;
- never guess the meaning of an unsupported profile;
- support canonical unsigned 64-bit big-endian binary interoperability;
- distinguish v1.4, v1.41, and v1.42 from one another by Version and Revision before interpreting profile-dependent fields;
- explicitly reject incompatible identifiers at a legacy-only boundary;
- require receiving Engines to use authoritative allocation during migration;
- route on Class + Engine in v1.42, not on Engine alone;
- detect Class mismatch before physical engine resolution;
- reject an administrative shift that would move an Engine to a different Class;
- apply the identifier-validation precedence of Section 16.1 and the administrative-validation procedure of Section 16.2 as distinct procedures; and
- preserve the defined routing semantics.

An implementation that cannot satisfy an applicable safety, uniqueness, non-reuse, validation, Class-property, retention, history-chain, or interoperability requirement MUST NOT claim conformance to SMART v1.42.

## 19. Non-Conforming Conditions

The following conditions are non-conforming for v1.42:

- encoded Class 0000 in an allocated identifier;
- encoded Class in 1001–1111;
- a missing, ambiguous, invalid, or incorrectly associated authoritative Class-property record;
- disagreement between the encoded Class and the authoritative Class-property record;
- nonzero Reserved bits;
- treating bit 54 as part of the Class field;
- reuse of a previously allocated Local ID within the same Engine;
- reissue of a retired Engine + Local coordinate;
- two successful allocations returning the same Engine + Local coordinate;
- a stale allocator successfully allocating after its authority has ended;
- changing the Identity Core of an allocated identity;
- changing Role by rewriting an existing representation;
- expressing a Role change without retirement and reallocation;
- changing the Class of an existing identity without following the applicable lifecycle or identity-replacement process;
- reallocating an identifier into an Engine of a different Class;
- an administrative shift that would move an Engine to a different Class;
- manually assigning a receiving Engine's Local ID outside its authoritative allocator;
- failure to retain a retired record under Section 10.3;
- failure to retain a permanent coordinate-consumption tombstone for a consumed coordinate;
- two resolvable identifiers in the same history chain;
- a history chain in which a pending successor exists and no identifier in the chain is resolvable;
- inference of a successor identity from numerical proximity, Engine contiguity, or Local adjacency;
- routing on Engine alone in a v1.42 implementation;
- deferring a Class mismatch to physical engine resolution;
- silently interpreting an unsupported Revision;
- interpreting Version 1 as a v1.x identifier;
- treating a v1.41 or v1.42 identifier as a valid v1.4 identifier;
- treating a v1.42 identifier as a valid v1.41 identifier;
- rewriting or truncating v1.41 or v1.42 bits to make them appear to belong to another profile; or
- using non-canonical binary byte order where canonical SMART binary interoperability is required.

The encoded Class value 0000 MUST NOT be confused with a valid Class. An identifier carrying 0000 in the Class field is not a v1.42 identifier.

## 20. Implementation Boundary

SMART defines identifier semantics, not an implementation's complete operational environment.

An implementation MAY provide:

- database storage;
- distributed allocation;
- replication;
- caching;
- APIs;
- message queues;
- authentication;
- authorization;
- monitoring;
- auditing;
- migration tooling; and
- lifecycle management.

Those systems MUST preserve the normative requirements of this specification wherever they operate on SMART identifiers.

A proxy, gateway, database, service, or application that bypasses required SMART validation is non-conforming for that operation.

An implementation MAY choose how to store and retrieve authoritative Class-property records, how to structure the virtual-engine table, how to arrange physical engine placement, how to manage the workflow status of identifiers in transition, and how to retain retired records and tombstones. Those choices MUST preserve the properties defined in this specification.

## 21. Summary

SMART v1.42 provides a 64-bit identifier with the following fields:

```text
29 bits Local
21 bits Engine
4 bits Class
4 bits Reserved
1 bit Role
4 bits Revision
1 bit Version

64 bits total
```

The 54-bit Identity Core is structurally:

```text
Class + Engine + Local = 54 bits
```

In v1.42, the Class field carries the encoded taxonomy value. The encoded Class MUST agree with the authoritative Class-property record. Encoded Class 0000 is invalid; encoded Class values 1001–1111 are reserved.

Each Engine is bound to exactly one Class; multiple Engines MAY share the same Class, but an Engine MUST NOT be bound to more than one Class. Reclassification of an Engine is not permitted; a Class change requires a new Engine.

A virtual-engine ID is the 25-bit concatenation of Class and Engine. Routing uses Class + Engine → virtual engine → physical engine address. This differs from v1.41 routing, which uses Engine alone.

The allocation namespace is:

```text
Engine + Local
```

Local IDs MUST NOT be reused within an Engine. Two successful allocations MUST NOT share the same Engine + Local coordinate. A retired coordinate is permanently consumed and MUST NOT be reissued under any profile of the SMART 64-Bit ID family. There is no release point. This is consistent with GS1 and NIST SP 800-53 IA-4 practice; see BIBLIOGRAPHY.md.

Role is immutable for the allocated identifier. A change of designation is expressed by retiring the identifier and allocating a new one, with the Class value preserved unchanged. Allocation precedes retirement. The successor is created inactive and linked into the history chain; successor activation and source retirement commit atomically, preserving at most one resolvable identifier at any time. Retired records are retained indefinitely while the allocating profile remains in force; a permanent coordinate-consumption tombstone is retained independently.

v1.4, v1.41, and v1.42 coexist. None supersedes another. Mutual invalidity is intentional. Profile is identified from Version and Revision before profile-dependent fields are interpreted.

Canonical binary serialization is unsigned 64-bit big-endian network byte order.

Unknown profiles MUST NOT be guessed.

Reserved bits MUST remain zero in v1.42. Bit 54 remains Reserved; the 5-bit Class expansion is deferred and is not part of v1.42.

Engine migration creates a new identity through authoritative allocation; the old identifier is retired, never migrated.

These requirements collectively define the SMART 64-Bit ID v1.42 profile.
