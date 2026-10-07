# SMART 64-Bit ID v1.41

**Status:** Stable / Release Candidate
**Specification family:** SMART 64-Bit ID
**Profile:** Version `0`, Revision `0001`
**Supersedes:** No — v1.4 remains a separate legacy profile
**Document purpose:** Normative technical specification for SMART 64-Bit ID v1.41

---

## 1. Scope

SMART 64-Bit ID v1.41 defines a 64-bit identifier format for persistent identification of entities and associated/dependent identities.

This specification defines:

* the 64-bit binary layout;
* identity-core semantics;
* Class and Role fields;
* Version and Revision profile selection;
* reserved-bit requirements;
* Engine and Local ID allocation semantics;
* routing semantics;
* Engine migration behavior;
* legacy v1.4 compatibility boundaries;
* canonical binary serialization;
* decoding and validation requirements; and
* conformance requirements.

SMART defines identifier structure and required identifier behavior. It does not prescribe a particular database vendor, storage engine, network protocol, replication system, consensus mechanism, cache, authentication system, or operational architecture.

---

# 2. 64-Bit Layout

The v1.41 identifier is an unsigned 64-bit value.

Bits are numbered from bit `0` as the least-significant bit (LSB) through bit `63` as the most-significant bit (MSB).

```text
63        62 61 60 59        58        57 56 55 54        53 52 51 50        49 ........ 29        28 ........ 0
┌──────────┬───────────────┬──────────┬──────────────────┬──────────────────┬─────────────────────────┬─────────────────────┐
│ Version  │    Revision   │   Role   │     Reserved     │      Class       │         Engine          │        Local        │
│   1 bit  │     4 bits    │  1 bit   │      4 bits      │      4 bits      │         21 bits        │       29 bits       │
└──────────┴───────────────┴──────────┴──────────────────┴──────────────────┴─────────────────────────┴─────────────────────┘
```

### Field allocation

| Bits  | Width | Field    | Requirement                               |
| ----- | ----: | -------- | ----------------------------------------- |
| 0–28  |    29 | Local    | Allocation-local identifier               |
| 29–49 |    21 | Engine   | Engine / namespace identifier             |
| 50–53 |     4 | Class    | Entity class                              |
| 54–57 |     4 | Reserved | MUST be zero in v1.41                     |
| 58    |     1 | Role     | Self-representing / dependent designation |
| 59–62 |     4 | Revision | Profile selector                          |
| 63    |     1 | Version  | Specification family selector             |

---

# 3. Identity Core

The **54-bit Identity Core** consists of:

```text
Class + Engine + Local
4     + 21     + 29
= 54 bits
```

The Identity Core defines the persistent identity.

For an allocated SMART identity, the Identity Core MUST NOT be changed.

The upper 10 bits define the current SMART representation/control layer.

The fields in the upper 10 bits do not all have identical mutability semantics. In particular, Role is semantically an immutable attribute of the allocated identity even though it is structurally located within the Representation and Control Area.

The following statement applies:

> The 54-bit Identity Core defines the persistent identity. The upper 10 bits define the current SMART representation/control layer.

---

# 4. Role

Bit `58` is the Role field.

| Value | Meaning           |
| ----- | ----------------- |
| `0`   | Dependent         |
| `1`   | Self-representing |

Role indicates whether the identified entity is designated as a self-representing identity or as an associated/dependent identity within the applicable identification relationship.

SMART does not define the legal, organizational, technical, or governance criteria used to determine that designation.

Role MUST NOT be interpreted as a statement of:

* legal capacity;
* legal agency;
* ownership;
* authority;
* autonomy;
* human status; or
* organizational status.

For a given allocated identity, every valid representation MUST carry the same Role value.

A representation containing a conflicting Role value is non-conforming.

Any operation that creates, migrates, or changes a representation MUST preserve Role.

If the applicable designation changes, the existing identifier MUST NOT be rewritten solely to change Role. Lifecycle history or a new identity MAY be used according to the applicable system's requirements.

Examples:

* Human identity: `Role = 1`
* Android phone: `Role = 0`
* SIM: `Role = 0`
* Coffee-maker IoT device: `Role = 0`

---

# 5. Class

Bits `50–53` define the Class field.

| Binary      | Class                                |
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

Class values `1001–1111` are reserved for future assignment unless a later specification explicitly assigns them.

Class is immutable after allocation.

