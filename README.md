# SMART 64-Bit ID

**Technical Specification: v1.4**
**Status: Locked for public release**

SMART 64-Bit ID is a fixed-width 64-bit identifier model designed for distributed identity allocation, deterministic Engine-based routing, immutable identity semantics, and bounded lifecycle/governance metadata.

## Core Layout

| Bits  | Field    |    Size | Role                         |
| ----- | -------- | ------: | ---------------------------- |
| 0–28  | Local ID | 29 bits | Immutable identity           |
| 29–49 | Engine   | 21 bits | Immutable identity / routing |
| 50–57 | Region   |  8 bits | Generation-time metadata     |
| 58    | State    |   1 bit | Lifecycle marker             |
| 59–62 | Reserved |  4 bits | Future governance            |
| 63    | Version  |   1 bit | Format version               |

The immutable identity core is **50 bits**:

* 29-bit Local ID
* 21-bit Engine ID
* Maximum identity capacity: `2^50 = 1,125,899,906,842,624`

Region, State, Reserved, and Version form the remaining 14 governance/metadata bits.

## Generation

SMART ID requires:

* Persistent Local ID allocation
* Monotonic Local IDs per Engine
* Batch allocation where appropriate
* No Local ID reuse
* Hard failure on Local ID exhaustion
* Authoritative Engine ownership
* At most one authoritative active allocator for an Engine at a time
* Protection against stale or concurrent ownership
* Crash-safe allocation behavior

Gaps caused by failures are acceptable. Uniqueness and non-reuse take priority over gaplessness.

## Routing

The defined routing path is:

```text
64-bit SMART ID
    ↓
Extract Engine (bits 29–49)
    ↓
Route to Engine
    ↓
Extract Local ID (bits 0–28)
    ↓
Full primary-key lookup
```

Region and State are not routing selectors.

SMART ID does not claim a universal CPU-cycle count. Actual performance depends on implementation, processor, cache behavior, storage, workload, and deployment environment.

## Lifecycle

State is a lifecycle marker:

* `State = 1` — enabled
* `State = 0` — retired/disabled

A retired SMART ID is never reused.

If an identity requires a new identifier, the implementation creates a new SMART ID and retires the old one.

## Public Representation and Security

SMART IDs may be represented publicly as strings.

Implementations must not rely on native numeric parsing above `2^53` where the surrounding platform uses IEEE-754-style numeric limitations.

Format-preserving encryption may be used for public representations where appropriate. FPE is not authentication, authorization, or integrity protection.

SMART ID does not define a proprietary cryptographic algorithm. Implementations must use applicable internationally recognized and approved cryptographic standards and their current authoritative revisions.

## Database Integration

SMART ID can be used as a database identifier while allowing implementations to maintain a separate internal database primary key where appropriate.

The v1.4 empirical work includes a controlled single-engine MariaDB/InnoDB experiment. The tested configurations showed approximately **33–53% smaller clustered indexes** for SMART IDs.

These storage findings are workload- and configuration-specific and are not universal guarantees.

The separate simulated multi-engine experiment is explicitly **INVALID as evidence of distributed multi-engine performance**.

## Scope

SMART ID defines:

* 64-bit identifier structure
* Identity semantics
* Engine and Local ID allocation rules
* Uniqueness and non-reuse requirements
* Routing semantics
* Lifecycle semantics
* Required failure behavior
* Standards commitment

SMART ID does not mandate:

* A particular control-plane topology
* A particular Engine provisioning system
* A specific lease/fencing mechanism
* A database vendor
* A deployment topology
* An authentication system
* An authorization system
* A proprietary cryptographic algorithm

## Documentation

### Specification

* `docs/SPECIFICATION.md`
* `docs/RULES.md`
* `docs/ARCHITECTURE.md`
* `docs/STANDARDS.md`
* `docs/INDUSTRY_ALIGNMENT.md`
* `docs/LIMITATIONS.md`

### Research

* `research/FINDINGS_SINGLE_ENGINE.md`
* `research/FINDINGS_MULTI_ENGINE_INVALID.md`
* `research/BENCHMARK_PROTOCOL.md`
* `research/CYCLE_COMPARISON.md`

### Technical Paper

* `papers/SMART_64BIT_ID_PAPER.md`
* `papers/SMART_64-Bit_ID_Technical_Paper_v1.4.pdf`

### Examples and Diagrams

See `examples/` and `diagrams/` for non-normative implementation examples and explanatory material.

## License

SMART 64-Bit ID is released under the GNU Affero General Public License v3.0. See `LICENSE`.

A separate commercial/proprietary license may be available from the copyright holder. See `COMMERCIAL-LICENSE.md`.

## Copyright

Copyright (c) 2026 MD. AZIZUR RAHMAN
SAMARA

## Contact

Commercial licensing and project inquiries:

* [md.azizur.rahman@samara.com.bd](mailto:md.azizur.rahman@samara.com.bd)
* [contact@samara.com.bd](mailto:contact@samara.com.bd)

## Status

**SMART ID Technical Specification v1.4 is locked for this release.**

The technical paper describes the v1.4 model and does not modify the normative specification.
