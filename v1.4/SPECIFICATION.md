# SMART 64-Bit ID — Specification

**Technical Specification v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Scope

SMART 64-Bit ID defines a compact 64-bit identifier model for systems requiring:

* immutable identity;
* deterministic engine-aware routing;
* persistent local allocation;
* non-reusable identifiers;
* lifecycle state;
* generation-time region metadata; and
* future versioning capacity.

This specification defines the identifier structure, allocation semantics, routing behavior, lifecycle rules, persistence requirements, and mandatory failure behavior.

SMART ID does **not** prescribe a particular database vendor, deployment topology, control-plane architecture, authentication system, authorization system, or cryptographic implementation.

---

## 2. 64-Bit Layout

The SMART ID is exactly 64 bits.

| Bit Range |   Width | Field    | Classification     |
| --------- | ------: | -------- | ------------------ |
| 0–28      | 29 bits | Local ID | Identity           |
| 29–49     | 21 bits | Engine   | Identity / Routing |
| 50–57     |  8 bits | Region   | Metadata           |
| 58        |   1 bit | State    | Lifecycle metadata |
| 59–62     |  4 bits | Reserved | Future governance  |
| 63        |   1 bit | Version  | Format version     |

The bit numbering is **least-significant bit (LSB) to most-significant bit (MSB)**.

---

## 3. Identity Core

The identity core consists of:

* Local ID: 29 bits
* Engine: 21 bits

Therefore the identity core contains **50 bits**.

The theoretical identity-core space is:

**2^50 = 1,125,899,906,842,624**

approximately **1.13 quadrillion** possible Engine + Local ID combinations.

The identity core is immutable after generation.

Region, State, Reserved, and Version are outside the identity core.

---

## 4. Local ID

The Local ID occupies bits 0–28.

### 4.1 Capacity

A 29-bit Local ID provides:

**2^29 = 536,870,912 identifiers per Engine**

The Local ID therefore provides **536,870,912 identifiers per Engine**.

### 4.2 Allocation

Local IDs:

* are allocated within an Engine;
* are monotonic within the allocation domain;
* may be allocated individually or in batches;
* must be persistent across process and system restarts;
* must never be reused after allocation; and
* must not wrap around.

A randomized non-zero starting point may be used by an implementation. If used, the implementation must recognize that the randomized starting point consumes part of the finite Local ID range.

### 4.3 Exhaustion

Local ID exhaustion is a **FAIL HARD** condition.

An implementation must not wrap the counter, recycle previously allocated values, or silently continue with duplicate identity values.

Operational handling of exhaustion, such as obtaining or assigning another Engine, is the responsibility of the client/control plane.

---

## 5. Engine

The Engine field occupies bits 29–49.

### 5.1 Capacity

A 21-bit Engine field provides:

**2^21 = 2,097,152 possible Engine IDs**

### 5.2 Allocation

Engine IDs are assigned at generation time and are immutable for the generated identifier.

Engine allocation and provisioning are responsibilities of the client/control plane.

SMART ID does not mandate a particular Engine allocation architecture.

A client may use a centralized allocator, distributed control application, leases, fencing, or another appropriate mechanism, provided that the requirements of this specification are satisfied.

### 5.3 Engine Rotation

Implementations should rotate Engine assignments to distribute write activity and avoid concentrating all generation activity on a permanently fixed Engine.

Static assignment of a single Engine as the permanent generation strategy is not the intended operating model.

---

## 6. Engine Ownership and Fencing

At any time, an Engine ID **MUST have at most one authoritative active allocator**.

Concurrent or stale ownership of the same Engine ID **MUST be prevented**.

If ownership cannot be established unambiguously, generation using that Engine **MUST FAIL HARD**.

Implementations may use leases, fencing tokens, epochs, centralized ownership records, or equivalent mechanisms to prevent stale or concurrent allocators from generating identifiers under the same Engine.

A network partition, process failure, delayed restart, or stale control-plane instance must not permit two independent authorities to generate Local IDs for the same active Engine.

The fundamental uniqueness invariant is:

> **No duplicate Engine ID + no duplicate Local ID → FAIL HARD.**

Any condition that can result in duplicate identity generation must be treated as a generation failure rather than silently producing an identifier.

---

## 7. Control-Plane Architecture

SMART ID does **not** mandate a particular Engine allocation or control-plane architecture.