Reclassification of an entity MUST NOT mutate the Class field of an existing allocated identity. Applicable systems MAY represent the change through lifecycle history or allocation of a new identity.

SMART defines the encoding and permanence of Class. SMART does not define a universal external ontology or classification authority.

## 5.1 Artificial spacecraft

Artificial or manufactured spacecraft, including Earth-orbiting artificial satellites and other spacecraft, are classified as:

```text
0011 = IoT / Device
```

## 5.2 Natural celestial entities

Naturally occurring celestial entities, including:

* natural satellites;
* planets;
* stars;
* comets;
* asteroids; and
* meteoroids

are classified as:

```text
1000 = Natural / Celestial Object
```

---

# 6. Engine and Local Namespace

The Engine field occupies bits `29–49` and is 21 bits wide.

The Local field occupies bits `0–28` and is 29 bits wide.

The allocation namespace is:

```text
Engine + Local
```

Class does **not** partition the allocation namespace.

Two identifiers with different Class values but the same Engine and Local values represent the same allocation coordinate and MUST NOT both be treated as independently allocated SMART identities.

The combined Engine + Local namespace contains:

```text
2^50 = 1,125,899,906,842,624
```

possible coordinates.

## 6.1 Engine range

Engine is an unsigned 21-bit value:

```text
0 .. 2^21 - 1
0 .. 2,097,151
```

## 6.2 Local range

Local is an unsigned 29-bit value:

```text
0 .. 2^29 - 1
0 .. 536,870,911
```

Local value `0` is valid and MUST NOT be treated as a sentinel, null, or unassigned value.

---

# 7. Allocation and Non-Reuse

Each Engine has an authoritative allocation mechanism for Local IDs.

For every Engine, a Local ID that has once been successfully allocated MUST NEVER be successfully allocated again within that Engine.

This prohibition applies across:

* process restart;
* system restart;
* database restart;
* crash recovery;
* database restore;
* allocator replacement;
* failover;
* ownership transfer;
* network partition;
* delayed recovery; and
* equivalent failure conditions.

No two successful allocations for the same Engine may return the same Local ID.

Local IDs are persistent and MUST NOT be reused.

Local allocation MAY be monotonic.

Batch allocation MAY be used.

When the Local namespace is exhausted, allocation MUST fail rather than reuse a previously allocated Local ID.

If an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail.

A stale allocator MUST NOT be capable of successfully committing a new allocation after its authority has ended.

At most one authoritative active allocator may successfully allocate within a given Engine namespace at a time.

Ownership transfer between allocators MUST prevent the former allocator from successfully allocating after authority has transferred.

SMART does not prescribe the implementation mechanism used to provide these guarantees.

---

# 8. Routing Semantics

SMART routing is based on the Engine field.

A typical resolution path is:

```text
SMART ID
    │
    ├── extract Engine
    │
    ▼
Engine
    │
    ├── route to Engine namespace
    │
    ▼
extract Local
    │
    ▼
Local ID lookup
    │
    ▼
Entity
```

Engine is a logical routing and namespace identifier. It does not necessarily represent a physical server, machine, host, database instance, or geographic location.

Local is the lookup identifier within the Engine-local namespace.

Local alone is not globally unique.

Cross-Engine references MUST include sufficient information to identify the Engine together with the Local identifier, or use the complete SMART identifier.

---

# 9. Database Representation

A conforming implementation MAY use Engine-local database tables or equivalent namespaces in which Local is the primary key.

The full 64-bit SMART identifier MAY be stored as a public/current representation.

The full 64-bit identifier does not have to be the relational database primary key.

Changes to the representation/control layer MUST NOT require relocation or mutation of the persistent identity record when the Identity Core remains unchanged.

SMART does not prescribe:

* SQL or NoSQL;
* database vendor;
* replication model;
* partitioning technology;
* consensus mechanism;
* caching;
* CDC;
* authentication; or
* transport protocol.

---

# 10. Engine Switching and Migration

Changing the Engine of an identity creates a **new SMART identity**.

An Engine switch MUST NOT mutate the original SMART identity into another Engine.

The receiving Engine MUST allocate a new Local ID through its authoritative allocation mechanism.

The receiving Engine MUST NOT:

* preserve the source Local ID merely for convenience;
* copy the source Local ID;
* request the source Local ID as the new allocation; or
* manually assign a Local ID outside the authoritative allocation mechanism.

