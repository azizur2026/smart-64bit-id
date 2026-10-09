# SMART 64-Bit ID — Bit Layout

**Technical Specification v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Overview

SMART 64-Bit ID is a fixed-width 64-bit identifier.

The identifier is divided into an immutable identity core and governance/metadata fields.

```text
MSB                                                               LSB
63                                                                  0
┌───────┬────────────┬──────────┬───────┬──────────────────────┬─────────────┐
│Version│  Reserved  │  State   │Region │       Engine         │  Local ID   │
│ 1 bit │   4 bits   │  1 bit   │8 bits │       21 bits        │   29 bits   │
└───────┴────────────┴──────────┴───────┴──────────────────────┴─────────────┘
   63      62..59        58       57..50       49..29              28..0
```

---

## 2. Field Definition

| Bits  |   Width | Field    | Role                           | Mutability |
| ----- | ------: | -------- | ------------------------------ | ---------- |
| 0–28  | 29 bits | Local ID | Per-Engine identity component  | Immutable  |
| 29–49 | 21 bits | Engine   | Routing and identity component | Immutable  |
| 50–57 |  8 bits | Region   | Generation-time metadata       | Metadata   |
| 58    |   1 bit | State    | Lifecycle marker               | Lifecycle  |
| 59–62 |  4 bits | Reserved | Future governance              | Reserved   |
| 63    |   1 bit | Version  | Format/version marker          | Immutable  |

---

## 3. Identity Core

The SMART ID identity core consists of:

```text
Local ID + Engine
```

This occupies:

```text
29 + 21 = 50 bits
```

The theoretical identity space is therefore:

```text
2^50
=
1,125,899,906,842,624
```

This is approximately:

```text
1.13 quadrillion identity combinations
```

The identity core is immutable after generation.

---

## 4. Local ID

The Local ID occupies bits:

```text
0–28
```

Width:

```text
29 bits
```

Capacity per Engine:

```text
2^29
=
536,870,912
```

Therefore:

**536,870,912 identifiers per Engine.**

The Local ID is allocated within the authoritative ownership domain of its Engine.

The Local ID:

* is monotonic within an Engine;
* is persistently allocated;
* must never be reused;
* must not wrap around;
* must fail hard when the namespace is exhausted.

Gaps caused by allocation, crash recovery, or abandoned reservations are acceptable.

---

## 5. Engine

The Engine occupies bits:

```text
29–49
```

Width:

```text
21 bits
```

The theoretical Engine namespace is:

```text
2^21
=
2,097,152
```

Engine assignment is part of identifier generation and is immutable after generation.

At any time:

> **An Engine ID MUST have at most one authoritative active allocator.**

Concurrent or stale ownership of the same Engine ID must be prevented by the implementation.

Fencing, leases, or another equivalent ownership mechanism may be used.

SMART ID does not mandate a particular control-plane architecture.

---

## 6. Region

The Region field occupies bits:

```text
50–57
```

Width:

```text
8 bits
```

Region is generation-time metadata.

It is **not part of the identity core**.

It is **not part of the routing path**.

Region may be used for:

* presentation;
* governance;
* reporting;
* historical classification;
* generation-time regional metadata.

Region values may be re-mapped for presentation or governance without changing the identity core.

---

## 7. State

The State field occupies bit:

```text
58
```

Width:

```text
1 bit
```

State is a lifecycle marker.

Defined v1.x semantics:

```text
State = 1 → enabled
State = 0 → retired / disabled
```

State is:

* not part of routing;
* not part of identity;
* suitable for index-level lifecycle filtering.

If an identity must be replaced because of transfer or another lifecycle event:

```text
Create NEW SMART ID
        │
        ▼
Use new identity
        │
        ▼
Retire OLD SMART ID
(State = 0)
```

The old identifier is permanently retired and is never reused.

---

## 8. Reserved Bits

Reserved bits occupy:

```text
59–62
```

