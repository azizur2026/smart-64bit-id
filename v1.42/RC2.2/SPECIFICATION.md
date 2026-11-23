**Filename:** `SPECIFICATION.md`
**Created on:** 2026-11-17
**Last modified:** 2026-11-23
**SMART 64-Bit ID Version & Revision:** v1.42 — Version 0, Revision 0010
**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**License:** AGPL3
**Email:** contact@samara.com.bd

> **Profile code note.** `Version 0, Revision 0010` is fixed at first final release. RC1 and RC2.2 are drafts of the same profile; RC1 is superseded and carries no interoperability claim. After first final release, any normative change to identifier semantics, validation order, or error-code meaning requires Revision `0011`.

---

# SMART 64-Bit ID v1.42 — Specification

**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Supersedes:** RC1 of the same profile. v1.41 (`Revision 0001`) remains a coexisting active profile; pre-v1.41 legacy profiles are historic and unsupported.
**Document purpose:** Normative technical specification for SMART 64-Bit ID v1.42

## 1. Scope

SMART 64-Bit ID v1.42 defines a 64-bit identifier format for persistent identification of entities and associated or dependent identities.

This specification defines the 64-bit binary layout; the encoded Class field and its relationship to the authoritative Class-property record; Identity Core semantics and permanent uniqueness across active profiles; independent Engine allocation pools for each supported Class; Virtual Engine composition and routing; Role semantics and retirement-and-reallocation for a change of designation; Version and Revision profile selection; Reserved-bit requirements; Engine and Local allocation semantics; Engine exhaustion, rollover, and reclamation; allocator authority, fencing, and failure handling; quarantine, fitness determination, and allocation-safety requirements; the portable Virtual Engine control table architecture, including generation epochs and lineage; retirement, migration, record retention, and identifier history; compatibility boundaries with v1.41 and historic profile rejection; canonical binary serialization; and decoding, validation, allocation precedence, and implementation conformance.

The identifier is a coordinate system, and every operation in this specification is keyed on that coordinate system. A Virtual Engine is addressed by `(Class, Engine)`. An identity is addressed by `(Class, Engine, Local)`. No other key — not an Engine number alone, not a network address, not a hardware address, not a surrogate row identifier — may be used for routing, binding, allocation, or uniqueness.

This specification defines identifier semantics and the properties that allocation, routing, and lifecycle operations MUST preserve. It does not prescribe a particular database, hardware architecture, network protocol, or allocator implementation. Where this specification names database structures (such as the `virtual_engines` control table), those names are logical and MAY be mapped to any equivalent physical schema that preserves the stated properties.

The Version and Revision fields MUST be interpreted before any profile-specific field is interpreted.

### 1.1 Compatibility with RC1

This revision is backward compatible with RC1 of the same profile:

- No bit position, field width, or field meaning changes.
- No existing `S64-Exxx` code changes identifier or trigger condition.
- Identifiers allocated under RC1 remain valid and unchanged.
- Additions are `S64-E030` and `S64-E031`, §6.3.2, and the tightening of §6.4, §7.3, §10.6, §10.7.2, and §16.1 step 4.
- §16.1 step 4 no longer emits `S64-E015` for profile provenance. Implementations built against RC1 must adopt `S64-E030` for that condition.

## 2. 64-Bit Layout

A v1.42 identifier is an unsigned 64-bit value. Bits are numbered from bit 0, the least-significant bit, through bit 63, the most-significant bit.

| Bits | Width | Field | Requirement |
|---|---|---|---|
| 63 | 1 | Version | `0` for v1.42 |
| 62–59 | 4 | Revision | `0010` for v1.42 |
| 58 | 1 | Role | Self-representing / dependent designation |
| 57–54 | 4 | Reserved | MUST be `0000` |
| 53–50 | 4 | Class | Encoded taxonomy value |
| 49–29 | 21 | Engine | Engine number within a Class pool |
| 28–0 | 29 | Local | Allocation-local identifier |

### 2.1 Meaning of the Class field

For v1.42, bits 50–53 carry the encoded taxonomy value. The encoded Class is the primary source of Class at validation and MUST agree with the authoritative Class-property record associated with the complete Identity Core.

`0000` is invalid (`S64-E004`). `0001`–`1000` are assigned. `1001`–`1111` are reserved (`S64-E005`).

The v1.42 encoded-Class rule MUST NOT be applied to v1.41.

### 2.2 Structural continuity with v1.41

The physical position of the Class field is structurally continuous with v1.41. Its meaning differs. In v1.41, bits 50–53 are a zero-valued Class marker (`0000`), and Class properties are resolved solely through the authoritative database table. In v1.42, bits 50–53 contain the encoded taxonomy value in addition to being backed by the authoritative Class-property record.

Implementations MUST identify Version and Revision before interpreting this field.

## 3. Identity Core

The 54-bit Identity Core consists of Class + Engine + Local (4 + 21 + 29 = 54 bits). The complete coordinate is `(Class, Engine, Local)`.

The 54-bit Identity Core is the permanent uniqueness key for an allocated identity across all active profiles sharing the 54-bit coordinate model (v1.41 and v1.42).

No two distinct identity records may ever be assigned the same 54-bit Identity Core across v1.41 and v1.42 coexistence, regardless of Virtual Engine, allocation lifecycle, retirement status, physical infrastructure changes, or Engine reclamation. Because v1.41 fixes bits 50–53 to `0000` and v1.42 requires bits 50–53 to be in `0001`–`1000`, their 54-bit Identity Core spaces are structurally disjoint by construction, guaranteeing family-wide non-collision without coordinate translation. Version and revision isolation (`0001` for v1.41, `0010` for v1.42) ensures complete runtime separation.

Once allocated, an Identity Core MUST NOT be changed, reused, or reassigned.

Two coordinates are distinct if any component differs: `(1, 120, 500)` and `(2, 120, 500)` are distinct; so are `(1, 120, 500)` and `(1, 121, 500)`, and `(1, 120, 500)` and `(1, 120, 501)`.

The upper 10 bits are Metadata. They do not form part of the 54-bit Identity Core.

### 3.1 Metadata immutability

In v1.42, all 10 Metadata bits are immutable for an allocated identifier: Version (value `0`), Revision (value `0010`), Role, Reserved (value `0000`). No Metadata bit may be modified in place after allocation.

A change requiring a different Role MUST follow the retirement-and-reallocation procedure in §4.1. No Metadata modification creates a new Identity Core or permits reuse of an existing Identity Core.

## 4. Role

Bit 58 is the Role field: `0` dependent, `1` self-representing. Role indicates whether the identified entity is designated as a self-representing identity or as an associated or dependent identity within the applicable identification relationship.

SMART does not define the legal, organizational, technical, or governance criteria used to determine this designation. Role MUST NOT be interpreted as a statement of legal capacity, legal agency, ownership, authority, autonomy, human status, or organizational status.

Every valid representation of a given allocated identity MUST carry the same Role value. Role is consumed by the application domain layer; it is not a routing or allocation attribute.

### 4.1 Role immutability and change of designation

Role is immutable for an allocated identifier. A change in designation MUST be expressed through retirement and reallocation, not by rewriting the existing identifier. The process MUST:

1. Allocate a new identifier through the authoritative allocation mechanism of the receiving Virtual Engine.
2. Create the new identifier in an inactive, non-resolvable state.
3. Create its authoritative Class-property record.
4. Link its history chain to the source identifier.
5. Transition the source to retired and the successor to active atomically from the perspective of ordinary lookups, or through an equivalent protocol preserving the same externally observable result.

At most one identifier in a history chain may be resolvable at any time.

A power cut or hardware failure invokes FAIL_HARD. No last-ID lookup or automatic resume is permitted. The retired Identity Core remains permanently consumed. Both records MUST be retained under §10.

The Class value MUST remain unchanged across a Role-change retirement-and-reallocation; the new identifier MUST use a receiving Virtual Engine in the same Class.

