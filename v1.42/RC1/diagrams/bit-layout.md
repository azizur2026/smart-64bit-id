# SMART 64-Bit ID v1.42 — Bit Layout

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Diagrammatic reference for the v1.42 64-bit layout

## 1. Purpose

This file presents the v1.42 bit layout in diagrammatic form. It is a reference aid for the normative content of SPECIFICATION.md §2 and §16. Where this file and the specification differ, the specification governs.

The bit layout is reproduced here for convenience. It does not introduce requirements. The normative requirements for each field are stated in the specification sections cross-referenced below.

## 2. Full 64-bit layout

Bits are numbered from bit 0 (least-significant) through bit 63 (most-significant).

```text
 63      62 61 60 59      58      57 56 55 54      53 52 51 50      49 ........ 29      28 ........ 0
┌─────────┬──────────────┬────────┬────────────────┬────────────────┬─────────────────────┬───────────────────┐
│ Version │   Revision   │  Role  │    Reserved    │     Class      │       Engine        │       Local       │
│  1 bit  │    4 bits    │ 1 bit  │     4 bits     │     4 bits     │      21 bits        │      29 bits      │
└─────────┴──────────────┴────────┴────────────────┴────────────────┴─────────────────────┴───────────────────┘
   MSB                                                                                                   LSB
```

## 3. Field allocation table

| Bits | Width | Field | v1.42 requirement | Spec ref |
|---|---|---|---|---|
| 0–28 | 29 | Local | Allocation-local identifier. 0 is valid. | §6.2 |
| 29–49 | 21 | Engine | Engine / namespace identifier. Each Engine is bound to exactly one Class. | §6, §6.3 |
| 50–53 | 4 | Class | Encoded taxonomy value. 0001–1000 assigned; 0000 invalid; 1001–1111 reserved. | §2.2, §5 |
| 54–57 | 4 | Reserved | MUST be 0000 in v1.42. Bit 54 is not part of Class. | §14 |
| 58 | 1 | Role | 0 = dependent; 1 = self-representing. Immutable per allocated identifier. | §4 |
| 59–62 | 4 | Revision | 0010 for v1.42. | §12 |
| 63 | 1 | Version | 0 for v1.42. | §12 |

## 4. Field-by-field diagram notes

### 4.1 Version (bit 63)

Single bit. Selects the specification-family generation. 0 covers the Version 0 family, which includes v1.4, v1.41, and v1.42, distinguished by Revision.

### 4.2 Revision (bits 59–62)

Four bits. Selects the profile within the Version 0 family. 0000 = v1.4, 0001 = v1.41, 0010 = v1.42. Revision is a profile selector, not a literal textual release number.

Version and Revision together MUST be read before any profile-dependent field is interpreted (§13.2). The identifier is self-identifying: the profile is determined before the field mask is applied.

### 4.3 Role (bit 58)

Single bit. Encodes the designation: 0 = dependent, 1 = self-representing. Immutable for the allocated identifier. A change of designation is expressed by retirement and reallocation, not by rewriting the identifier (§4.1).

Role is not a routing attribute. Routing uses Class + Engine (§8). Role is consumed by the application domain layer; it is not read by the routing or allocation layers.

### 4.4 Reserved (bits 54–57)

Four bits. MUST be 0000 in v1.42. Must not be used for private application data, hidden flags, implementation-specific state, or undocumented extensions.

Bit 54 is Reserved in v1.42. It is not part of the Class field. A 5-bit Class expansion that would reallocate bit 54 is deferred and is not part of v1.42 (§14.1).

### 4.5 Class (bits 50–53)

Four bits. Carries the encoded taxonomy value. Assigned values 0001–1000; 0000 invalid; 1001–1111 reserved.

Structurally continuous with v1.41's Class-marker field at the same bit positions, semantically different: v1.41 requires 0000 as a marker; v1.42 requires an assigned nonzero value.

The encoded Class MUST agree with the authoritative Class-property record (§5.3). Disagreement is S64-E007 CLASS_MISMATCH.

### 4.6 Engine (bits 29–49)

21 bits. Engine / namespace identifier. Range 0 .. 2²¹ − 1 (§6.1).

Each Engine is bound to exactly one Class. Multiple Engines MAY be bound to the same Class, but an Engine MUST NOT be bound to more than one Class. Given the Engine, the Class is determined. Reclassification of an Engine is not permitted; a Class change requires a new Engine (§6.3).

Engine exhaustion advances the Engine ID within the same Class, while Class remains fixed for that Class across rollover (§6.4). When no further Engine ID is available within the Class, allocation fails terminally (§6.5).

