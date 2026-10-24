# SMART 64-Bit ID v1.41

**Status:** Proposed corrected specification
**Specification family:** SMART 64-Bit ID
**Profile:** Version `0`, Revision `0001`
**Supersedes:** No — v1.4 remains a separate legacy profile
**Document purpose:** Normative technical specification for SMART 64-Bit ID v1.41

---

## 1. Scope

SMART 64-Bit ID v1.41 defines a 64-bit identifier format for persistent identification of entities and associated or dependent identities.

This specification defines:

- the 64-bit binary layout;
- identity-core semantics;
- Class-marker and effective-Class semantics;
- Role semantics;
- Version and Revision profile selection;
- reserved-bit requirements;
- Engine and Local ID allocation semantics;
- routing semantics;
- Engine migration behavior;
- compatibility boundaries with legacy v1.4;
- canonical binary serialization;
- decoding and validation requirements; and
- implementation conformance requirements.

SMART defines identifier structure and required identifier behavior. It does not prescribe a particular database vendor, storage engine, network protocol, replication system, consensus mechanism, cache, authentication system, or operational architecture.

The effective Class property described in this specification is distinct from the four-bit Class-marker field physically encoded in a v1.41 identifier.

---

## 2. 64-Bit Layout

A v1.41 identifier is an unsigned 64-bit value.

Bits are numbered from bit `0`, the least-significant bit (LSB), through bit `63`, the most-significant bit (MSB).

```text
63        62 61 60 59        58        57 56 55 54        53 52 51 50        49 ........ 29        28 ........ 0
┌──────────┬───────────────┬──────────┬──────────────────┬──────────────────┬─────────────────────────┬─────────────────────┐
│ Version  │    Revision   │   Role   │     Reserved     │   Class marker   │         Engine          │        Local        │
│  1 bit   │    4 bits     │  1 bit   │     4 bits       │     4 bits       │       21 bits           │      29 bits        │
└──────────┴───────────────┴──────────┴──────────────────┴──────────────────┴─────────────────────────┴─────────────────────┘
```

### 2.1 Field allocation

| Bits | Width | Field | Requirement |
|---|---:|---|---|
| 0–28 | 29 | Local | Allocation-local identifier |
| 29–49 | 21 | Engine | Engine / namespace identifier |
| 50–53 | 4 | Class marker | MUST be `0000` in v1.41 |
| 54–57 | 4 | Reserved | MUST be `0000` in v1.41 |
| 58 | 1 | Role | Self-representing / dependent designation |
| 59–62 | 4 | Revision | Profile selector |
| 63 | 1 | Version | Specification-family selector |

### 2.2 Meaning of the Class marker

For v1.41, bits `50–53` MUST always contain `0000`.

This value is a representation marker. It is not an effective entity Class and MUST NOT be interpreted as one.

The effective Class MUST be obtained from the authoritative Class-property record associated with the allocated identity's Engine + Local coordinate.

The marker rule is profile-specific. Implementations MUST identify the profile from Version and Revision before interpreting profile-dependent fields.

The v1.41 marker rule MUST NOT be applied to the legacy v1.4 profile, whose bits `50–57` retain their v1.4 Region-field meaning.

---

## 3. Identity Core

The 54-bit Identity Core is structurally composed of the four-bit Class-marker field, the 21-bit Engine field, and the 29-bit Local field.

```text
Class marker + Engine + Local
      4      +   21   +  29
             = 54 bits
```

For v1.41, the Class-marker bits MUST be `0000`. They do not encode the effective Class.

The effective Class is maintained separately in an authoritative Class-property record associated with the identity's Engine + Local allocation coordinate.

The Identity Core defines the persistent identifier representation for the allocated identity. Once an identity is allocated, its Identity Core MUST NOT be changed.

The effective Class-property record MUST be associated unambiguously with the allocated identity. Its effective Class value MUST remain stable for the lifetime of that identity.

Implementations MUST NOT infer the effective Class from the zero-valued Class marker.

The upper 10 bits form the representation and control area. These fields do not all have identical mutability semantics. In particular, Role is an immutable semantic attribute of the allocated identity even though it is located within this area.

The governing distinction is:

> The 54-bit Identity Core defines the persistent identity representation. In v1.41, the Class-marker bits are always zero, and the effective Class is resolved through the authoritative Class-property record. The upper 10 bits define the representation and control area, with Role remaining an immutable identity attribute.

---

## 4. Role

Bit `58` is the Role field.

| Value | Meaning |
|---|---|
| `0` | Dependent |
| `1` | Self-representing |

Role indicates whether the identified entity is designated as a self-representing identity or as an associated or dependent identity within the applicable identification relationship.