A different Role MUST NOT be achieved by changing the Role bit of an existing identifier. Such an operation is `S64-E010 ROLE_INVALID`. Role does not participate in routing.

## 5. Class

### 5.1 Encoded Class

Bits 50–53 form the Class field in v1.42. A conforming identifier MUST contain an assigned Class value in the range `0001`–`1000`. The encoded Class MUST agree with the authoritative Class-property record. Disagreement is `S64-E007 CLASS_MISMATCH` and is a hard stop.

### 5.2 Class values

| Binary | Class |
|---|---|
| `0000` | Invalid / Unassigned (in v1.42; Class marker only in v1.41) |
| `0001` | Human |
| `0010` | Other Living Being |
| `0011` | IoT / Device |
| `0100` | AI |
| `0101` | Organization |
| `0110` | Artifact / Object |
| `0111` | Android / Humanoid Artificial Entity |
| `1000` | Natural / Celestial Object |
| `1001`–`1111` | Reserved for future assignment |

This specification assigns encoded taxonomy identifiers and labels. It does not define an ontology or establish criteria for Class membership; external application-domain governance policies MUST determine which Class applies to an entity at allocation.

### 5.3 Authoritative Class-property record

A conforming implementation MUST maintain an authoritative Class-property record for every allocated identity. There MUST be exactly one canonical allocation record for each 54-bit Identity Core ever allocated. Two or more canonical allocation records for the same Identity Core constitute `S64-E009 ALLOCATION_CONFLICT`, regardless of lifecycle state.

Retirement MUST update the existing canonical record. It MUST NOT create a second canonical record for the same Identity Core. Append-only audit events MAY be stored separately, but MUST NOT be treated as canonical allocation records.

The record MAY be stored in the identity's primary record, a separate table, or an equivalent authoritative data store. Cached or replicated copies MAY be used if they do not introduce a conflicting Class value or undermine the authoritative association.

#### 5.3.1 Row-level provenance

The authoritative Class-property record MUST store, as explicit, queryable fields: the Class value as a discrete column, typed to hold the 4-bit value without bit-packing; and the profile under which the identity was allocated, as an explicit discrete value.

The Class column MUST be directly queryable with ordinary SQL equality, join, and foreign-key operations. Bitwise extraction MUST NOT be required to read the Class. The profile column MUST be an explicit, typed value; implementations MUST NOT infer the profile from a numerical threshold, bit pattern, or encoded range. Legacy records allocated under v1.41 or v1.42 MUST be assigned an explicit profile value at migration time.

The profile column is record-level provenance. It is not part of the 64-bit identifier.

### 5.4 Class stability and Virtual Engine binding

Class remains stable for the lifetime of an allocated identity. A Virtual Engine is identified by `(Class, Engine)`; its Class binding is immutable.

An ordinary lookup under a different Class identifies a different Virtual Engine. It is not an attempt to access or reclassify the original Virtual Engine.

An attempt to modify an existing Virtual Engine's Class binding, or to transfer an allocated identifier into a different Class without the required retirement and reallocation process, MUST be rejected with `S64-E015 ENGINE_CLASS_BINDING_VIOLATION`.

A Class change for an identity requires a new identity under the applicable identity-replacement process. The old Identity Core remains permanently consumed.

### 5.5 Artificial spacecraft

Artificial or manufactured spacecraft, including Earth-orbiting artificial satellites and other spacecraft, use Class `0011` (IoT / Device).

### 5.6 Natural celestial entities

Naturally occurring celestial entities, including natural satellites, planets, stars, comets, asteroids, and meteoroids, use Class `1000` (Natural / Celestial Object).

## 6. Engine, Local, and Virtual Engine Architecture

The Engine field occupies bits 29–49 and is 21 bits wide. The Local field occupies bits 0–28 and is 29 bits wide.

### 6.1 Engine range

Engine is an unsigned 21-bit value: `0`–`2,097,151`. Values outside this range MUST fail with `S64-E023 COORDINATE_OUT_OF_RANGE`.

Each supported Class has its own independent Engine pool containing the complete 21-bit numerical range. Engine numbers MUST be unique within their own Class pool. The same numerical Engine number MAY exist in different Classes.

### 6.2 Local range

Local is an unsigned 29-bit value: `0`–`536,870,911`. Values outside this range MUST fail with `S64-E023 COORDINATE_OUT_OF_RANGE`.

Local value `0` is valid and MUST NOT be treated as a sentinel, null, or unassigned value. A Local coordinate that has been consumed MUST never be reused, including after retirement or Virtual Engine reclamation.

### 6.3 Virtual Engine identity and Class binding

A Virtual Engine is identified by the composite key `(Class, Engine)`. The Virtual Engine control table MUST use `(Class, Engine)` as its composite primary key, and no surrogate key may replace it for routing or binding purposes.

Each Virtual Engine is permanently bound to one Class. The same numerical Engine value in two Classes represents two different Virtual Engines with separate Local allocation namespaces: `(Class 1, Engine 120)` and `(Class 2, Engine 120)` are separate Virtual Engines.

The Class binding of an existing Virtual Engine MUST NOT be changed. Any attempt to alter this binding MUST be rejected with `S64-E015 ENGINE_CLASS_BINDING_VIOLATION`.

A System Admin MUST verify the Virtual Engine's Class property before shifting physical engine placement. A physical placement change MUST NOT change the Virtual Engine's Class binding.

Historical Virtual Engine lifecycle records MUST be preserved separately from the current control table entry. A reclaimed `(Class, Engine)` key MUST NOT overwrite or destroy its previous lifecycle history.

#### 6.3.1 Portable Virtual Engine control table

A conforming implementation MUST maintain a portable control table (hereafter `virtual_engines`) keyed by `(Class, Engine)` that holds, at minimum:

| Column | Content |
|---|---|
| `class` | The 4-bit Class value, as a discrete typed column |
| `engine` | The 21-bit Engine value, as a discrete typed column |
| `active_profile` | The profile under which the Virtual Engine is currently operating, as an explicit typed value |
| `generation_epoch` | A monotonically increasing integer, incremented on each QDH reclamation cycle for this `(Class, Engine)` |
| `lifecycle_state` | The current state of the §3 QDH state machine |
| `local_watermark` | The first-coordinate floor for the current generation |
| `physical_node_ref` | The `(Class, Engine)`-to-node binding of §6.3.2 |
| `allocator_authority_ref` | The current allocator authority, or null when none exists |
| `lineage` | An append-only record of prior generation epochs, each paired with the profile under which that generation operated and the reason for its closure |

The control table MUST be relational and portable across standard SQL databases. Implementations MUST NOT rely on vendor-specific system catalogs, comment-based metadata, or bit-packed columns to hold the fields listed above.

The `active_profile` column MUST be an explicit typed value. Implementations MUST NOT infer the active profile from the numerical value of another column, from an identifier range, or from any other implicit signal.

The `generation_epoch` column MUST be used to logically isolate successive lifecycles of the same `(Class, Engine)`. Writes attributable to a prior epoch MUST NOT be accepted as current.

The lineage record MUST be append-only. It MUST NOT be rewritten or pruned while any identifier from any prior generation remains subject to retention under §10.3. Each lineage entry MUST record the profile of that generation, because §16.1 step 4 compares an identity's recorded profile against the profile of the generation in which it was allocated.

#### 6.3.2 Control table semantics, placement, and durability

**Roles and separation of duties.** Four roles are distinguished and MUST NOT be collapsed into one another: the *controller* is the only writer of the control table; the *allocator* is the only writer of Local coordinates; the *QDH policy engine* is the only component that advances `generation_epoch` or changes lifecycle state; the *auditor* is read-only. No role may perform another's write. This separation is a normative property independent of how the roles are deployed.