The client is responsible for ensuring:

* authoritative Engine ownership;
* non-conflicting Engine allocation;
* persistent Local ID allocation;
* prevention of stale ownership;
* prevention of duplicate generation; and
* appropriate failure handling.

A reference implementation may use a centralized control application because it is practical, but that is an implementation choice and is **not a requirement of SMART ID**.

---

## 8. Region

The Region field occupies bits 50–57 and provides 8 bits of metadata.

Region represents a generation-time regional or country classification.

Region is **not part of the identity core**.

Region is also:

* not a routing field;
* not an Engine selector;
* not required for primary-key lookup; and
* not a uniqueness mechanism.

Region may be remapped for presentation or governance purposes.

Implementations may preserve the original generation-time Region value as a historical snapshot when historical interpretation is required.

---

## 9. State

The State field occupies bit 58.

State is a lifecycle marker.

### State values

| Value | Meaning            |
| ----: | ------------------ |
|     1 | Enabled            |
|     0 | Retired / Disabled |

State is **not part of routing**.

State is evaluated as an index-level lifecycle filter or equivalent application/database filter.

### 9.1 Retirement

When an identity must be replaced because an underlying entity is transferred or otherwise requires a new identifier:

1. a new SMART ID is generated;
2. the new identity becomes the current identity;
3. the old SMART ID is set to State = 0; and
4. the old identifier is permanently retired.

A retired SMART ID must never be reused.

---

## 10. Reserved Bits

Bits 59–62 are reserved.

Current implementations must set Reserved bits to zero unless a future SMART ID specification explicitly assigns a different meaning.

Reserved bits provide capacity for future governance or format evolution.

---

## 11. Version

Bit 63 is the Version field.

For the v1.x SMART ID format:

**Version = 0**

Version value 1 is reserved for a future v2 format unless formally assigned by a later specification.

Implementations must not reinterpret the Version bit independently of the applicable SMART ID specification.

---

## 12. Routing

SMART ID routing uses fixed-position bit extraction.

The routing path is:

```text
64-bit SMART ID arrives
        │
        ▼
Extract Engine
(bits 29–49)
        │
        ▼
Route to Engine
        │
        ▼
Extract Local ID
(bits 0–28)
        │
        ▼
Full primary-key lookup
```

Engine determines the destination Engine.

Local ID identifies the local record within that Engine.

Region is not used for routing.

State is not used for routing.

Reserved and Version fields are not routing selectors.

### 12.1 Constant-Width Extraction

Because the SMART ID has a fixed 64-bit representation and fixed field positions, Engine and Local ID extraction requires a fixed number of bit operations with respect to identifier width.

Actual CPU instruction count and latency are implementation- and microarchitecture-dependent.

This specification therefore does **not** claim a universal CPU-cycle count for SMART ID extraction.

---

## 13. Identity Lookup

After routing to the appropriate Engine, the complete SMART ID remains available as the primary identifier.

The recommended conceptual lookup sequence is:

```text
SMART ID
  │
  ├── Engine → routing destination
  │
  └── Local ID → local lookup component
```

Implementations may retain the complete 64-bit SMART ID as the database primary key.

SMART ID does not require a particular database engine or indexing implementation.

---

## 14. Persistence

Local ID allocation state must be persistent.

An implementation must ensure that allocated Local IDs cannot be lost and subsequently reused after:

* process restart;
* system restart;
* database restart;
* transaction failure;
* crash recovery; or
* equivalent failure conditions.

Where shared allocation state exists, appropriate concurrency control such as row-level locking or an equivalent mechanism is required.

SQLite, MyISAM, or other storage mechanisms that cannot satisfy the required allocation and concurrency guarantees are outside the intended reference model.

---

## 15. Crash Recovery

Crash recovery must prioritize uniqueness and non-reuse over gaplessness.

If a Local ID has been allocated and a subsequent operation fails before the associated record is fully committed, that allocated Local ID may become a gap.

Such gaps are acceptable.

An implementation must **not** reuse the abandoned value merely to maintain sequential continuity.

The governing rule is:

> **Allocated identifiers are never reused.**

---

## 16. Batch Allocation

SMART ID supports batch allocation of Local IDs.

Batch allocation may improve allocation efficiency and reduce coordination overhead.

Implementations should clearly distinguish:

* allocation/reservation order; and
* record commit or visibility order.