The new Local ID MUST satisfy all applicable allocation, uniqueness, non-reuse, and allocator-authority requirements.

Migration MUST NOT bypass normal allocation safety.

If the receiving Engine cannot safely allocate a new Local ID, the Engine switch MUST NOT create the new SMART identity.

The source identity remains unchanged.

An implementation MAY maintain an external association or lifecycle record linking the old identity to the new identity.

SMART does not require a particular migration protocol.

---

# 11. Engine Retirement

SMART does not require an Engine to remain available indefinitely.

An identifier whose Engine becomes unavailable, retired, transferred, or otherwise inaccessible remains an identifier.

Resolution behavior for unavailable Engines is outside the SMART identifier format.

SMART does not encode or infer a successor Engine.

An association between an old identity and a new identity cannot be inferred solely from the numerical relationship between their identifiers.

---

# 12. Version and Revision

Bit `63` is Version.

Bits `59–62` are Revision.

Together they select the applicable SMART profile.

For Version `0`:

| Version |             Revision | Profile     |
| ------: | -------------------: | ----------- |
|     `0` |               `0000` | SMART v1.4  |
|     `0` |               `0001` | SMART v1.41 |
|     `0` |               `0010` | Future v1.x |
|     `0` | other assigned value | Future v1.x |

Version `1` identifies the v2+ family.

A v1.x implementation encountering Version `1` MUST NOT interpret the identifier as a v1.x identifier. It MUST reject or delegate the identifier according to the implementation boundary.

An implementation encountering an unsupported Revision MUST NOT guess its meaning.

It MUST reject or delegate the identifier according to the implementation boundary.

Revision is a profile selector. It is not a literal textual representation of the release number.

The Version `0` family has 16 possible Revision values.

If the available Revision values are exhausted, incompatible future evolution requires a new Version family.

---

# 13. Legacy v1.4 Compatibility

SMART v1.4 and SMART v1.41 are distinct profiles.

A v1.4 implementation interprets bits `50–57` according to the v1.4 specification, where those bits represent the v1.4 Region field.

A v1.41 implementation MUST determine the applicable profile before interpreting profile-dependent fields.

A v1.41 implementation MUST NOT reinterpret the legacy v1.4 Region field as the v1.41 Class and Reserved fields.

A v1.4 implementation cannot assume that a Version `0` identifier with an unsupported Revision is valid v1.4.

A v1.4 implementation MUST validate the v1.4 Reserved-field requirements before accepting an identifier as conforming v1.4.

## 13.1 Legacy-only boundary

At a boundary configured to accept only legacy v1.4 identifiers:

A v1.41 identifier MUST NOT be accepted, silently discarded, stripped, mutated, downgraded, or passed downstream as though it were a valid v1.4 identifier.

The boundary MUST explicitly reject the incompatible identifier or operation and report the incompatibility to the calling or upstream system.

A boundary implementation MUST NOT convert a v1.41 identifier into a v1.4 identifier by:

* rewriting;
* truncating;
* masking; or
* otherwise modifying its bits.

SMART does not prescribe:

* transport protocol;
* error code;
* logging behavior; or
* retry behavior.

The required property is deterministic rejection rather than silent reinterpretation.

---

# 14. Reserved Bits

Bits `54–57` are Reserved in v1.41.

At generation, all four Reserved bits MUST be:

```text
0000
```

A v1.41 identifier containing any nonzero Reserved bit is non-conforming.

A v1.41 implementation MUST NOT accept such an identifier as a valid v1.41 identifier.

Reserved bits MUST NOT be used for:

* private application data;
* hidden flags;
* implementation-specific state; or
* undocumented extensions.

Future specifications MAY assign currently reserved values.

---

# 15. Binary Serialization

A SMART v1.41 identifier is an unsigned 64-bit integer.

The canonical binary wire representation MUST use:

```text
unsigned 64-bit
big-endian
network byte order
```

Bit `0` is the least-significant bit.

Bit `63` is the most-significant bit.

Textual representations MAY be defined by applications or future specifications, provided that they preserve the same underlying unsigned 64-bit value.

An implementation MUST NOT use signed integer interpretation in a way that changes the identifier's numerical value or causes incorrect field extraction.

Implementations using signed host-language types MUST provide equivalent unsigned 64-bit semantics.

---

# 16. Field Extraction

For an unsigned 64-bit identifier `ID`, the v1.41 fields are extracted as follows:

```text
Local    = ID & 0x1FFFFFFF
Engine   = (ID >> 29) & 0x1FFFFF
Class    = (ID >> 50) & 0x0F
Reserved = (ID >> 54) & 0x0F
Role     = (ID >> 58) & 0x01
Revision = (ID >> 59) & 0x0F
Version  = (ID >> 63) & 0x01
```

Logical right-shift semantics MUST be used.

The extraction operations MUST correspond exactly to the bit positions defined in Section 2.

---

# 17. Representation and Identity Stability

For a given allocated identity:

* Identity Core MUST remain stable.
* Role MUST remain stable.
* Class MUST remain stable.
* Engine and Local together identify the allocation coordinate.

Changes to the representation/control layer MUST NOT silently create a different interpretation of the Identity Core.

If an operation changes Engine, it creates a new SMART identity rather than mutating the existing identity.

If an operation changes Class or Role, the existing identity MUST NOT simply be rewritten to represent the new semantic designation.

External lifecycle/history mechanisms MAY record relationships between identities.

---

# 18. Conformance

A conforming SMART v1.41 implementation MUST:

1. implement the specified bit positions;
2. preserve the 54-bit Identity Core for an allocated identity;
3. preserve Role for an allocated identity;
4. enforce Engine + Local uniqueness;
5. guarantee Local non-reuse within an Engine;
6. generate Reserved bits `54–57` as zero;
7. reject v1.41 identifiers with nonzero Reserved bits;
8. reject Class `0000`;
9. treat Local `0` as a valid Local ID;
10. correctly interpret Version and Revision;
11. never guess the meaning of an unsupported profile;
12. support canonical unsigned 64-bit big-endian binary interoperability;
13. distinguish legacy v1.4 from v1.41;
14. explicitly reject incompatible identifiers at a legacy-only boundary;
15. require receiving Engines to use authoritative allocation during Engine migration; and
16. preserve the defined routing semantics.

An implementation that cannot satisfy an applicable safety, uniqueness, non-reuse, validation, or interoperability requirement MUST NOT claim conformance to SMART v1.41.

---

# 19. Non-Conforming Conditions

The following conditions are non-conforming for v1.41:

* Class `0000` appearing in an allocated identifier;
* nonzero Reserved bits;
* reuse of a previously allocated Local ID within the same Engine;
* two successful allocations returning the same Engine + Local coordinate;
* stale allocator successfully allocating after authority has ended;
* changing Identity Core of an allocated identity;
* changing Role by rewriting an existing representation;
* manually assigning a receiving Engine's Local ID outside its authoritative allocator;
* silently interpreting an unsupported Revision;
* interpreting Version `1` as a v1.x identifier;
* treating a v1.41 identifier as a valid v1.4 identifier;
* rewriting or truncating v1.41 bits to make them appear to be v1.4; or
* using non-canonical binary byte order where canonical SMART binary interoperability is required.

---

# 20. Implementation Boundary

SMART defines identifier semantics, not an implementation's complete operational environment.

An implementation MAY provide:

* database storage;
* distributed allocation;
* replication;
* caching;
* APIs;
* message queues;
* authentication;
* authorization;
* monitoring;
* auditing;
* migration tooling; and
* lifecycle management.

Those systems MUST preserve the normative requirements of this specification where they operate on SMART identifiers.

A proxy, gateway, database, service, or application that bypasses required SMART validation is non-conforming for that operation.

---

# 21. Summary

SMART v1.41 provides a 64-bit identifier with:

```text
29 bits  Local
21 bits  Engine
 4 bits  Class
 4 bits  Reserved
 1 bit   Role
 4 bits  Revision
 1 bit   Version
----------------
64 bits total
```

The persistent Identity Core is:

```text
Class + Engine + Local = 54 bits
```

The upper 10 bits provide the current representation and control layer, with Role remaining a semantically immutable identity attribute.

The allocation namespace is:

```text
Engine + Local
```

and Local IDs MUST NOT be reused within an Engine.

v1.41 is explicitly separated from legacy v1.4 through Version/Revision profile handling.

Canonical binary serialization is unsigned 64-bit big-endian network byte order.

Unknown profiles MUST NOT be guessed.

Reserved bits MUST remain zero.

Engine migration creates a new identity through authoritative allocation.

These requirements collectively define the SMART 64-Bit ID v1.41 profile.