**Two entity levels.** The control table references a *physical node* entity. A physical node is a stable logical record identified independently of its addresses. A Virtual Engine references exactly one physical node; a node hosts zero or more Virtual Engines. A flat `(Class, Engine)`-to-address mapping is insufficient, because node-wide quarantine (§9.3) requires that the node exist as its own entity.

**Minimum node attributes.** Node identifier, network address, hardware address, node state, and address-change history.

**Addresses are locators.** The network address (for example IPv4 or IPv6) and the hardware address (for example EUI-48 or EUI-64) are operational locators. They are not identity, are not part of the Identity Core, are not evidence for reconstructing Class, and MUST NOT be used to authenticate a host. Host trust derives from hardware attestation and a signed, epoch-bound allocator lease (§10.7.3).

**Address mutability.** The network address is reassignable at any time. The hardware address changes on network-interface replacement or virtualisation. Both are mutable, and neither may be treated as stable identity.

**Placement change.** A placement change is permitted while the Virtual Engine is not `STATE_ACTIVE`, and in `STATE_ACTIVE` only under an operator-governed maintenance window with Class verification under §6.3. It MUST NOT alter the Class binding, `active_profile`, `generation_epoch`, `local_watermark`, or lineage, and it MUST be recorded with timestamp, prior address, new address, and reason.

**Integrity and authority.** The control table is authoritative for binding, profile, epoch, and lifecycle state. It is not authoritative for consumption. Non-reuse is established from durable allocation evidence and permanent tombstones (§7.3, §10.3), never from the control table alone.

**Durability.** The control table MUST be replicated to an authoritative store independent of any single node, with committed rows recoverable without loss. Where an engine's Class is not encoded in its identifiers — every v1.41 engine — the control table row is the sole Class record, and its loss forbids reclamation; allocation remains suspended.

### 6.4 Engine exhaustion and rollover

When a Virtual Engine's Local namespace is exhausted, the controller MUST search Engine numbers numerically greater than the exhausted Engine number, in ascending order, within the requested Class's Engine pool. It MUST NOT wrap around to a lower Engine number.

A candidate Engine number is eligible only if it is in range and satisfies one of:

1. It is in `STATE_UNALLOCATED` within that same Class's Engine pool and is eligible for allocation under this specification; or
2. It is an existing Virtual Engine in the requested Class with allocatable Local coordinates remaining, **and** its prior allocator authority has been conclusively invalidated under §7.4 before it is adopted.

An existing Virtual Engine under a live allocator authority MUST NOT be adopted as a rollover target.

The controller MUST hold authority for the engine it issues from, and MUST hold a forward reservation covering the case that the issuing engine's namespace is exhausted before the next reservation can be established. A reservation MUST be in place before the final Local coordinate of the issuing engine is issued. Rollover is exhaustion handling; it MUST NOT be used to resume an interrupted allocation or as a failure recovery path (§7.1).

An Engine number in another Class's pool does not make the same numerical value unavailable in the requested Class.

Concurrent controllers MUST NOT claim the same `(Class, Engine)` key in a manner that permits conflicting allocations (`S64-E020 CONCURRENT_ALLOCATOR`).

`S64-E022 ENGINE_EXHAUSTED` applies when the current Virtual Engine's Local namespace is exhausted and the lowest eligible forward Engine has been safely reserved. If authoritative state or reservation safety cannot be established, allocation MUST fail closed with `S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` without issuing an identifier.

Existing identifiers in an exhausted Virtual Engine remain valid and routable. They are not automatically migrated. Migration and retirement continue to follow §10.

#### 6.4.1 Index-backed forward engine scanning

A conforming implementation MUST maintain an indexed free-list pointer, a real-time bitmap, or an equivalent indexed structure that identifies the next eligible forward Engine within each Class pool. The rollover search in §6.4 MUST NOT require an unindexed linear scan across the Engine pool or across the control table.

The structure MUST be updated atomically when an Engine is bound, exhausted, reclaimed, or reissued, so that a concurrent rollover search observes a consistent view of the next eligible candidate.

If the structure is lost or found inconsistent with the authoritative control-table state, the controller MUST rebuild it from authoritative evidence before the next rollover. Rebuilding MUST NOT issue identifiers and MUST NOT infer allocation state from a last-ID lookup.

### 6.5 Terminal Engine-ID exhaustion

If an authoritative search establishes that no eligible higher Engine number remains in the requested Class pool, allocation MUST fail with `S64-E029 ENGINE_ID_SPACE_EXHAUSTED`. This condition can occur before Engine number `2,097,151` if all remaining higher Engine numbers in that Class pool are exhausted or otherwise ineligible. No wraparound is permitted.

If the authoritative search cannot complete or reservation safety cannot be established, the implementation MUST report the applicable authority or safety failure (`S64-E012`, `S64-E019`, `S64-E020`, or `S64-E021`) instead of `S64-E029`.

Expansion of the Engine ID space requires a new profile or a separately defined Class assignment under a new profile. Existing identifiers MUST NOT be renumbered.

### 6.6 Virtual Engine capacity

Each Virtual Engine has a theoretical Local capacity of `2^29 = 536,870,912` coordinates. Each Class has a theoretical capacity of `2^21 × 2^29 = 2^50 = 1,125,899,906,842,624` Identity Core coordinates. For the eight currently assigned Classes: `8 × 2^50 = 2^53 = 9,007,199,254,740,992`.

These are theoretical capacities. Actual capacity depends on the number of supported Classes, consumed coordinates, and available Virtual Engine lifecycles. If future Class values in the reserved range are assigned under a future profile, the aggregate figure scales accordingly and is not a fixed property of v1.42.

## 7. Allocation, Non-Reuse, and Failure Safety

Each Virtual Engine MUST have an authoritative allocation mechanism for Local coordinates. The allocation namespace is the complete Identity Core `(Class, Engine, Local)`.

### 7.1 Power-cut and hardware-failure policy (FAIL_HARD)

Any detected power cut or hardware failure affecting the allocator, its authoritative state, or the integrity of allocation MUST produce the operational outcome FAIL_HARD.

The affected allocator MUST stop issuing identifiers and MUST NOT: perform a last-ID lookup; infer the last issued Local or Engine value; resume from a guessed position; roll back to a potentially reused coordinate; use rollover as a fallback; automatically retry the interrupted allocation; or automatically resume an interrupted allocation or migration.

The allocator MUST remain unavailable until authoritative state and allocation safety are established through an explicitly authorized procedure outside this failure path. If authoritative state and safety cannot be established, allocation MUST remain disabled. This procedure MUST NOT use a last-ID lookup as a substitute for establishing authoritative state.

Under v1.42, that explicitly authorized procedure is the QDH lifecycle of §10.7: quarantine, database-engineering verification of the first never-consumed Local coordinate, hardware-engineering sanitization and attestation, atomic epoch commit, and controlled reactivation. Under pre-v1.42 rules no such procedure existed, and a `FAIL_HARD` event permanently retired the entire `(Class, Engine)` Virtual Engine and its issued Local coordinates. Such engines are permanently ineligible for reclamation and MUST NOT be re-entered (`S64-E002`).

FAIL_HARD is an operational outcome, not a new `S64` error code. Where an interface requires an `S64` code and no more specific ordinary condition applies, `S64-E021` MAY be reported as the interface-level result. Reporting an `S64` code MUST NOT replace or weaken FAIL_HARD.

This rule takes precedence over ordinary allocation-error selection, validation errors, migration retries, and rollover.

### 7.2 Permanent Local non-reuse

A Local coordinate that has once been successfully allocated MUST NEVER be successfully allocated again within the same `(Class, Engine)` namespace (`S64-E018 LOCAL_REUSE_VIOLATION` for unretired coordinates; `S64-E016 RETIRED_COORDINATE_REISSUE` for retired coordinates). This prohibition applies across process restart, system restart, database restart, crash recovery, database restore, allocator replacement, failover, ownership transfer, network partition, delayed recovery, Virtual Engine reclamation, reallocation of the same `(Class, Engine)` key, and equivalent failure conditions.