SMART does not define the legal, organizational, technical, or governance criteria used to determine this designation.

Role MUST NOT be interpreted as a statement of:

- legal capacity;
- legal agency;
- ownership;
- authority;
- autonomy;
- human status; or
- organizational status.

Every valid representation of a given allocated identity MUST carry the same Role value.

A representation containing a conflicting Role value is non-conforming.

Any operation that creates, migrates, or changes a representation MUST preserve Role.

If the applicable designation changes, the existing identifier MUST NOT be rewritten solely to change Role. Lifecycle history or a new identity MAY be used according to the applicable system's requirements.

Examples:

- Human identity: `Role = 1`
- Android phone: `Role = 0`
- SIM: `Role = 0`
- Coffee-maker IoT device: `Role = 0`

These examples illustrate possible designations; they do not establish a universal legal or organizational classification rule.

---

## 5. Class

### 5.1 Class-marker encoding

Bits `50–53` form the Class-marker field in v1.41.

A conforming v1.41 identifier MUST contain:

```text
Class marker = 0000
```

The marker is not an effective Class value. A conforming implementation MUST NOT use it to determine whether the entity is Human, a Device, an AI, an Organization, or another entity category.

The effective Class MUST be obtained from the authoritative Class-property record associated with the identity's Engine + Local coordinate.

### 5.2 Effective Class values

The following table defines effective Class values for the authoritative Class-property record.

| Binary value | Effective Class |
|---|---|
| `0000` | Invalid / Unassigned |
| `0001` | Human |
| `0010` | Other Living Being |
| `0011` | IoT / Device |
| `0100` | AI |
| `0101` | Organization |
| `0110` | Artifact / Object |
| `0111` | Android / Humanoid Artificial Entity |
| `1000` | Natural / Celestial Object |
| `1001–1111` | Reserved for future assignment |

The value `0000` MUST NOT be assigned as an effective Class.

Every allocated v1.41 identity MUST have an authoritative Class-property record containing a valid effective Class.

The record MUST be associated unambiguously with the identity's Engine + Local coordinate. An implementation MUST NOT guess an effective Class if the record is missing, ambiguous, invalid, or incorrectly associated.

A missing or invalid record MUST be treated as an unresolved or invalid Class-property state. It MUST NOT be treated as successful Class resolution.

Effective Class values `1001–1111` are reserved unless a later specification explicitly assigns them.

### 5.3 Class-property stability

The effective Class property MUST remain stable after allocation.

Reclassification MUST NOT silently change the effective Class of an existing allocated identity. Applicable systems MAY record a reclassification in lifecycle history or allocate a new identity where required by their governing rules.

SMART specifies the v1.41 marker encoding and the permanence requirements for the effective Class property. SMART does not define a universal external ontology or classification authority.

### 5.4 Artificial spacecraft

Artificial or manufactured spacecraft, including Earth-orbiting artificial satellites and other spacecraft, use the effective Class:

```text
0011 = IoT / Device
```

This value belongs in the authoritative Class-property record. It MUST NOT be written into the v1.41 Class-marker bits.

### 5.5 Natural celestial entities

Naturally occurring celestial entities, including natural satellites, planets, stars, comets, asteroids, and meteoroids, use the effective Class:

```text
1000 = Natural / Celestial Object
```

This value belongs in the authoritative Class-property record. It MUST NOT be written into the v1.41 Class-marker bits.

---

## 6. Engine and Local Namespace

The Engine field occupies bits `29–49` and is 21 bits wide.

The Local field occupies bits `0–28` and is 29 bits wide.

The allocation namespace is:

```text
Engine + Local
```

Effective Class does not partition the allocation namespace.

Two records with different effective Class values but identical Engine and Local values MUST NOT be treated as independently allocated SMART identities. They refer to the same allocation coordinate.

The effective Class property MUST therefore be associated with the single identity allocated at that coordinate.

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

Local value `0` is valid and MUST NOT be treated as a sentinel, null, or unassigned value.

---

## 7. Allocation and Non-Reuse

Each Engine MUST have an authoritative allocation mechanism for Local IDs.

For every Engine, a Local ID that has once been successfully allocated MUST NEVER be successfully allocated again within that Engine.

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

When the Local namespace is exhausted, allocation MUST fail rather than reuse a previously allocated Local ID.

If an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail.

A stale allocator MUST NOT be capable of successfully committing a new allocation after its authority has ended.

At most one authoritative active allocator may successfully allocate within a given Engine namespace at a time.

Ownership transfer between allocators MUST prevent the former allocator from successfully allocating after authority has transferred.