### 4.7 Local (bits 0–28)

29 bits. Allocation-local identifier. Range 0 .. 2²⁹ − 1 (§6.2).

Local value 0 is valid and is not a sentinel, null, or unassigned value.

Local IDs are not reused within an Engine, including across retirement (§7, §10.2).

## 5. Identity Core

The structural Identity Core is the concatenation of Class, Engine, and Local:

```text
 Class │       Engine        │        Local
 4 bits│      21 bits        │      29 bits
───────┼─────────────────────┼────────────────────
       └──── 54 bits total ─────────────────────┘
```

In v1.42, the Class field carries the encoded taxonomy value. In v1.41, the corresponding field is a zero marker. The structural composition is preserved across the two profiles; the semantic difference is stated explicitly (§3).

The Identity Core defines the persistent identifier representation. Once allocated, it MUST NOT be changed (§3, §17).

## 6. Engine + Local allocation coordinate

The allocation namespace is Engine + Local:

```text
       Engine (21)        │        Local (29)
──────────────────────────┼──────────────────────────
           └──────────── 50 bits total ───────────┘
```

Total coordinates: 2⁵⁰ = 1,125,899,906,842,624.

Class does not partition the allocation namespace. Uniqueness coordinate is Engine + Local (§6).

## 7. Virtual-engine composition

A virtual-engine ID is the concatenation of Class and Engine:

```text
     Class (4)     │       Engine (21)
───────────────────┼────────────────────────
      └────────── 25 bits total ───────────┘
```

The virtual-engine ID is not a hash and is not a surrogate. Each virtual-engine ID is a row in a virtual-engine table, mapping to a physical engine address (§8).

Routing uses Class + Engine → virtual engine → physical engine address. This differs from v1.41 routing, which uses Engine alone.

## 8. Profile comparison: v1.41 and v1.42

The two profiles are structurally aligned in the Identity Core and structurally differ in the meaning of the field at bits 50–53.

| Bits | v1.41 field | v1.41 rule | v1.42 field | v1.42 rule |
|---|---|---|---|---|
| 0–28 | Local | 0 valid | Local | 0 valid |
| 29–49 | Engine | Namespace / routing identifier | Engine | Namespace / routing identifier; each Engine bound to exactly one Class |
| 50–53 | Class marker | MUST be 0000; not the effective Class | Class | Encoded taxonomy value; 0000 invalid; 1001–1111 reserved |
| 54–57 | Reserved | MUST be 0000 | Reserved | MUST be 0000 |
| 58 | Role | Immutable | Role | Immutable per identifier |
| 59–62 | Revision | 0001 | Revision | 0010 |
| 63 | Version | 0 | Version | 0 |

Consequence: under normal validation, a cross-profile identifier is rejected at profile identification. Independently, if force-read under the other profile's field rules, a v1.42 identifier has nonzero Class-marker bits and a v1.41 identifier has encoded Class 0000. Mutual invalidity is intentional (§13.1). Profile MUST be identified from Version and Revision before the field at bits 50–53 is interpreted (§13.2).

## 9. Deferred expansion (informative)

A 5-bit Class expansion — reallocating bit 54 from Reserved to Class, so that Class occupies bits 50–54 and Reserved occupies bits 55–57 — is a future option. It is explicitly not part of v1.42.

In v1.42, bit 54 remains Reserved and MUST be zero. Implementations MUST NOT interpret bit 54 as part of the Class field in a v1.42 identifier (§14.1).

## 10. Canonical serialization

A v1.42 identifier is an unsigned 64-bit integer. Canonical binary wire representation is unsigned 64-bit, big-endian, network byte order. Bit 0 is the least-significant bit; bit 63 is the most-significant bit (§15).

Field extraction for an unsigned 64-bit identifier ID:

```text
Local    = ID & 0x1FFFFFFF
Engine   = (ID >> 29) & 0x1FFFFF
Class    = (ID >> 50) & 0x0F
Reserved = (ID >> 54) & 0x0F
Role     = (ID >> 58) & 0x01
Revision = (ID >> 59) & 0x0F
Version  = (ID >> 63) & 0x01
```

Logical right-shift semantics MUST be used (§16).

## 11. Summary

The v1.42 layout assigns all 64 bits as follows:

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

The 54-bit Identity Core is Class + Engine + Local. Class carries the encoded taxonomy value in v1.42, unlike the v1.41 zero marker. Each Engine is bound to exactly one Class; multiple Engines may share a Class. A virtual-engine ID is Class + Engine, 25 bits, used as the routing key. A retired Engine + Local coordinate is permanently consumed and is not reissued.
