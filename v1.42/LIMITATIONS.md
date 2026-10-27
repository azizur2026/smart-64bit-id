# SMART 64-Bit ID v1.42 — Limitations and Non-Guarantees

**Status:** Release Candidate 1 — cross-check in progress

This note clarifies boundaries of the format. It does not amend SPECIFICATION.md.

## 1. No time-ordering guarantee

The v1.42 layout contains no timestamp field. Numeric order therefore does not represent generation-time order. The format does not promise time-sortability or encode creation time. Applications needing temporal metadata must maintain it separately.

## 2. Uniqueness depends on correct namespace governance

The uniqueness coordinate is Engine + Local. The bit layout alone cannot prevent two independent authorities from assigning the same Engine/Local pair. Implementations need authoritative Engine assignment and crash-safe, non-reusing Local allocation. v1.42 states allocator safety outcomes but does not mandate a particular consensus, database, lease, fencing, or recovery mechanism.

Global Engine-number registration, permanent Engine-number non-reuse after retirement, and the policy under which Engines are assigned to Classes are governance topics. In v1.42 the binding of each Engine to exactly one Class is a normative requirement (SPECIFICATION.md §6.3); what remains governance is the registration of Engine numbers and the policy under which Engines are assigned to Classes. v1.42 states the binding as a property; it does not define the authority that assigns an Engine to a Class.

## 3. Class is not a universal ontology

Class is a four-bit encoded taxonomy value defined by SMART. It does not prove an entity's legal status, ownership, biological nature, authority, or external classification. Class does not partition the Engine + Local allocation namespace. In v1.42 the Class is carried in the identifier; the profile assigns the binary values and their labels, and does not adjudicate membership in a Class.

## 4. Routing scope

The normative routing selector in v1.42 is Class + Engine. Local is looked up within the resolved Engine namespace. The virtual-engine ID is the 25-bit concatenation of Class and Engine; it is a row in the virtual-engine table, not a hash. v1.42 does not define the implementation of the virtual-engine table, the physical address resolution mechanism, or the administrative tooling for rearrangement. Those belong to the surrounding system, subject to the Class-binding property.

## 5. Role is not a relationship graph

Role is an immutable per-identifier designation. It does not encode ownership, a parent/child graph, legal agency, or the identity of an associated device/person. Those relationships require external records. Role is fixed for the allocated identifier but not for the entity; a change of designation is expressed by retirement and reallocation, and the profile does not define the criteria by which a designation is determined. Role is consumed by the application domain layer and is not read by the routing or allocation layers.

## 6. No authentication, secrecy, or authorization

A SMART ID is not a credential and does not authenticate its presenter. The format does not provide encryption, signatures, access control, or proof of ownership. In v1.42 the Class field directly exposes the entity category to anyone able to inspect the identifier; applications with confidentiality requirements should account for this.

## 7. No universal performance claim

The identifier layout alone does not guarantee faster queries, smaller indexes in every database, lower CPU cost, or superior throughput compared with UUIDs, Snowflake-like IDs, or other schemes. Results depend on schema, workload, database engine, indexing, hardware, caching, concurrency, and allocation design. The archived benchmark material outside this package is version-scoped and must not be presented as proof of v1.42 performance.

Because Class and Engine occupy the most-significant bits, concurrent inserts across different Classes will produce scattered B-Tree page writes. This is an inherent trade-off of spatial prefix routing: the prefix that makes routing fast also makes multi-class inserts non-sequential at the index layer. Mitigation is a database-layer concern (connection pooling, batched writes, fill-factor tuning), not an identifier-format concern.

## 8. Infrastructure remains implementation-specific

SMART does not define a complete distributed database, Engine registry, virtual-engine table implementation, allocator deployment, migration protocol, retry policy, or resolution service for retired or unavailable Engines. Implementations must design those systems while preserving the normative identifier requirements.

## 9. Retention cost and identifier-lifecycle alignment

In v1.42 a retired identifier's Engine + Local coordinate is permanently consumed, and a retired record must be retained for as long as the profile under which it was allocated remains in force. A coordinate-consumption tombstone must be retained permanently, independent of the full record's retention. These are normative properties of the profile, not choices. They have an operational cost that grows monotonically with the number of retirements. Implementations must plan for that cost. The profile does not prescribe a retention mechanism, archive format, or storage technology.

SMART v1.42's retirement model is consistent with established identifier-lifecycle practice. GS1 requires that an allocated GTIN SHALL NOT be reallocated to another trade item; the earlier four-year non-reuse period has been deprecated, with only narrow exceptions for items never produced and withdrawn items reintroduced unchanged. NIST SP 800-53 IA-4 requires organizations to prevent reuse of identifiers for an organization-defined period, defining this as preventing assignment of previously used identifiers to different individuals, groups, roles, or devices. ISO 8000-115:2024 specifies identifier syntax and resolution principles while explicitly leaving the methods of creation and resolution outside its scope. SMART v1.42 follows the same direction as GS1 and NIST: a retired coordinate is consumed permanently, with no release point. This is justified by the 2²⁹-per-Engine namespace, which makes permanence operationally cheap. The profile does not prescribe the resolution or allocation mechanism, consistent with the boundary ISO 8000-115 draws.

## 10. Mutual invalidity

v1.4, v1.41, and v1.42 coexist. Under normal validation, a cross-profile identifier is rejected at profile identification because its Version/Revision does not select the target profile. This is the decisive rejection. Independently, if force-read under the other profile's field rules, a v1.42 identifier has nonzero Class-marker bits under v1.41 field rules, and a v1.41 identifier has encoded Class 0000 under v1.42 field rules. The field-level observation is informative; profile selection is normative. An implementation must not treat a failed validation under one profile as evidence that an identifier belongs to another.