Width:

```text
4 bits
```

For the current v1.x specification:

```text
Reserved = 0
```

These bits are reserved for future governance or specification evolution.

Implementations should not assign independent application semantics to these bits in v1.x.

---

## 9. Version

The Version field occupies:

```text
63
```

Width:

```text
1 bit
```

Current semantics:

```text
Version = 0 → v1.x
Version = 1 → reserved for v2
```

The Version bit is part of the format definition and is immutable after generation.

---

## 10. Identity vs Metadata

The structure can be summarized as:

```text
┌───────────────────────────────┐
│       SMART 64-Bit ID         │
├───────────────────────────────┤
│       50-bit Identity Core    │
│                               │
│  Local ID (29) + Engine (21) │
├───────────────────────────────┤
│    14-bit Governance/Metadata │
│                               │
│ Region (8)                    │
│ State (1)                     │
│ Reserved (4)                  │
│ Version (1)                   │
└───────────────────────────────┘
```

The identity core determines the immutable identity.

The remaining bits provide lifecycle, governance, metadata, and version information.

---

## 11. Routing-Relevant Fields

Only the identity fields required for routing participate in the routing path:

```text
Engine
   │
   ▼
Destination Engine
   │
   ▼
Local ID
   │
   ▼
Full Primary-Key Lookup
```

Region does not determine routing.

State does not determine routing.

Reserved bits do not determine routing.

Version does not determine routing in the v1.x routing path.

---

## 12. Fixed-Position Extraction

The fields have fixed positions within the 64-bit representation.

Conceptually:

```text
SMART ID
   │
   ├── bits 29–49 ──► Engine
   │
   └── bits 0–28 ───► Local ID
```

Extraction therefore does not require scanning variable-length identifier content.

The computational cost of extraction depends on the implementation and processor.

No universal CPU-cycle count is specified by SMART ID.

---

## 13. Structural Invariants

A valid v1.x SMART ID follows these structural rules:

1. Total width is 64 bits.
2. Local ID occupies bits 0–28.
3. Engine occupies bits 29–49.
4. Region occupies bits 50–57.
5. State occupies bit 58.
6. Reserved occupies bits 59–62.
7. Version occupies bit 63.
8. Reserved bits are zero in v1.x.
9. Identity core is Local ID + Engine.
10. Identity core is immutable after generation.

---

## 14. Capacity Summary

| Component     |   Width | Capacity / Meaning               |
| ------------- | ------: | -------------------------------- |
| Local ID      | 29 bits | 536,870,912 per Engine           |
| Engine        | 21 bits | 2,097,152 possible Engine values |
| Identity Core | 50 bits | 2^50 combinations                |
| Region        |  8 bits | Metadata                         |
| State         |   1 bit | Enabled / retired                |
| Reserved      |  4 bits | Future governance                |
| Version       |   1 bit | v1.x / future version            |

---

## 15. Important Boundary

SMART ID defines the identifier structure and its required semantics.

It does not define:

* a particular database vendor;
* a particular control-plane topology;
* a particular Engine provisioning system;
* a particular lease or fencing implementation;
* an authentication system;
* an authorization system;
* a proprietary cryptographic algorithm;
* a particular deployment topology.

Those are implementation and operational choices.

---

## 16. Summary

The v1.4 SMART 64-Bit ID layout is:

```text
63          59 58 57        50 49                  29 28                 0
┌─────────────┬──┬────────────┬──────────────────────┬─────────────────────┐
│   Version   │S │   Region   │       Engine         │      Local ID       │
│    1 bit    │1 │   8 bits   │       21 bits        │       29 bits       │
└─────────────┴──┴────────────┴──────────────────────┴─────────────────────┘
```

Where:

```text
Identity Core = Engine + Local ID = 50 bits

Governance / Metadata = Region + State + Reserved + Version = 14 bits
```

This layout is locked for SMART ID Technical Specification v1.4.
