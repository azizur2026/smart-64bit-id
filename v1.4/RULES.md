# SMART 64-Bit ID — Rules

**Technical Rules v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document defines the normative operational rules of SMART 64-Bit ID v1.4.

The terms **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are used in their ordinary normative sense.

A rule marked **FAIL HARD** identifies a condition under which an implementation must stop the affected generation operation rather than continue with potentially unsafe identity allocation.

---

## 2. Identifier Structure Rules

### Rule 2.1 — Fixed Width

A SMART ID **MUST** contain exactly 64 bits.

### Rule 2.2 — Field Positions

Implementations **MUST** use the v1.4 field positions:

| Field    | Bits  |
| -------- | ----- |
| Local ID | 0–28  |
| Engine   | 29–49 |
| Region   | 50–57 |
| State    | 58    |
| Reserved | 59–62 |
| Version  | 63    |

### Rule 2.3 — Identity Core

The Local ID and Engine fields together **MUST** constitute the immutable identity core.

The identity core is 50 bits.

### Rule 2.4 — Immutable Identity

Once generated, the Engine and Local ID components of a SMART ID **MUST NOT** be modified.

---

## 3. Local ID Rules

### Rule 3.1 — Width

Local ID **MUST** use the 29-bit range defined by bits 0–28.

### Rule 3.2 — Capacity

Each Engine provides:

**2^29 = 536,870,912 identifiers**

within its Local ID namespace.

### Rule 3.3 — Persistence

Local allocation state **MUST** be persistent.

A restart or crash **MUST NOT** cause previously allocated Local IDs to become available again.

### Rule 3.4 — Non-Reuse

An allocated Local ID **MUST NOT** be reused within the same Engine namespace.

### Rule 3.5 — No Wraparound

A Local ID counter **MUST NOT** wrap around after reaching its maximum usable value.

### Rule 3.6 — Monotonic Allocation

Local IDs **SHOULD** be allocated monotonically within an Engine.

The specification does not require gapless allocation.

### Rule 3.7 — Batch Allocation

Local IDs **MAY** be allocated in batches.

Batch allocation **MUST NOT** compromise uniqueness or non-reuse.

---

## 4. Local ID Exhaustion

### Rule 4.1 — Exhaustion

When an Engine's Local ID namespace is exhausted, that Engine **MUST NOT** allocate another Local ID.

### Rule 4.2 — Exhaustion Failure

Local ID exhaustion is a **FAIL HARD** condition for the affected Engine.

### Rule 4.3 — No Recycling

An implementation **MUST NOT** recycle previously allocated Local IDs to overcome exhaustion.

### Rule 4.4 — Operational Response

The client/control plane **MAY** respond to exhaustion by:

* assigning another Engine;
* provisioning another Engine;
* rotating to another available Engine; or
* applying another operational policy.

These responses are outside the SMART ID identifier format.

---

## 5. Engine Rules

### Rule 5.1 — Width

Engine **MUST** use the 21-bit range defined by bits 29–49.

### Rule 5.2 — Capacity

The Engine field provides:

**2^21 = 2,097,152 possible Engine IDs**

### Rule 5.3 — Immutability

The Engine component of a generated SMART ID **MUST NOT** change.

### Rule 5.4 — Allocation Authority

Engine allocation is a client/control-plane responsibility.

SMART ID **MUST NOT** be interpreted as requiring a specific control-plane architecture.

---

## 6. Engine Ownership Rules

### Rule 6.1 — Single Authority

At any time, an Engine ID **MUST** have at most one authoritative active allocator.

### Rule 6.2 — No Concurrent Authority

Two independent authorities **MUST NOT** simultaneously generate Local IDs for the same active Engine.

### Rule 6.3 — Stale Ownership

A stale allocator **MUST NOT** continue generating valid SMART IDs after its Engine authority has ended.

### Rule 6.4 — Ownership Uncertainty

If authoritative ownership cannot be established unambiguously, generation using that Engine **MUST FAIL HARD**.

### Rule 6.5 — Fencing