SMART does not prescribe the implementation mechanism used to provide these guarantees.

---

## 8. Routing Semantics

SMART routing is based on the Engine field.

A typical resolution path is:

```text
SMART ID
    |
    v
Extract Engine
    |
    v
Route to Engine namespace
    |
    v
Extract Local
    |
    v
Look up Local ID
    |
    v
Resolve identity and effective Class property
```

Engine is a logical routing and namespace identifier. It does not necessarily represent a physical server, machine, host, database instance, or geographic location.

Local is the lookup identifier within the Engine-local namespace.

Local alone is not globally unique.

Cross-Engine references MUST include sufficient information to identify Engine together with Local, or use the complete SMART identifier.

A resolver that needs the effective Class MUST resolve the authoritative Class-property record associated with the identity. It MUST NOT infer the effective Class from the v1.41 Class-marker bits.

---

## 9. Database Representation

A conforming implementation MAY use Engine-local database tables or equivalent namespaces in which Local is the primary key.

The full 64-bit SMART identifier MAY be stored as a public or current representation.

The full 64-bit identifier does not have to be the relational database primary key.

Changes to the representation or control area MUST NOT require relocation or mutation of the persistent identity record when the Identity Core remains unchanged.

### 9.1 Effective Class storage

For v1.41, a conforming implementation MUST maintain an authoritative Class-property record for every allocated identity.

The implementation MUST be able to associate that record unambiguously with the identity's Engine + Local coordinate.

The record MAY be stored in the identity's primary record, in a separate table, or in an equivalent authoritative data store.

The storage arrangement is implementation-defined, but the association and effective Class value MUST satisfy this specification's uniqueness, validity, and stability requirements.

The v1.41 zero-valued Class marker MUST NOT be used as a substitute for the authoritative Class-property record.

A cached or replicated copy MAY be used operationally, provided that it does not introduce conflicting effective Class values or undermine the authoritative association.

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

These implementation choices MUST preserve the normative requirements of this specification.

---

## 10. Engine Switching and Migration

Changing the Engine of an identity creates a **new SMART identity**.

An Engine switch MUST NOT mutate the original SMART identity into another Engine.

The receiving Engine MUST allocate a new Local ID through its authoritative allocation mechanism.

The receiving Engine MUST NOT:

- preserve the source Local ID merely for convenience;
- copy the source Local ID;
- request the source Local ID as the new allocation; or
- manually assign a Local ID outside the authoritative allocation mechanism.

The new Local ID MUST satisfy all applicable allocation, uniqueness, non-reuse, and allocator-authority requirements.

Migration MUST NOT bypass normal allocation safety.

If the receiving Engine cannot safely allocate a new Local ID, the Engine switch MUST NOT create the new SMART identity.

The source identity remains unchanged.

An implementation MAY maintain an external association or lifecycle record linking the old identity to the new identity.

The effective Class associated with an identity MUST NOT be silently changed merely because an Engine migration occurs. The new identity MUST have an authoritative Class-property record consistent with the applicable allocation and lifecycle rules.

SMART does not require a particular migration protocol.

---

## 11. Engine Retirement

SMART does not require an Engine to remain available indefinitely.

An identifier whose Engine becomes unavailable, retired, transferred, or otherwise inaccessible remains an identifier.

Resolution behavior for unavailable Engines is outside the SMART identifier format.

SMART does not encode or infer a successor Engine.

An association between an old identity and a new identity cannot be inferred solely from the numerical relationship between their identifiers.

---

## 12. Version and Revision

Bit `63` is Version.

Bits `59–62` are Revision.

Together they select the applicable SMART profile.

For Version `0`:

| Version | Revision | Profile |
|---:|---:|---|
| `0` | `0000` | SMART v1.4 |
| `0` | `0001` | SMART v1.41 |
| `0` | `0010` | Future v1.x |
| `0` | Other assigned value | Future v1.x |

Version `1` identifies the v2+ family.

A v1.x implementation encountering Version `1` MUST NOT interpret the identifier as a v1.x identifier. It MUST reject or delegate the identifier according to the implementation boundary.

An implementation encountering an unsupported Revision MUST NOT guess its meaning.

It MUST reject or delegate the identifier according to the implementation boundary.

Revision is a profile selector. It is not a literal textual representation of the release number.

The Version `0` family has 16 possible Revision values.

If the available Revision values are exhausted, incompatible future evolution requires a new Version family.

---

## 13. Legacy v1.4 Compatibility

SMART v1.4 and SMART v1.41 are distinct profiles.

A v1.4 implementation interprets bits `50–57` according to the v1.4 specification, where those bits represent the legacy v1.4 Region field.