These orders do not necessarily have to be identical.

The specification does not require gapless numbering.

---

## 17. Uniqueness Requirements

The following invariants are mandatory:

1. An Engine ID must not have conflicting authoritative active allocators.
2. A Local ID must not be generated twice within the same authoritative Engine ownership domain.
3. An allocated SMART ID must never be reused.
4. Local ID exhaustion must not result in wraparound.
5. Conflicting Engine ownership must result in generation failure.
6. Any detected condition capable of producing duplicate identity must **FAIL HARD**.

Uniqueness takes priority over continuity and gaplessness.

---

## 18. Public IDs and Format-Preserving Encryption

SMART ID's internal identity and routing model is separate from public-ID cryptographic processing.

An implementation may use format-preserving encryption (FPE) or another appropriate mechanism when a public representation requires protection of the underlying identifier structure.

FPE is **not**:

* authentication;
* authorization;
* integrity protection;
* access control; or
* a replacement for application security.

Cryptographic processing of public identifiers must therefore be treated as a separate security layer.

SMART ID does not define or require a proprietary cryptographic algorithm.

---

## 19. Security Boundary

SMART ID defines an identifier and routing model.

It does not define a complete security architecture.

Implementations remain responsible for appropriate:

* authentication;
* authorization;
* integrity protection;
* key management;
* cryptographic implementation;
* secret handling;
* transport security;
* database security; and
* operational security controls.

The use of a SMART ID does not by itself provide authorization or confidentiality.

---

## 20. Serialization

SMART IDs should be serialized as strings in JSON and other APIs where numeric interoperability may be uncertain.

Implementations must not assume that all application runtimes can safely represent the complete unsigned 64-bit range using their default numeric type.

In particular, environments based on IEEE-754 double-precision numeric representations may not preserve all integers above 2^53 exactly.

String serialization avoids this interoperability problem.

---

## 21. Cryptographic Standards

SMART ID implementations that use format-preserving encryption or related cryptographic mechanisms **MUST use such mechanisms in accordance with applicable internationally recognized and approved cryptographic standards and their current authoritative revisions**.

SMART ID does not define or require a proprietary cryptographic algorithm.

Compliance depends on the actual cryptographic algorithm, implementation, deployment, jurisdiction, and applicable standards.

This specification does not itself constitute a cryptographic certification.

---

## 22. Database Independence

SMART ID is database-independent at the specification level.

The specification does not require:

* MariaDB;
* MySQL;
* PostgreSQL;
* Oracle;
* SQL Server;
* a specific NoSQL database; or
* a specific storage engine.

Database implementations must nevertheless provide the persistence, concurrency, uniqueness, and recovery guarantees required by this specification.

---

## 23. Performance Claims

SMART ID does not guarantee a particular performance improvement across all systems.

Performance depends on factors including:

* database engine;
* storage engine;
* hardware;
* buffer/cache configuration;
* workload;
* concurrency;
* transaction settings;
* indexing strategy;
* query patterns; and
* implementation details.

The project's empirical findings are documented separately in the `research/` directory.

Measured results must not be interpreted as universal guarantees.

---

## 24. Architectural Boundary

### SMART ID defines

* the 64-bit structure;
* identity semantics;
* Engine and Local ID allocation rules;
* uniqueness invariants;
* routing semantics;
* lifecycle semantics;
* required failure behavior;
* persistence requirements; and
* the cryptographic standards boundary.

### SMART ID does not dictate

* client control-plane topology;
* Engine provisioning architecture;
* lease or fencing implementation;
* database vendor;
* deployment topology;
* authentication system;
* authorization system;
* network architecture; or
* a proprietary cryptographic algorithm.

These are implementation and deployment decisions.

---

## 25. Summary

SMART 64-Bit ID uses a 50-bit immutable identity core composed of a 29-bit Local ID and a 21-bit Engine ID.

The remaining 14 bits provide Region metadata, lifecycle State, Reserved capacity, and Version information.

The Engine field provides deterministic routing to the appropriate generation or storage domain, while the Local ID provides the local identity component.

The model prioritizes:

* immutable identity;
* deterministic routing;
* persistent allocation;
* non-reuse;
* authoritative Engine ownership;
* hard failure on uniqueness violations;
* explicit lifecycle retirement; and
* implementation-independent architectural boundaries.

SMART ID v1.4 is the technical baseline for the public release of this specification.