No two successful allocations may return the same 54-bit Identity Core. Local coordinates are persistent and MUST NOT be reused.

Local allocation MAY be monotonic. Batch and range allocation MAY be used. If an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail (`S64-E021`).

### 7.3 First Never-Consumed Local Coordinate

Following an authorized Virtual Engine reclamation, allocation MUST continue from the first Local coordinate authoritatively established as never previously consumed for that `(Class, Engine)` key. A reclaimed Virtual Engine MUST NOT reset its Local allocation position to zero.

For example, if coordinates `0`–`499` were consumed during a previous lifecycle and authoritative evidence establishes that `500` is the first never-consumed coordinate, the new lifecycle MUST continue from `500`. The previous lifecycle's allocation records and tombstones MUST remain preserved.

If the first never-consumed Local coordinate cannot be established from authoritative evidence, allocation and reclamation MUST remain suspended for that Virtual Engine. The state is not automatically declared permanently unrecoverable; evidence may later be recovered through an authorized process, and allocation may resume only when safety and the correct watermark are established.

Implementations MUST maintain durable allocation evidence in an authoritative store independent of the allocator node's local storage, so that safe reclamation remains possible after physical node loss. The mechanism is an implementation decision; the property is normative.

Where Local coordinates are reserved through leases, the entire reserved range MUST be treated as permanently consumed for allocation purposes, even if every coordinate in the range was not actually issued, because an issued-but-unacknowledged coordinate cannot be distinguished from an unissued one after failure. A lease watermark MUST be durably recorded before the allocator is permitted to issue identifiers from that range.

This section MUST NOT be interpreted as permission to perform a last-ID lookup, infer a position, or resume automatically after FAIL_HARD.

### 7.4 Allocator authority and fencing

A stale allocator MUST NOT be capable of successfully committing a new allocation after its authority has ended. Any commit attempted by a stale allocator MUST be rejected with `S64-E019 ALLOCATOR_AUTHORITY_LOST`.

At most one authoritative active allocator may successfully commit allocations within a given `(Class, Engine)` namespace at a time (`S64-E020 CONCURRENT_ALLOCATOR`).

Ownership transfer between allocators MUST prevent the former allocator from successfully allocating after authority has transferred. Fencing MUST prevent stale allocators from committing after failover, ownership transfer, recovery, or a network partition. A new allocator obtains authority only after the previous authority has been conclusively invalidated.

Allocation may proceed only while the Virtual Engine is `STATE_ACTIVE` and its hosting node is active. Authority attached to an engine whose node is not active MUST NOT be exercised.

SMART does not prescribe the implementation mechanism used to provide these guarantees. The required properties are normative.

## 8. Routing Semantics

Routing in v1.42 uses `Class + Engine`. The Virtual Engine ID is the 25-bit concatenation of the 4-bit Class and the 21-bit Engine.

| Component | Width |
|---|---|
| Class | 4 bits |
| Engine | 21 bits |
| Virtual Engine ID | 25 bits |

The Virtual Engine ID is not a hash or surrogate. It is the composite key of a control-table row mapping to the network address of the node hosting that engine.

The resolution path is: identify profile from Version and Revision; extract Class and Engine; look up the Virtual Engine using `(Class, Engine)`; resolve the network address of the hosting node; extract Local; look up the Local coordinate; resolve the identity and its authoritative Class-property record.

A Class mismatch MUST be detected before physical engine resolution. `S64-E007 CLASS_MISMATCH` is a hard stop.

A Virtual Engine key not present in the control table is `S64-E013 VIRTUAL_ENGINE_NOT_FOUND`. A network address that is unreachable is `S64-E014 PHYSICAL_ENGINE_UNREACHABLE`.

Implementations MUST NOT apply the v1.41 Engine-alone routing rule to v1.42.

Physical placement MAY be rearranged for operational purposes, including load balancing, under the conditions of §6.3.2, provided that the Class binding and identity allocation namespace remain unchanged.

Local alone is not globally unique. Cross-Engine references MUST include sufficient information to identify the complete Identity Core or use the complete SMART identifier.

## 9. Database Representation and Node Safety

### 9.1 Database representation

A conforming implementation MAY use Engine-local database tables or equivalent namespaces in which Local is a primary key within the appropriate Virtual Engine namespace. The full 64-bit identifier MAY be stored as a public or current representation and need not be the relational primary key.

The authoritative identity uniqueness key MUST be the complete 54-bit Identity Core. The control table MUST use `(Class, Engine)` as its composite primary key and MUST include the explicit columns specified in §6.3.1. The Class-property record MUST store Class and profile as explicit, queryable columns as specified in §5.3.1.

Historical Virtual Engine lifecycle records MUST be retained separately so that a reclaimed key does not overwrite the history of its previous lifecycle.

### 9.2 Class storage

A conforming implementation MUST maintain an authoritative Class-property record for every allocated identity and MUST verify that the encoded Class agrees with that record. The record MAY be stored in the identity's primary record, a separate table, or an equivalent authoritative data store. Cached or replicated copies MAY be used if they do not introduce a conflicting Class value or undermine the authoritative association.

SMART does not prescribe SQL or NoSQL, database vendor, replication model, partitioning technology, consensus mechanism, caching, authentication, authorization, or transport protocol.

### 9.3 Node-wide quarantine

When a physical node experiences an incident that may affect an allocator, authoritative allocation state, or allocation integrity, the node and all Virtual Engines hosted on it MUST enter the applicable incident investigation and quarantine controls. Every hosted Virtual Engine, in any non-terminal state, MUST be able to enter quarantine.

The investigation MUST assess the node and its hosted Virtual Engines. An Engine MUST NOT be presumed unaffected merely because its own application process appears operational.

The quarantine and investigation process MUST establish whether allocation authority, authoritative state, and non-reuse safety remain intact.

Quarantine MUST stop old-node allocation. Fencing MUST prevent stale allocator commits (`S64-E019`). New allocator authority may be established only after prior authority has been conclusively invalidated.

Reclamation of a Virtual Engine following QDH is specified in §10.7.

### 9.4 Independent Engine return to service

Following the node-wide investigation, an individual Virtual Engine MAY return to service only after its own allocation safety has been independently established. The assessment of one Virtual Engine MUST NOT automatically authorize another Virtual Engine to return to service.

The FAIL_HARD requirements of §7 remain applicable. A return to service MUST NOT bypass authoritative-state verification, allocator fencing, or the applicable QDH process.

## 10. Retirement, Migration, Reclamation, and Record Retention

### 10.1 Retirement and workflow status

Retirement is a record-level transition. State (active or retired) is a property of the authoritative allocation record; it is not encoded as a bit in a v1.42 identifier. An identifier is retired by transitioning its canonical allocation record from active to retired, not by modifying the 64-bit identifier.

Workflow status, such as on hold, is operational and allocator-level. It is separate from the normative record state.

Activation is separate from allocation. An identifier is allocated when its Identity Core is consumed and its record is created; it becomes active only when its state is set to active. An allocated identifier that is not yet active is searchable by administrative tooling but is not resolvable by ordinary lookups.

### 10.2 Permanent consumption of the Identity Core

A retired identifier's complete 54-bit Identity Core MUST NOT be reissued under any active profile of the SMART 64-Bit ID family (`S64-E016 RETIRED_COORDINATE_REISSUE`). The Identity Core remains permanently consumed; there is no release point.

A retired identifier MUST NOT be reused, reactivated, reallocated, or treated as a free coordinate. The prohibition applies regardless of whether a later allocation would have different Metadata bits.

### 10.3 Retention and tombstones

A retired identifier's full record MUST be retained indefinitely for as long as the SMART profile under which it was allocated remains in force (`S64-E017 RETIRED_RECORD_MISSING`).

The retained record MUST preserve: the complete Identity Core; the encoded Class; the profile under which the identity was allocated, as an explicit value; the generation epoch under which it was allocated; the Role; the allocation coordinate; retirement status; and the history-chain link.