Implementations **SHOULD** use leases, fencing tokens, epochs, or an equivalent mechanism when required to prevent stale or concurrent ownership.

The particular mechanism is implementation-specific.

---

## 7. Uniqueness Rules

### Rule 7.1 — Identity Uniqueness

The combination of Engine and Local ID **MUST** be unique among all generated SMART IDs.

### Rule 7.2 — Duplicate Detection

If an implementation detects a condition capable of producing a duplicate SMART ID, generation **MUST FAIL HARD**.

### Rule 7.3 — No Silent Recovery

An implementation **MUST NOT** silently continue after detecting an identity-allocation condition that could result in duplication.

### Rule 7.4 — Fundamental Invariant

The fundamental generation invariant is:

> **No duplicate Engine ID + no duplicate Local ID → FAIL HARD.**

---

## 8. Crash and Recovery Rules

### Rule 8.1 — Crash Safety

A crash **MUST NOT** result in reuse of an already allocated Local ID.

### Rule 8.2 — Recovery State

Recovery **MUST** establish a safe allocation point before generation resumes.

### Rule 8.3 — Gaps

Allocation gaps **MAY** occur after failures.

Gaps are acceptable.

### Rule 8.4 — Gap Priority

Uniqueness and non-reuse **MUST** take priority over gapless numbering.

### Rule 8.5 — Unsafe Recovery

If recovery cannot establish a safe non-reuse state, generation **MUST FAIL HARD** until the state is repaired or replaced.

---

## 9. Concurrency Rules

### Rule 9.1 — Shared Allocation State

Where multiple workers share allocation state, the implementation **MUST** use appropriate concurrency control.

### Rule 9.2 — Equivalent Mechanisms

Acceptable mechanisms **MAY** include:

* row-level locking;
* transactional allocation;
* atomic operations;
* serialized allocation services;
* distributed coordination; or
* another mechanism providing equivalent guarantees.

### Rule 9.3 — Duplicate Prevention

Concurrent allocation **MUST NOT** produce duplicate Local IDs within an Engine.

### Rule 9.4 — Storage Capability

The selected storage mechanism **MUST** be capable of satisfying the persistence and concurrency requirements.

---

## 10. Routing Rules

### Rule 10.1 — Engine First

Routing **MUST** extract the Engine field from bits 29–49.

### Rule 10.2 — Engine Routing

The Engine field **MUST** determine the SMART ID's Engine routing destination.

### Rule 10.3 — Local Lookup

After Engine routing, the Local ID **MUST** remain available for the local lookup operation.

### Rule 10.4 — Region Exclusion

Region **MUST NOT** be treated as part of the defined SMART ID routing path.

### Rule 10.5 — State Exclusion

State **MUST NOT** be used as the routing selector.

### Rule 10.6 — Fixed Positions

Implementations **MUST** use the defined fixed field positions when interpreting a v1.4 SMART ID.

---

## 11. Region Rules

### Rule 11.1 — Metadata

Region **MUST** be treated as metadata rather than part of the immutable identity core.

### Rule 11.2 — Generation-Time Classification

Region represents the generation-time regional or country classification according to the implementation's applicable policy.

### Rule 11.3 — No Identity Dependency

Region **MUST NOT** be required to establish identity uniqueness.

### Rule 11.4 — No Routing Dependency

Region **MUST NOT** be required for the defined Engine → Local routing path.

### Rule 11.5 — Presentation Mapping

Region **MAY** be remapped for presentation or governance purposes.

---

## 12. State Rules

### Rule 12.1 — State Values

State value:

* `1` = Enabled
* `0` = Retired / Disabled

### Rule 12.2 — Lifecycle Role

State **MUST** be treated as lifecycle metadata.

### Rule 12.3 — Routing Exclusion

State **MUST NOT** determine routing.

### Rule 12.4 — Retirement

When an identity is replaced and a new SMART ID is required:

1. a new SMART ID **MUST** be generated;
2. the new identity **MUST** be established as the current identity;
3. the old SMART ID **MUST** be set to State = 0; and
4. the old SMART ID **MUST NOT** be reused.

