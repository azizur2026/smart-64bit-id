# SMART 64-Bit ID

**Current Technical Specification: v1.41**
**Status: Stable**

SMART 64-Bit ID is a fixed-width 64-bit identifier model designed for persistent identity, distributed identity allocation, deterministic Engine-based routing, immutable identity semantics, and bounded representation/control metadata.

## Current Specification

The current normative specification is:

**[SMART 64-Bit ID v1.41](docs/SMART-64-Bit-ID-v1.41.md)**

v1.41 uses **Version `0`, Revision `0001`**.

SMART v1.4 remains a separate legacy profile and is not reinterpreted as v1.41.

---

## v1.41 Core Layout

| Bits  | Field    |    Size | Purpose                                   |
| ----- | -------- | ------: | ----------------------------------------- |
| 0–28  | Local    | 29 bits | Engine-local allocation identifier        |
| 29–49 | Engine   | 21 bits | Logical routing / namespace identifier    |
| 50–53 | Class    |  4 bits | Entity class                              |
| 54–57 | Reserved |  4 bits | Reserved for future specification         |
| 58    | Role     |   1 bit | Self-representing / dependent designation |
| 59–62 | Revision |  4 bits | Profile selector                          |
| 63    | Version  |   1 bit | Specification family selector             |

The persistent **Identity Core is 54 bits**:

* 29-bit Local
* 21-bit Engine
* 4-bit Class

The upper 10 bits define the current SMART representation/control layer. Role is structurally located in this area but is semantically an immutable attribute of the allocated identity.

---

## Identity Core

The Identity Core is:

```text
Class + Engine + Local
 4   +  21   +  29
      = 54 bits
```

For an allocated identity, the Identity Core is immutable.

Role is also preserved for the allocated identity.

If an operation changes Engine, it creates a **new SMART identity** rather than mutating the existing identity.

---

## Class

v1.41 defines:

| Value       | Class                                |
| ----------- | ------------------------------------ |
| `0000`      | Reserved / Unassigned / Invalid      |
| `0001`      | Human                                |
| `0010`      | Other Living Being                   |
| `0011`      | IoT / Device                         |
| `0100`      | AI                                   |
| `0101`      | Organization                         |
| `0110`      | Artifact / Object                    |
| `0111`      | Android / Humanoid Artificial Entity |
| `1000`      | Natural / Celestial Object           |
| `1001–1111` | Reserved / Future                    |

Class `0000` MUST NOT appear in an allocated SMART identifier.

Class is immutable after allocation.

SMART defines the encoding and permanence of Class; it does not define a universal external ontology or classification authority.

---

## Role

Bit `58` defines Role:

| Value | Meaning           |
| ----- | ----------------- |
| `0`   | Dependent         |
| `1`   | Self-representing |

Role indicates whether the identified entity is designated as a self-representing identity or as an associated/dependent identity within the applicable identification relationship.

Role MUST NOT be interpreted as a statement of legal capacity, legal agency, ownership, authority, autonomy, human status, or organizational status.

---

## Engine + Local Allocation

The allocation namespace is:

```text
Engine + Local
```

Class does not partition the allocation namespace.

### Engine

* 21 bits
* Range: `0 .. 2,097,151`

### Local

* 29 bits
* Range: `0 .. 536,870,911`
* Local `0` is valid

A Local ID that has once been successfully allocated within an Engine MUST NEVER be successfully allocated again within that Engine.

This requirement applies across restart, crash recovery, restore, failover, ownership transfer, network partition, allocator replacement, and equivalent failure conditions.

If an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail.

A stale allocator MUST NOT be capable of successfully committing a new allocation after its authority has ended.

---

## Routing

The routing model is:

```text
SMART ID
    ↓
Extract Engine
    ↓
Route to Engine namespace
    ↓
Extract Local
    ↓
Local ID lookup
    ↓
Entity
```

Engine is a logical routing and namespace identifier. It does not necessarily represent a physical server, machine, database instance, or geographic location.

Local alone is not globally unique.

Cross-Engine references MUST include sufficient information to identify Engine together with Local, or use the complete SMART identifier.

---

## Engine Migration

Changing the Engine creates a new SMART identity.

The receiving Engine MUST allocate a new Local ID through its authoritative allocation mechanism.

Migration MUST NOT bypass normal allocation safety.

The receiving Engine MUST NOT manually copy or assign the source Local ID merely for convenience.

If safe allocation cannot be performed, the migration MUST NOT create the new SMART identity.

The source identity remains unchanged.

Systems MAY maintain an external lifecycle/history association between the old and new identities.

---

## Version and Revision

v1.41 is:

```text
Version  = 0
Revision = 0001
```