A v1.41 implementation MUST determine the applicable profile before interpreting profile-dependent fields.

A v1.41 implementation MUST NOT reinterpret the legacy v1.4 Region field as the v1.41 Class-marker and Reserved fields.

A v1.4 implementation cannot assume that a Version `0` identifier with an unsupported Revision is valid v1.4.

A v1.4 implementation MUST validate the v1.4 Reserved-field requirements before accepting an identifier as conforming v1.4.

### 13.1 Profile-specific Class handling

The v1.41 rule requiring bits `50–53` to be `0000` applies only after an identifier has been identified as v1.41.

In v1.41, those bits are a Class marker, and the effective Class MUST be resolved through the authoritative Class-property record.

In v1.4, bits `50–57` retain their legacy Region-field interpretation. Implementations MUST NOT reinterpret the v1.4 Region field as an effective Class or as the v1.41 Class marker.

Implementations MUST NOT infer the applicable interpretation solely from bits `50–53`. Version and Revision MUST be checked first.

The v1.41 zero-marker rule MUST NOT automatically carry forward to v1.42 or later profiles. Future profiles MUST be validated according to their own specifications. Under the intended v1.42-and-later encoding rule, the encoded Class MUST be a valid assigned value other than `0000`.

### 13.2 Legacy-only boundary

At a boundary configured to accept only legacy v1.4 identifiers, a v1.41 identifier MUST NOT be accepted, silently discarded, stripped, mutated, downgraded, or passed downstream as though it were a valid v1.4 identifier.

The boundary MUST explicitly reject the incompatible identifier or operation and report the incompatibility to the calling or upstream system.

A boundary implementation MUST NOT convert a v1.41 identifier into a v1.4 identifier by:

- rewriting;
- truncating;
- masking; or
- otherwise modifying its bits.

SMART does not prescribe:

- transport protocol;
- error code;
- logging behavior; or
- retry behavior.

The required property is deterministic rejection rather than silent reinterpretation.

---

## 14. Reserved Bits

Bits `54–57` are Reserved in v1.41.

At generation, all four Reserved bits MUST be:

```text
0000
```

A v1.41 identifier containing any nonzero Reserved bit is non-conforming.

A v1.41 implementation MUST NOT accept such an identifier as a valid v1.41 identifier.

Reserved bits MUST NOT be used for:

- private application data;
- hidden flags;
- implementation-specific state; or
- undocumented extensions.

Future specifications MAY assign currently reserved values under their own profile definitions. Such future assignments do not change the requirements for v1.41 identifiers.

The Class-marker field at bits `50–53` and the Reserved field at bits `54–57` are separate fields and MUST be validated independently.

---

## 15. Binary Serialization

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

Serialization and deserialization MUST preserve all 64 bits exactly. An implementation MUST NOT rewrite the Class-marker field, Reserved field, Role, Version, or Revision merely to make an identifier acceptable to another profile.

---

## 16. Field Extraction

For an unsigned 64-bit identifier `ID`, the v1.41 fields are extracted as follows:

```text
Local       = ID & 0x1FFFFFFF
Engine      = (ID >> 29) & 0x1FFFFF
ClassMarker = (ID >> 50) & 0x0F
Reserved    = (ID >> 54) & 0x0F
Role        = (ID >> 58) & 0x01
Revision    = (ID >> 59) & 0x0F
Version     = (ID >> 63) & 0x01
```

Logical right-shift semantics MUST be used.

The extraction operations MUST correspond exactly to the bit positions defined in Section 2.

### 16.1 Validation order

An implementation MUST identify Version and Revision before applying profile-specific validation.

For a v1.41 identifier:

1. `Version` MUST equal `0`.
2. `Revision` MUST equal `0001`.
3. `ClassMarker` MUST equal `0000`.
4. `Reserved` MUST equal `0000`.
5. The Engine + Local coordinate MUST satisfy the allocation and identity-resolution requirements.
6. The authoritative Class-property record MUST resolve to a valid effective Class.
7. Role and all other applicable requirements MUST be validated.

The extracted `ClassMarker` is not the effective Class. Implementations MUST NOT substitute `ClassMarker` for the effective Class property.

Unsupported profiles MUST be rejected or delegated according to the implementation boundary. Their field meanings MUST NOT be guessed.

---

## 17. Representation and Identity Stability

For a given allocated v1.41 identity:

- the Identity Core MUST remain stable;
- the Class-marker bits MUST remain `0000`;
- the effective Class-property value and its association with the identity MUST remain stable;
- Role MUST remain stable; and
- Engine and Local together identify the allocation coordinate.