In addition to the full retired record, a permanent coordinate-consumption tombstone MUST be retained for every consumed Identity Core. The tombstone MUST preserve sufficient information to enforce non-reuse, including the Identity Core, the allocating profile, the allocating generation epoch, and consumption or retirement status.

Tombstone retention is not conditional on the allocating profile remaining in force.

### 10.4 Per-profile retention

A v1.42 retired identifier's record MUST be retained under v1.42. Retention obligations for identifiers allocated under other profiles arise from the profile under which those identifiers were allocated, or from applicable law or governance. The silence of v1.42 on another profile's records is not permission to discard them.

### 10.5 Migration and designation change

Migration means retirement of an old identifier and allocation of a new identifier. The old identifier is never migrated, reused, or rewritten. Allocation precedes retirement.

The sequence is:

1. The receiving Virtual Engine allocates a new Local coordinate through its authoritative allocation mechanism. The coordinate is consumed and its record is created inactive.
2. The receiving Virtual Engine creates the new identifier's authoritative Class-property record.
3. The new identifier's history chain is linked to the source identifier, inheriting the source's `history_chain_root_id` (§10.6).
4. The source record transitions to retired and the successor record transitions to active atomically from the perspective of ordinary lookups, or through an equivalent protocol guaranteeing the same observable result.
5. The retired Identity Core remains permanently consumed and both records are retained.

A separate workflow or on-hold state MAY be used before commit.

If allocation fails without a power cut or hardware failure, the source remains active. If record creation or history linking fails, the operation aborts and the allocated successor coordinate remains consumed. If the atomic transition fails without a power cut or hardware failure, the source remains resolvable and the successor remains non-resolvable.

The operation MAY be retried only while authoritative state and allocator authority are positively established. Any power cut or hardware failure invokes FAIL_HARD; the system MUST NOT perform a last-ID lookup or automatically resume or retry the interrupted sequence.

The receiving Virtual Engine MUST allocate the new Local coordinate through its authoritative allocation mechanism. It MUST NOT copy, preserve, request, or manually assign the source Local coordinate. Migration MUST NOT bypass normal allocation safety.

The receiving Virtual Engine MUST belong to the same Class as the source identity unless the operation is explicitly a Class change, which is not a migration under this section (`S64-E015`).

### 10.6 Identifier history chain

Each allocated identifier record MUST record the identifier it replaced, if any, or an explicit first-allocation marker. The history chain MUST be retained for as long as any identifier in the chain is retained.

Each identity record MUST carry a stable `history_chain_root_id`. A first allocation sets its root to its own Identity Core. A successor MUST inherit the root of the identity it replaced. A successor that does not inherit its predecessor's root is non-conforming, and the one-resolvable invariant of §10.6.1 cannot be established for it.

At most one identifier in a history chain may be resolvable by ordinary lookups at any time. A pending successor MUST remain non-resolvable while the source remains active.

A power cut or hardware failure MUST invoke FAIL_HARD. The implementation MUST NOT expose both identifiers as resolvable or declare the transition complete unless the atomic transition has committed.

The history chain is the authoritative record of which Identity Cores the entity has consumed. The permanent tombstone is the fallback record enforcing non-reuse.

#### 10.6.1 Partial unique index for chain resolvability

The database schema MUST enforce the one-resolvable-identifier invariant of §10.6 at the storage layer.

For every history chain, identified by its `history_chain_root_id`, the schema MUST enforce that at most one record in the chain has `is_active = TRUE` at any given time.

This constraint MUST be enforced by a partial unique index, a filtered unique constraint, or an equivalent database-level mechanism. It MUST NOT be enforced solely by application code.

If a restore, replication catch-up, administrative operation, or concurrent transition would produce two active records in the same chain, the database MUST reject the write.

The externally observable invariant is that at no time do two identifiers in the same chain resolve through ordinary lookups.

### 10.7 Virtual Engine reclamation (QDH)

A Virtual Engine that has entered quarantine or unavailability under v1.42 MAY be reclaimed and returned to service only through an authorized QDH lifecycle transition.

QDH denotes the recovery programme of **Quarantine, Database Engineering, and Hardware Engineering**. The Hardware Engineering phase comprises sanitization and refurbishment. This expansion is fixed; the programme MUST NOT be referred to by another expansion in any conforming document.

#### 10.7.1 Deterministic reissue

A reclaimed Virtual Engine MUST be reissued under its existing `active_profile` as recorded in the control table (§6.3.1).

Reissue is deterministic. There is no administrative discretion over which Revision a reclaimed Virtual Engine adopts: an engine whose `active_profile` is v1.41 reissues under v1.41, and one whose `active_profile` is v1.42 reissues under v1.42.

A profile change is not part of reissue. Changing a Virtual Engine from one profile to another is a distinct, explicit profile-upgrade operation governed by §13.1, and MUST NOT occur as a side effect of QDH reclamation, allocator reissue, or any other lifecycle transition.

Before reissue, the QDH process MUST establish the engine's first never-consumed Local coordinate under §7.3. The reissue transition MUST atomically perform all three of the following, or MUST use an equivalent protocol that guarantees the same externally observable result:

1. Increment `generation_epoch` in the control table.
2. Append the prior generation epoch and the profile under which it operated to the lineage record.
3. Authorize the new allocator for the reissued Virtual Engine.

No new allocation under the reissued Virtual Engine may commit unless all three have been durably completed. If the transition is interrupted by a power cut or hardware failure at any point, FAIL_HARD applies and allocation remains disabled until the transition is completed or authoritatively rolled back through an explicitly authorized procedure.

Reissue under the existing `active_profile` does not relax any safety property. §7.2, §7.3, and §7.4 apply to the reissued engine without exception.

#### 10.7.2 Epoch-fenced database writes

The Local coordinate write path MUST enforce a generation-epoch match at the point of write.

Any write that creates, activates, retires, or otherwise mutates an allocation record for a `(Class, Engine, Local)` coordinate MUST be conditioned on the write's generation epoch matching the current `generation_epoch` value in the control table for that `(Class, Engine)`.

The match MUST be enforced by one or more of:

1. A database-level trigger or constraint that evaluates the comparison against the current control-table row inside the same statement as the write.
2. A conditional update of the form `WHERE engine_epoch = current_engine_epoch` applied in the same statement as the write.
3. A serializable transaction that reads `generation_epoch` and performs the write with conflict detection, aborting on serialization failure.

A bare read-then-write at a weaker isolation level does not satisfy this requirement. A declarative check constraint alone cannot reference another table and does not satisfy this requirement.

The comparison and the write MUST be a single transactional or serializable unit, or a database-enforced conditional evaluated at write time.

Writes that record the consumption or retirement of a coordinate in a prior generation MAY be performed under the prior generation's epoch, provided the write is append-only and does not affect current-generation allocation state. Such writes are exempt from the current-epoch match requirement. The exemption exists so that permanent consumption tombstones (§10.3) may be written after the epoch has advanced. It does not permit a prior-generation allocator to commit a new allocation, a reactivation, or any write that would alter current-generation allocation state.

A write whose generation epoch does not match the current epoch MUST be rejected; it MUST NOT be silently ignored, coerced, or retried against the current epoch. A rejected prior-generation write MUST be reported as `S64-E019 ALLOCATOR_AUTHORITY_LOST` if the write originates from a stale allocator whose authority has ended, or as `S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` if the source cannot establish current authoritative state.

This rule protects against stale asynchronous workers, delayed network packets, and administrative operations that would otherwise commit against a prior generation after the engine has been reclaimed.

#### 10.7.3 Automated QDH governance

QDH MUST operate as an automated policy engine rather than a manual approval gate.

The QDH process MUST validate, at minimum: node and engine fitness for return to service; authoritative establishment of the first never-consumed Local coordinate under §7.3; absence of any residual allocator authority from prior generations; and presence and consistency of the prior generation's records and tombstones under §10.3.