The Version/Revision combination selects the applicable SMART profile.

Examples:

| Version | Revision | Profile     |
| ------: | -------: | ----------- |
|     `0` |   `0000` | v1.4        |
|     `0` |   `0001` | v1.41       |
|     `0` |   `0010` | Future v1.x |
|     `1` |        — | v2+ family  |

An implementation MUST NOT guess the meaning of an unsupported Revision.

A v1.x implementation MUST NOT interpret Version `1` as a v1.x identifier.

Unsupported profiles MUST be rejected or delegated according to the implementation boundary.

---

## Legacy v1.4

SMART v1.4 and v1.41 are distinct profiles.

In v1.4, bits `50–57` represent the v1.4 **Region** field.

In v1.41, those bits are divided into **Class** and **Reserved**.

A v1.41 implementation MUST NOT reinterpret a legacy v1.4 Region field as v1.41 Class + Reserved.

A boundary configured to accept only v1.4 MUST explicitly reject an incompatible v1.41 identifier rather than silently reinterpret, truncate, mask, downgrade, or mutate it.

---

## Reserved Bits

v1.41 bits `54–57` are Reserved.

They MUST be zero when generating a v1.41 identifier.

A nonzero Reserved value makes the identifier non-conforming as v1.41.

Reserved bits MUST NOT be used for private application data or undocumented implementation flags.

---

## Canonical Serialization

SMART v1.41 uses an unsigned 64-bit identifier.

The canonical binary representation is:

```text
Unsigned 64-bit
Big-endian
Network byte order
```

Implementations MUST preserve the exact underlying unsigned 64-bit value when converting between supported representations.

---

## Database Integration

SMART does not require a particular database technology.

An implementation MAY use Engine-local tables or equivalent namespaces with Local as a primary key.

The full 64-bit SMART ID MAY be stored as a public/current representation without being the relational database primary key.

SMART does not mandate:

* a database vendor;
* a replication model;
* a partitioning technology;
* a consensus mechanism;
* caching;
* CDC;
* authentication; or
* transport protocol.

---

## Research

The repository contains non-normative research and experimental material under `research/`.

Research results do not modify the normative v1.41 specification and should not be interpreted as universal performance guarantees.

Historical v1.4 research remains available for reference.

---

## Documentation

### Normative Specification

* [`docs/SMART-64-Bit-ID-v1.41.md`](docs/SMART-64-Bit-ID-v1.41.md)

### Legacy / Historical Documentation

* `docs/SPECIFICATION.md`
* `docs/RULES.md`
* `docs/ARCHITECTURE.md`
* `docs/STANDARDS.md`
* `docs/INDUSTRY_ALIGNMENT.md`
* `docs/LIMITATIONS.md`

These documents include material from earlier development and should be interpreted according to their applicable specification/profile.

### Research

* `research/FINDINGS_SINGLE_ENGINE.md`
* `research/FINDINGS_MULTI_ENGINE_INVALID.md`
* `research/BENCHMARK_PROTOCOL.md`
* `research/CYCLE_COMPARISON.md`

### Technical Papers

* `papers/SMART_64BIT_ID_PAPER.md`
* `papers/SMART_64-Bit_ID_Technical_Paper_v1.4.pdf`

### Examples and Diagrams

See `examples/` and `diagrams/` for non-normative implementation examples and explanatory material.

---

## Scope

SMART defines:

* 64-bit identifier structure;
* identity semantics;
* Class and Role semantics;
* Engine and Local allocation rules;
* uniqueness and non-reuse requirements;
* routing semantics;
* Engine migration requirements;
* profile/version handling;
* canonical serialization; and
* conformance requirements.

SMART does not mandate:

* a particular control-plane topology;
* a particular Engine provisioning system;
* a specific lease or fencing mechanism;
* a database vendor;
* a deployment topology;
* an authentication system;
* an authorization system; or
* a proprietary cryptographic algorithm.

---

## License

SMART 64-Bit ID is released under the GNU Affero General Public License v3.0. See [`LICENSE`](LICENSE).

A separate commercial/proprietary license may be available from the copyright holder. See [`COMMERCIAL-LICENSE.md`](COMMERCIAL-LICENSE.md).

---

## Copyright

Copyright (c) 2026 MD. AZIZUR RAHMAN
SAMARA

---

## Contact

Commercial licensing and project inquiries:

* [md.azizur.rahman@samara.com.bd](mailto:md.azizur.rahman@samara.com.bd)
* [contact@samara.com.bd](mailto:contact@samara.com.bd)

---

## Status

**SMART 64-Bit ID v1.41 is the current stable specification.**

The v1.41 specification is frozen under the `v1.41` release tag.

SMART v1.4 remains available as a separate legacy profile.