Changes to the representation or control area MUST NOT silently create a different interpretation of the Identity Core.

If an operation changes Engine, it creates a new SMART identity rather than mutating the existing identity.

If an operation changes Class or Role, the existing identity MUST NOT simply be rewritten to represent the new semantic designation.

An implementation MUST NOT change the effective Class property of an existing allocated identity without following an applicable lifecycle or identity-replacement process.

External lifecycle or history mechanisms MAY record relationships between identities.

The v1.41 zero marker is a required representation value, not a substitute for identity lifecycle history or effective Class metadata.

---

## 18. Conformance

A conforming SMART v1.41 implementation MUST:

1. implement the specified bit positions;
2. preserve the 54-bit Identity Core for an allocated identity;
3. generate Class-marker bits `50–53` as `0000`;
4. preserve the effective Class-property value and its association with the allocated identity;
5. maintain an authoritative Class-property record for every allocated identity;
6. reject an effective Class property of `0000`;
7. reject missing, ambiguous, invalid, or incorrectly associated Class-property records as successful Class resolution;
8. preserve Role for an allocated identity;
9. enforce Engine + Local uniqueness;
10. guarantee Local non-reuse within an Engine;
11. generate Reserved bits `54–57` as zero;
12. reject v1.41 identifiers with nonzero Reserved bits;
13. treat Local `0` as a valid Local ID;
14. correctly interpret Version and Revision;
15. never guess the meaning of an unsupported profile;
16. support canonical unsigned 64-bit big-endian binary interoperability;
17. distinguish legacy v1.4 from v1.41;
18. explicitly reject incompatible identifiers at a legacy-only boundary;
19. require receiving Engines to use authoritative allocation during Engine migration; and
20. preserve the defined routing semantics.

An implementation that cannot satisfy an applicable safety, uniqueness, non-reuse, validation, Class-property, or interoperability requirement MUST NOT claim conformance to SMART v1.41.

---

## 19. Non-Conforming Conditions

The following conditions are non-conforming for v1.41:

- nonzero Class-marker bits in a v1.41 identifier;
- an effective Class property of `0000`;
- a missing, ambiguous, invalid, or incorrectly associated authoritative Class-property record;
- nonzero Reserved bits;
- reuse of a previously allocated Local ID within the same Engine;
- two successful allocations returning the same Engine + Local coordinate;
- a stale allocator successfully allocating after its authority has ended;
- changing the Identity Core of an allocated identity;
- changing Role by rewriting an existing representation;
- changing the effective Class of an existing identity without following the applicable lifecycle or identity-replacement process;
- manually assigning a receiving Engine's Local ID outside its authoritative allocator;
- silently interpreting an unsupported Revision;
- interpreting Version `1` as a v1.x identifier;
- treating a v1.41 identifier as a valid v1.4 identifier;
- rewriting or truncating v1.41 bits to make them appear to be v1.4; or
- using non-canonical binary byte order where canonical SMART binary interoperability is required.

The required zero value in the v1.41 Class-marker field MUST NOT be confused with the invalid zero value for an effective Class property.

---

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

An implementation MAY choose how to store and retrieve authoritative Class-property records, but that choice MUST preserve the unambiguous association, validity, and stability requirements defined here.

---

## 21. Summary

SMART v1.41 provides a 64-bit identifier with the following fields:

```text
29 bits  Local
21 bits  Engine
 4 bits  Class marker
 4 bits  Reserved
 1 bit   Role
 4 bits  Revision
 1 bit   Version
----------------
64 bits total
```

The 54-bit Identity Core is structurally:

```text
Class marker + Engine + Local = 54 bits
```

In v1.41, the Class-marker bits MUST be `0000`. The effective Class is maintained in an authoritative Class-property record associated unambiguously with Engine + Local.

The zero-valued marker does not represent an effective Class. An effective Class of `0000` remains invalid.

The v1.4 Region-field interpretation remains unchanged. Implementations MUST select the profile before interpreting the relevant bits.

The v1.41 zero-marker rule MUST NOT automatically carry forward to v1.42 or later profiles. Future profiles MUST be validated according to their own specifications, including the intended requirement that an encoded Class be valid and nonzero.

The allocation namespace is:

```text
Engine + Local
```

Local IDs MUST NOT be reused within an Engine, and two successful allocations MUST NOT share the same Engine + Local coordinate.

Canonical binary serialization is unsigned 64-bit big-endian network byte order.

Unknown profiles MUST NOT be guessed.

Reserved bits MUST remain zero in v1.41.

Engine migration creates a new identity through authoritative allocation.

These requirements collectively define the SMART 64-Bit ID v1.41 profile.