When automated fitness and watermark safety are established, the control plane MUST increment `generation_epoch`, append the prior generation to the lineage record, and authorize the authoritative allocator for the reissued Virtual Engine.

These three actions MUST be performed atomically with respect to the control-table row for the reissued engine, or through a transactionally equivalent protocol in which no intermediate state is externally observable. A partial completion MUST NOT authorize an allocator and MUST NOT expose an advanced `generation_epoch` without the corresponding lineage entry. If the transition is interrupted by a power cut or hardware failure at any point, FAIL_HARD applies under §7.1 and allocation remains disabled until the transition is completed or authoritatively rolled back through an explicitly authorized procedure.

These actions MUST NOT require manual administrative intervention for standard reclamation.

Manual intervention MAY be required only when the automated QDH process cannot establish fitness or safety from authoritative evidence — for example, when the first never-consumed Local coordinate cannot be established, when authoritative state is unavailable, or when a specific incident class requires human judgment under the operator's governing policy. In such cases allocation MUST remain suspended until the condition is resolved under §7.3 or §7.1.

Automated QDH governance does not relax FAIL_HARD. A qualifying power cut or hardware failure still invokes FAIL_HARD under §7.1, and the allocator remains unavailable until authoritative state and safety are established through the explicitly authorized procedure described there.

## 11. Engine Retirement and Unavailability

SMART does not require a Virtual Engine to remain available indefinitely.

An identifier whose Virtual Engine becomes unavailable, retired, transferred, or otherwise inaccessible remains an identifier. Its record remains subject to the retention requirements of §10.3.

Resolution behavior for unavailable Virtual Engines is not defined by the identifier format. SMART does not encode or infer a successor Virtual Engine.

An association between an old identity and a new identity cannot be inferred solely from numerical proximity, Engine contiguity, or Local adjacency.

Virtual Engine retirement is distinct from identifier retirement. A Virtual Engine may be retired while identifiers allocated within it remain records. An identifier may be retired while its Virtual Engine remains active.

Reclamation of a Virtual Engine number is governed by §10.7. Retirement of a Virtual Engine number without reclamation is final for that key: a key retired outside the QDH process MUST NOT be re-entered as a new Virtual Engine.

## 12. Version and Revision

Bit 63 is Version. Bits 59–62 are Revision. Together they select the applicable SMART profile.

For Version 0:

| Version | Revision | Profile | Status |
|---|---|---|---|
| 0 | `0000` | Reserved / Historic (Obsolete) | Unsupported (`S64-E002`) |
| 0 | `0001` | SMART v1.41 | Active (Coexisting) |
| 0 | `0010` | SMART v1.42 | Active (Current) |
| 0 | Other assigned value | Future v1.x | Reserved |

Version 1 identifies the v2+ family.

A v1.x implementation encountering Version 1 MUST NOT interpret the identifier as a v1.x identifier. It MUST reject the identifier with `S64-E002`, or delegate it according to the implementation boundary. Delegation MUST NOT silently reinterpret the identifier as a v1.x identifier.

An implementation encountering Revision `0000` or any unassigned Revision MUST treat it as unsupported (`S64-E002`) and MUST NOT guess its meaning.

Revision is a profile selector, not a literal textual representation of the release number. The Version 0 family has 16 possible Revision values; if those are exhausted, incompatible future evolution requires a new Version family.

A failed validation under one profile MUST NOT be treated as proof that the identifier belongs to another profile.

Profile provenance for an allocated identity is recorded explicitly in the authoritative Class-property record's profile column (§5.3.1) and, at the Virtual Engine level, in the control table's `active_profile` column (§6.3.1), with the per-generation profile history in the lineage record. Implementations MUST NOT infer profile provenance from a numerical threshold, bit pattern, or identifier range.

## 13. Profile Coexistence: v1.41 and v1.42

SMART v1.41 and v1.42 are the active profiles of the Version 0 family. They coexist. Neither supersedes, obsoletes, or replaces the other. Pre-v1.41 revisions are historic and obsolete.

A v1.42 identifier is not a v1.41 identifier, and a v1.41 identifier is not a v1.42 identifier.

### 13.1 Mutual invalidity and profile upgrade

Under normal validation, a cross-profile identifier is rejected at profile identification because its Version/Revision does not select the target profile (`S64-E002`). Forced interpretation under another profile MUST NOT replace profile selection (`S64-E026 PROFILE_BOUNDARY_VIOLATION`).

No automatic migration between profiles is implied or permitted. Any conversion is an explicit operation that preserves identity relationships and follows the applicable allocation rules.

A profile change for a Virtual Engine is a distinct, explicit operation. It MUST NOT be performed as an implicit side effect of QDH reclamation or of any other lifecycle transition. The operation MUST satisfy all of:

1. It is authorized under a separately defined profile-upgrade procedure.
2. It is recorded in the control table before the engine operates under the new profile.
3. It opens a new generation boundary: `generation_epoch` is incremented and a lineage entry is appended for the closed generation, recording that generation's profile and the closure reason `PROFILE_UPGRADE`.
4. It MUST NOT rewrite the profile recorded on any existing identity record; that value is immutable (§17, `S64-E024`).
5. It MUST NOT change the Class binding of the engine (`S64-E015`).

Identities allocated before the upgrade remain valid after it. §16.1 step 4 compares an identity's recorded profile against the profile recorded for the generation epoch in which that identity was allocated, not against the engine's current `active_profile`.

### 13.2 Profile identification

An implementation MUST identify the profile from Version and Revision before interpreting profile-dependent fields. A failed validation under one profile MUST NOT be treated as proof that the identifier belongs to another profile.

### 13.3 Profile-specific field handling

The v1.42 rule that bits 50–53 carry the encoded taxonomy value applies only after an identifier has been identified as v1.42. In v1.41, bits 50–53 are a zero-valued Class marker (`0000`) and all Class properties are resolved strictly from the authoritative database table. Future profiles MUST be validated according to their own specifications.

### 13.4 Profile-restricted boundaries and selection rule

At a boundary configured to accept only a specific profile, an identifier from another active or obsolete profile MUST NOT be accepted, silently discarded, stripped, mutated, downgraded, or passed downstream as though it belonged to the target profile.

The selection rule is: emit `S64-E002` on the standard read path when a gateway or parser encounters an unrecognized, obsolete, or out-of-scope Version/Revision header during initial profile identification; emit `S64-E026` when a restricted boundary or bridge actively intercepts an otherwise valid cross-profile identifier and attempts to force, mask, truncate, or coerce it into another profile's domain.

An implementation that stores identifiers from both v1.41 and v1.42 MUST retain the decoder and validation logic for each profile it stores.

## 14. Reserved Bits

Bits 54–57 are Reserved in v1.42. At generation, all four Reserved bits MUST be `0000`.

A v1.42 identifier containing any nonzero Reserved bit is non-conforming and MUST be rejected with `S64-E003 RESERVED_BITS_NONZERO`.

Reserved bits MUST NOT be used for private application data, hidden flags, implementation-specific state, or undocumented extensions.

Future specifications MAY assign currently reserved values under their own profile definitions. Such assignments do not change v1.42 requirements.

The Class field at bits 50–53 and the Reserved field at bits 54–57 are separate fields and MUST be validated independently.

### 14.1 Deferred expansion

A 5-bit Class expansion using bit 54 is a future option and is explicitly not part of v1.42. In v1.42, bit 54 remains Reserved and MUST be zero.

## 15. Binary Serialization

A SMART v1.42 identifier is an unsigned 64-bit integer.

The canonical binary wire representation MUST be unsigned 64-bit, big-endian, in network byte order. Bit 0 is the least-significant bit; bit 63 is the most-significant bit.

Textual representations MAY be defined by applications or future specifications, provided they preserve the same underlying unsigned 64-bit value.