### Rule 12.5 — Permanent Retirement

Once retired, an identifier **MUST** remain permanently unavailable for reuse.

---

## 13. Reserved-Bit Rules

### Rule 13.1 — Current Value

Reserved bits 59–62 **MUST** be zero for the current v1.x format.

### Rule 13.2 — Future Assignment

Reserved bits **MUST NOT** be assigned a new meaning by an implementation without an applicable future specification.

### Rule 13.3 — Compatibility

Implementations **SHOULD** preserve Reserved-bit compatibility for future format evolution.

---

## 14. Version Rules

### Rule 14.1 — Current Version

Version bit 63 **MUST** be zero for SMART ID v1.x.

### Rule 14.2 — Future Version

Version value 1 is reserved for a future v2 format unless formally assigned.

### Rule 14.3 — Independent Interpretation

Implementations **MUST NOT** independently redefine the Version bit.

---

## 15. Public-ID and FPE Rules

### Rule 15.1 — Separation

Public-ID cryptographic processing **MUST** remain separate from SMART ID's internal identity and routing semantics.

### Rule 15.2 — FPE Role

Format-preserving encryption **MAY** be used where appropriate for public identifier representation.

### Rule 15.3 — Security Boundary

FPE **MUST NOT** be treated as a replacement for:

* authentication;
* authorization;
* integrity protection;
* access control; or
* application security.

### Rule 15.4 — Proprietary Algorithms

SMART ID **DOES NOT** require a proprietary cryptographic algorithm.

---

## 16. Cryptographic Standards Rules

### Rule 16.1 — Applicable Standards

Implementations using FPE or related cryptographic mechanisms **MUST** use applicable internationally recognized and approved cryptographic standards and their current authoritative revisions.

### Rule 16.2 — Implementation Responsibility

The implementation owner is responsible for selecting appropriate algorithms, libraries, configuration, key management, and deployment controls.

### Rule 16.3 — Certification Boundary

SMART ID v1.4 itself does not constitute cryptographic certification.

Compliance depends on the actual implementation, deployment, jurisdiction, and applicable standards.

---

## 17. Serialization Rules

### Rule 17.1 — API Representation

SMART IDs **SHOULD** be serialized as strings in JSON and other APIs where complete 64-bit numeric precision cannot be guaranteed.

### Rule 17.2 — Numeric Precision

Implementations **MUST NOT** assume that an application runtime's default numeric type can exactly represent every unsigned 64-bit SMART ID.

### Rule 17.3 — IEEE-754 Environments

Applications using IEEE-754 double-precision numeric representations **MUST** account for the loss of integer precision above 2^53.

---

## 18. Security Rules

### Rule 18.1 — Authentication

SMART ID does not provide authentication.

The surrounding application **MUST** implement appropriate authentication where required.

### Rule 18.2 — Authorization

SMART ID does not provide authorization.

The surrounding application **MUST** enforce authorization independently.

### Rule 18.3 — Integrity

SMART ID does not provide cryptographic integrity protection.

Applications requiring integrity protection **MUST** implement appropriate controls.

### Rule 18.4 — Key Management

Where cryptography is used, key management **MUST** be handled by the implementation according to applicable security requirements and standards.

---

## 19. Database Rules

### Rule 19.1 — Database Independence

SMART ID **MUST NOT** require a specific database vendor at the specification level.

### Rule 19.2 — Persistence

The selected database/storage system **MUST** support the required persistence guarantees.

### Rule 19.3 — Concurrency

The selected database/storage system **MUST** support the required allocation concurrency guarantees.

### Rule 19.4 — Uniqueness

Where database-level uniqueness constraints are used, they **SHOULD** be configured to reinforce the SMART ID uniqueness invariant.

---

## 20. Performance Rules

### Rule 20.1 — No Universal Guarantee

SMART ID **MUST NOT** be presented as having a universal performance advantage over other identifier schemes.

### Rule 20.2 — Measured Results

Benchmark claims **MUST** identify their test environment and workload.

### Rule 20.3 — CPU Cycles