An implementation MUST NOT use signed integer interpretation in a way that changes the identifier's numerical value or causes incorrect field extraction. Serialization and deserialization MUST preserve all 64 bits exactly (`S64-E028 SERIALIZATION_NONCANONICAL`).

An implementation MUST NOT rewrite Class, Reserved, Role, Version, or Revision merely to make an identifier acceptable to another profile (`S64-E026`).

## 16. Field Extraction and Validation

For an unsigned 64-bit identifier `ID`:

| Field | Expression | Width |
|---|---|---|
| Local | `ID & 0x1FFFFFFF` | 29 |
| Engine | `(ID >> 29) & 0x1FFFFF` | 21 |
| Class | `(ID >> 50) & 0x0F` | 4 |
| Reserved | `(ID >> 54) & 0x0F` | 4 |
| Role | `(ID >> 58) & 0x01` | 1 |
| Revision | `(ID >> 59) & 0x0F` | 4 |
| Version | `(ID >> 63) & 0x01` | 1 |

Logical right-shift semantics MUST be used. Any extraction inconsistent with these bit positions is `S64-E027 FIELD_EXTRACTION_INVALID`.

The authoritative Class-property record stores Class and profile as explicit, queryable columns (§5.3.1). The control table stores `active_profile`, `generation_epoch`, `lifecycle_state`, and `local_watermark` as explicit, queryable columns (§6.3.1). Neither requires bitwise extraction for ordinary queries.

### 16.1 Identifier validation order

An implementation MUST identify Version and Revision before applying profile-specific validation. For a v1.42 identifier the precedence is:

1. **Input format.** Input MUST be exactly 16 hexadecimal characters (0–9, A–F or a–f, case-insensitive). Prefixes, whitespace, separators, and other formatting are not permitted. Formatting is validated before length. Disallowed formatting is `S64-E011 MALFORMED_INPUT`; correctly formatted hexadecimal input of incorrect length is `S64-E001 INVALID_LENGTH`.
2. **Profile identification.** Version MUST equal `0`; Revision MUST equal `0010`. Otherwise `S64-E002 UNSUPPORTED_PROFILE`.
3. **Field validity.** Reserved MUST equal `0000` (`S64-E003`). Class MUST NOT be `0000` (`S64-E004`) or `1001`–`1111` (`S64-E005`). Both Role values are valid during field validation; `S64-E010` applies exclusively to prohibited Role-changing lifecycle operations (§4.1), not to field validation.
4. **Authoritative checks.** Required authoritative queries MUST complete; otherwise `S64-E012 VALIDATION_UNAVAILABLE`. If they complete: the complete Identity Core MUST be present in the allocation registry (`S64-E008`); duplicate canonical records for the same Identity Core are `S64-E009`; the authoritative Class-property record MUST exist (`S64-E006`); the encoded Class MUST agree with that record (`S64-E007`); and the profile recorded for the identity MUST match the profile recorded for the generation epoch in which that identity was allocated, as recorded in the control table lineage (`S64-E030 PROFILE_PROVENANCE_MISMATCH`). The engine's current `active_profile` governs new allocations only and MUST NOT retroactively invalidate identities allocated under a prior generation of the same engine. An attempt to alter an existing Virtual Engine's Class binding is `S64-E015`.
5. **Routing resolution.** `(Class, Engine)` MUST resolve to a control-table row (`S64-E013`). The network address MUST be reachable (`S64-E014`).

A power cut or hardware failure invokes FAIL_HARD and overrides ordinary validation and allocation error selection.

An implementation MUST NOT proceed past a failure at an earlier stage or report a later-stage condition as though earlier stages had succeeded.

### 16.2 Allocation and administrative operation validation

Allocation and administrative operations are validated separately from ordinary identifier validation and follow this normative precedence. These rules are mirrored in `ERROR-CODES.md` §4.5.

1. **Authority, fencing, and epoch first.** Confirm exclusive allocator authority (`S64-E019`, `S64-E020`), allocation safety (`S64-E021`), and current epoch match (§10.7.2) before evaluating or committing coordinate changes. No error-selection order may permit a stale allocator or a prior-generation writer to commit.
2. **Coordinate and lifecycle checks.** Validate coordinate ranges (`S64-E023`), permanent retirement non-reissue (`S64-E016`), Local non-reuse (`S64-E018`), and lifecycle-state admissibility of the requested transition (`S64-E031`).
3. **Administrative invariants.** Reject any attempt to modify an existing Virtual Engine's Class binding or transfer an allocated identity into a different Class without retirement and reallocation (`S64-E015`); to mutate Role in place (`S64-E010`); to modify the profile recorded on an existing identity (`S64-E030`); to modify immutable fields of a retired record (`S64-E024`); or to reactivate a retired identifier or treat a retired coordinate as free (`S64-E025`).
4. **Rollover and exhaustion.** Apply the lowest-eligible-forward-Engine policy within the requested Class pool (`S64-E022` once reserved, or `S64-E029` if exhausted), using the indexed structure required by §6.4.1.
5. **Failure policy.** Any power cut or hardware failure invokes FAIL_HARD. Where an interface requires an `S64` code and no more specific ordinary condition applies, `S64-E021` MAY be reported as the interface-level result without weakening FAIL_HARD.

An ordinary read does not execute administrative or allocation validation.

### 16.3 Error-code registry reference

`ERROR-CODES.md` is the authoritative registry for v1.42 error identifiers and defines the normative diagnostic codes that implementations MUST emit when the corresponding conditions occur. The registry and this specification are mutually normative and synchronized.

## 17. Representation and Identity Stability

For a given allocated v1.42 identity: the Identity Core MUST remain stable; the encoded Class MUST remain stable; the authoritative Class-property record and its association MUST remain stable; the profile recorded in that record MUST remain stable; Role MUST remain stable; Version, Revision, and Reserved bits MUST remain unchanged; the complete Identity Core MUST remain globally unique across active profiles; and the `(Class, Engine)` to which the identity routes MUST retain its Class binding and its `active_profile`, except through the explicit profile-upgrade procedure of §13.1.

Profile stability is a property of the record, not of the engine. A profile upgrade changes the engine's `active_profile` and opens a new generation; it does not change the profile recorded on identities allocated in earlier generations, and those identities remain valid under §16.1 step 4.

If an operation changes Engine, it creates a new SMART identity rather than mutating the existing identity. If an operation changes Class or Role, the existing identity MUST NOT simply be rewritten.

A retired identifier's record MUST remain stable and retained under §10.3. Its encoded Class, its recorded profile, and its Role MUST NOT be changed. Its recorded generation epoch MUST NOT be changed.

## 18. Conformance

A conforming SMART v1.42 implementation MUST:

- Implement the specified bit positions and preserve the 54-bit Identity Core for an allocated identity.
- Enforce permanent global uniqueness of the complete Identity Core across v1.41 and v1.42.
- Generate assigned encoded Class values only (`0001`–`1000`); reject `0000` and `1001`–`1111`.
- Maintain an authoritative Class-property record for every allocated identity, verify that the encoded Class agrees with it, and store Class and profile as explicit, queryable columns (§5.3.1).
- Never require bitwise extraction for ordinary Class queries, joins, or foreign-key references; never infer profile provenance from a numerical threshold, bit pattern, or identifier range.
- Maintain a portable control table keyed by `(Class, Engine)` with the columns of §6.3.1, the semantics of §6.3.2, and the explicit `class`, `engine`, `active_profile`, `generation_epoch`, `lifecycle_state`, `local_watermark`, node binding, authority binding, and lineage columns.
- Never use vendor-specific system catalogs, comment-based metadata, or bit-packed columns for Virtual Engine state; never replace the `(Class, Engine)` key with a surrogate for routing or binding.
- Enforce independent Engine pools per supported Class; permit the same numerical Engine value in different Classes as separate Virtual Engines; preserve Class binding and `active_profile`.
- Preserve all 10 Metadata bits for an allocated identifier; reject in-place Role change and require retirement and reallocation.
- Permanently consume every allocated Identity Core; never reuse a Local coordinate, including across Virtual Engine reclamation; resume a reclaimed engine only from its first never-consumed Local coordinate established by authoritative evidence.
- Maintain durable allocation evidence independent of the allocator node and record lease watermarks before issuing from a lease (§7.3).
- Preserve historical Virtual Engine lifecycle records and the append-only lineage, including the per-generation profile.
- Reissue a reclaimed Virtual Engine deterministically under its existing `active_profile`; perform any profile change only through §13.1, including the new generation boundary and `PROFILE_UPGRADE` lineage entry.
- Enforce epoch-fenced writes at the point of write by one of the mechanisms of §10.7.2.
- Enforce allocator authority and fencing; enforce FAIL_HARD; apply node-wide quarantine and independently assessed engine return-to-service; require host fitness for allocation.
- Operate QDH as an automated policy engine as specified in §10.7.3, with the four roles of §6.3.2 separated.
- Maintain an indexed structure for forward engine scanning (§6.4.1); enforce the partial unique index for history-chain resolvability (§10.6.1) with root inheritance (§10.6).
- Retain retired records and permanent tombstones; maintain identifier history chains and the one-resolvable-identifier invariant.
- Generate Reserved bits as zero; correctly interpret Version and Revision; reject obsolete `0000` and unsupported profiles.
- Support canonical unsigned 64-bit big-endian binary interoperability.
- Distinguish v1.41 and v1.42 before interpreting profile-specific fields; reject incompatible identifiers at profile-restricted boundaries.
- Require receiving Virtual Engines to use authoritative allocation during migration; route on `(Class, Engine)`; detect Class mismatch before physical engine resolution; detect profile-provenance mismatch as `S64-E030` under §16.1 step 4.
- Apply identifier validation and allocation/administrative validation separately in accordance with `ERROR-CODES.md`.

An implementation that cannot satisfy an applicable safety, uniqueness, non-reuse, validation, Class-property, profile-provenance, retention, history-chain, epoch-fencing, host-fitness, or interoperability requirement MUST NOT claim conformance to SMART v1.42.

## 19. Non-Conforming Conditions

The following are non-conforming:

- Encoded Class `0000`, or Class in `1001`–`1111`, in an allocated v1.42 identifier.
- A missing, ambiguous, invalid, or incorrectly associated authoritative Class-property record; disagreement between encoded Class and that record.
- Nonzero Reserved bits; treating bit 54 as part of Class.
- Storing Class or profile in a bit-packed column instead of explicit typed columns; requiring bitwise extraction for ordinary Class queries, joins, or foreign-key references.
- Inferring profile provenance from a numerical threshold, bit pattern, or identifier range; relying on vendor-specific system catalogs or comment-based metadata for Virtual Engine state.
- Replacing the `(Class, Engine)` key with a surrogate for routing or binding; routing on Engine alone; using a network or hardware address as identity, as Class evidence, or as host authentication.
- Reuse of a previously consumed Local coordinate; reissue of a retired 54-bit Identity Core; two successful allocations returning the same Identity Core.
- A stale allocator successfully allocating after its authority has ended; a prior-generation writer successfully committing after the epoch has advanced.
- Changing the Identity Core of an allocated identity; changing Role by rewriting an existing representation; expressing a Role change without retirement and reallocation; changing the profile recorded on an existing identity.
- Changing the Class binding of an existing Virtual Engine; changing the `active_profile` outside §13.1; reallocating an identity into a different Class without the required process.
- Reusing a Local coordinate after reclamation; resetting a reclaimed engine's Local position to zero; reclaiming without authoritative evidence of the first never-consumed coordinate.
- Overwriting historical Virtual Engine lifecycle records or the append-only lineage; reissuing a reclaimed engine under a profile other than its existing `active_profile` outside §13.1.
- Adopting a live Virtual Engine as a rollover target without conclusive invalidation of its prior allocator authority.
- Unindexed linear scanning during rollover search; failure to maintain the indexed structure of §6.4.1.
- Failure to enforce the partial unique index for chain resolvability; creating a successor that does not inherit its predecessor's chain root.
- Two authoritative allocators successfully committing conflicting allocations in the same `(Class, Engine)` namespace; allocating while the hosting node is not active.
- Failure to enforce FAIL_HARD; failure to retain a retired record or permanent tombstone; two resolvable identifiers in the same chain; a pending successor with no resolvable identifier after a successful ordinary operation.
- Inferring a successor identity from numerical proximity, Engine contiguity, or Local adjacency.
- Deferring a Class mismatch, or a profile-provenance mismatch, to physical engine resolution.
- Silently interpreting an unsupported or obsolete Revision; interpreting Version 1 as a v1.x identifier; treating a v1.42 identifier as a valid v1.41 identifier or vice versa; rewriting or truncating identifier bits to appear to belong to another profile.
- Using non-canonical binary byte order where canonical interoperability is required.
- Re-entering a Virtual Engine key that was retired outside the QDH process.

## 20. Implementation Boundary

SMART defines identifier semantics, not an implementation's complete operational environment. An implementation MAY provide database storage, distributed allocation, replication, caching, APIs, message queues, authentication, authorization, monitoring, auditing, migration tooling, lifecycle management, quarantine and investigation workflows, and Virtual Engine lifecycle management. Those systems MUST preserve the normative requirements of this specification wherever they operate on SMART identifiers.

A proxy, gateway, database, service, or application that bypasses required SMART validation is non-conforming for that operation.

An implementation MAY choose how to store authoritative Class-property records, structure the control table, arrange physical node placement, manage workflow status, and retain retired records and tombstones. Those choices MUST preserve the properties defined in this specification.

The logical structure of the control table in §6.3.1 and §6.3.2 is normative. The physical schema, column names, data types, and indexing strategy MAY vary, provided the required columns exist, the required constraints are enforced at the database layer, and the required queryability and non-bit-packed properties are preserved.

## 21. Summary

SMART v1.42 provides a 64-bit identifier with the following fields:

| Field | Bits |
|---|---|
| Local | 29 |
| Engine | 21 |
| Class | 4 |
| Reserved | 4 |
| Role | 1 |
| Revision | 4 |
| Version | 1 |
| **Total** | **64** |

The 54-bit Identity Core is Class + Engine + Local, and is globally unique and permanently non-reusable across the active v1.41 and v1.42 profiles. A Virtual Engine is identified by `(Class, Engine)`; each Virtual Engine has its own Local allocation namespace, so the only valid identity key is the full coordinate `(Class, Engine, Local)`.

Local coordinates are never reused. A reclaimed Virtual Engine continues from its first never-consumed Local coordinate, established through authoritative evidence. The 10 Metadata bits are immutable for an allocated identifier in v1.42.

Profile provenance and Virtual Engine state are stored in explicit, queryable relational columns, not in bit-packed fields, and profile provenance is resolved per generation so that a profile upgrade does not invalidate previously allocated identities.

QDH reissue is deterministic and operates as an automated policy engine. Any profile change is a separate, explicit profile-upgrade operation under §13.1 and never occurs as a side effect of reclamation.

Concurrency safety is enforced by epoch-fenced writes at the point of write, with stale writes rejected as `S64-E019` or `S64-E021`. Rollover search is index-backed and must not degrade to unindexed linear scanning. History-chain resolvability is enforced by a partial unique index with root inheritance at the database layer.

Routing uses `(Class, Engine)`. Allocator authority, fencing, FAIL_HARD, quarantine, retirement, migration, record retention, and history-chain requirements preserve identity safety. v1.41 and v1.42 coexist as the active profiles of the Version 0 family; pre-v1.41 revisions are historic and unsupported.

Canonical binary serialization is unsigned 64-bit big-endian network byte order. Unknown or obsolete profiles MUST NOT be guessed. Reserved bits MUST remain zero in v1.42.

These requirements collectively define the SMART 64-Bit ID v1.42 profile.