Implementations **MUST NOT** claim a universal CPU-cycle count for SMART ID bit extraction.

Actual performance depends on implementation and processor microarchitecture.

### Rule 20.4 — Storage Results

Measured index-size reductions **MUST** be presented as empirical results from the tested configurations and workload, not as universal guarantees.

---

## 21. Experimental Evidence Rules

### Rule 21.1 — Reproducibility

Published benchmark results **SHOULD** include sufficient environment and methodology information for independent reproduction.

### Rule 21.2 — Validity

An experiment that does not correctly model the architecture under evaluation **MUST NOT** be presented as valid evidence for that architecture.

### Rule 21.3 — Invalid Multi-Engine Experiment

The documented one-writer experiment that cycles across 16 Engine values **MUST** be identified as invalid evidence for a true 16-engine distributed workload.

It represents one writer cycling across Engine namespaces rather than 16 independent concurrent Engine authorities.

### Rule 21.4 — Future Multi-Engine Testing

A valid multi-engine benchmark should use independent concurrent writers, each with an appropriate Engine ownership and allocation context, or another methodology that accurately models the intended distributed architecture.

---

## 22. Failure Rules

### Rule 22.1 — Fail Hard

The following conditions **MUST** cause the affected generation operation to fail hard:

* duplicate Engine ownership;
* ambiguous Engine ownership;
* stale allocator authority;
* duplicate Local ID detection;
* unsafe recovery state;
* Local ID exhaustion;
* counter wraparound;
* corrupted allocation state; or
* any condition known to threaten identity uniqueness.

### Rule 22.2 — No Silent Duplication

An implementation **MUST NOT** generate a potentially duplicate identifier merely to maintain service availability.

### Rule 22.3 — Operational Recovery

After a hard failure, the surrounding system **MAY** restore generation after establishing a safe authoritative state.

---

## 23. Control-Plane Rules

### Rule 23.1 — Architecture Freedom

SMART ID **MUST NOT** be interpreted as mandating a centralized control-plane architecture.

### Rule 23.2 — Responsibility

The client/control plane **MUST** ensure authoritative and non-conflicting Engine ownership.

### Rule 23.3 — Implementation Choice

The choice of centralized, distributed, leased, fenced, or equivalent control mechanisms is an implementation decision.

### Rule 23.4 — Required Outcome

Regardless of architecture, the implementation **MUST** preserve:

* Engine ownership uniqueness;
* Local ID uniqueness;
* persistence;
* non-reuse; and
* safe failure behavior.

---

## 24. Lifecycle Rules

### Rule 24.1 — Enabled

State = 1 represents an enabled identifier.

### Rule 24.2 — Retired

State = 0 represents a retired or disabled identifier.

### Rule 24.3 — No Reuse

Retirement **MUST NOT** return the identifier to the allocation pool.

### Rule 24.4 — Replacement

When replacement requires a new identity, the implementation **MUST** generate a new SMART ID.

---

## 25. Compliance Summary

A v1.4-compatible implementation must satisfy the following core conditions:

* exactly 64-bit SMART ID structure;
* correct field positions;
* 29-bit Local ID;
* 21-bit Engine;
* 8-bit Region;
* 1-bit State;
* 4 Reserved bits;
* 1 Version bit;
* immutable identity core;
* persistent Local allocation;
* no Local ID reuse;
* no Local ID wraparound;
* single authoritative Engine ownership;
* prevention of stale ownership;
* hard failure on unsafe allocation;
* Engine-based routing;
* Region excluded from routing;
* State excluded from routing;
* permanent retirement;
* correct Version handling;
* appropriate serialization;
* standards-aligned cryptographic implementation where applicable; and
* truthful presentation of empirical performance results.

---

## 26. Final Rule

The highest-priority operational principle is:

> **When an implementation cannot guarantee identity uniqueness and non-reuse, it must stop generation rather than generate an uncertain identifier.**

SMART ID prioritizes identity correctness over gaplessness and availability under unsafe allocation conditions.

SMART ID v1.4 establishes these rules as the normative operational baseline.
