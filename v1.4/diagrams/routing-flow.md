# SMART 64-Bit ID — Routing Flow

**Technical Specification v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document describes the routing model defined by SMART 64-Bit ID v1.4.

The routing model uses the fixed-position Engine field to identify the destination Engine and then uses the Local ID as part of the full primary-key lookup.

The routing path is:

```text
64-bit SMART ID
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
Full Primary-Key Lookup
```

This document describes routing semantics only.

It does not prescribe a particular database, network, service-mesh, proxy, control-plane, or deployment architecture.

---

## 2. Core Routing Principle

The Engine field is the routing component of the SMART ID identity core.

The Local ID identifies the record within the Engine namespace.

Therefore:

```text
Engine
  ↓
Destination
  ↓
Local ID
  ↓
Record lookup
```

The complete identity is:

```text
Identity = Engine + Local ID
```

The router uses the Engine field first because it identifies the authoritative destination for the identifier.

---

## 3. Bit Positions

The relevant fields are:

```text
┌──────────────────────┬─────────────────────┐
│ Engine               │ Local ID            │
│ bits 29–49           │ bits 0–28           │
│ 21 bits              │ 29 bits             │
└──────────────────────┴─────────────────────┘
```

The complete 64-bit identifier also contains metadata and lifecycle fields:

```text
┌─────────┬──────────┬───────┬───────────┬───────────────┬─────────────┐
│ Version │ Reserved │ State │  Region   │    Engine     │  Local ID   │
│ 1 bit   │ 4 bits   │ 1 bit │  8 bits   │    21 bits    │   29 bits   │
└─────────┴──────────┴───────┴───────────┴───────────────┴─────────────┘
```

Only Engine and Local ID are required for the identity lookup path.

---

## 4. Step 1 — Receive SMART ID

A request or internal operation provides a SMART ID.

Conceptually:

```text
Input
  │
  ▼
64-bit SMART ID
```

The identifier may arrive through an API, message, database operation, or another application interface.

If the identifier arrives as text, parsing into an appropriate 64-bit representation occurs before field extraction.

Parsing is separate from routing extraction.

---

## 5. Step 2 — Extract Engine

The router extracts bits:

```text
29–49
```

This produces the Engine value.

Conceptually:

```text
SMART ID
   │
   ├── bits 29–49
   │
   ▼
Engine
```

The Engine value identifies the destination Engine according to the deployment's Engine mapping.

SMART ID defines the field semantics but does not mandate how an implementation maps an Engine value to a physical or logical service.

---

## 6. Step 3 — Route to Engine

After Engine extraction:

```text
Engine value
     │
     ▼
Engine mapping
     │
     ▼
Destination
```

The implementation may use any suitable routing mechanism.

Examples include:

* direct service mapping;
* routing tables;
* service discovery;
* partition maps;
* database shard maps;
* application-level dispatch.

The SMART ID specification does not require one specific mechanism.

The essential semantic requirement is that the Engine value identifies the authoritative destination for the identity.

---

## 7. Engine Ownership

Routing depends on correct Engine ownership.

The fundamental invariant is:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

The routing destination and authoritative ownership model must remain consistent.

An implementation may use:

* leases;
* fencing;
* control-plane allocation;
* serialized ownership management;
* another equivalent mechanism.

SMART ID does not mandate a particular control-plane architecture.

---

## 8. Stale Ownership

A stale allocator must not continue generating identifiers for an Engine after its authoritative ownership has ended.

Examples of causes include:

* process failure;
* network partition;
* lease expiration;
* service replacement;
* failover;
* control-plane transition.

If authoritative ownership cannot be established unambiguously, generation must fail.

This is a correctness requirement rather than a performance optimization.

---

## 9. Step 4 — Extract Local ID

After routing to the appropriate Engine, the Local ID is extracted from bits:

```text
0–28
```

Conceptually:

```text
SMART ID
   │
   ├── bits 0–28
   │
   ▼
Local ID
```

The Local ID is interpreted within the Engine namespace.

Therefore the lookup identity is:

```text
Engine + Local ID
```

---

## 10. Step 5 — Full Primary-Key Lookup

The destination Engine performs the complete identity lookup.

Conceptually:

```text
Engine
  │
  ▼
Local ID
  │
  ▼
Engine + Local ID
  │
  ▼
Primary-Key Lookup
  │
  ▼
Record
```

The complete SMART ID remains the canonical identifier.

The extracted fields are routing and lookup components rather than independent identities.

---

## 11. Complete Routing Diagram

The complete conceptual path is:

```text
                    SMART 64-BIT ID
                           │
                           ▼
                  ┌─────────────────┐
                  │  64-bit value   │
                  └────────┬────────┘
                           │
                           ▼
                  Extract Engine
                   bits 29–49
                           │
                           ▼
                  ┌─────────────────┐
                  │ Engine mapping  │
                  └────────┬────────┘
                           │
                           ▼
                    Destination
                       Engine
                           │
                           ▼
                  Extract Local ID
                    bits 0–28
                           │
                           ▼
                  ┌─────────────────┐
                  │ Engine + Local  │
                  │      ID         │
                  └────────┬────────┘
                           │
                           ▼
                 Primary-Key Lookup
                           │
                           ▼
                         Record
```

---

## 12. Region Is Not Routing

The Region field occupies bits:

```text
50–57
```

Region is metadata.

It does not determine the destination Engine.

Therefore the routing path does **not** contain:

```text
SMART ID
   │
   ▼
Region
   │
   ▼
Route
```

That is not the SMART ID v1.4 routing model.

The correct path is:

```text
SMART ID
   │
   ▼
Engine
   │
   ▼
Destination
```

Region may still be used by an application for:

* reporting;
* governance;
* presentation;
* analytics;
* historical classification.

Those uses are outside the core routing decision.

---

## 13. State Is Not Routing

The State field occupies bit:

```text
58
```

State is a lifecycle marker.

Defined v1.x semantics:

```text
State = 1 → enabled
State = 0 → retired / disabled
```

State is not a routing selector.

Therefore:

```text
Engine → routing
State  → lifecycle filtering
```

An implementation may use State as an index-level filter after locating the relevant record.

It must not treat State as the Engine-routing field.

---

## 14. Reserved Bits Are Not Routing

Reserved bits occupy:

```text
59–62
```

They have no independent application semantics in v1.x.

Therefore they do not participate in routing.

Current v1.x requirement:

```text
Reserved = 0
```

---

## 15. Version Is Not a Destination Selector

Version occupies bit:

```text
63
```

Version identifies the format generation.

Current semantics:

```text
Version = 0 → v1.x
Version = 1 → reserved for v2
```

Version does not replace the Engine routing field.

Future specification versions may define their own compatibility behavior, but such behavior is outside the v1.4 routing model.

---

## 16. Routing and Lifecycle Separation

Routing and lifecycle evaluation are separate operations.

Conceptually:

```text
SMART ID
   │
   ▼
Engine extraction
   │
   ▼
Route
   │
   ▼
Primary-key lookup
   │
   ▼
Lifecycle evaluation
   │
   ├── enabled
   │
   └── retired / disabled
```

The State field therefore does not need to be part of the destination-selection operation.

---

## 17. Identity Transfer

A SMART ID is immutable.

If an identity must be transferred or otherwise requires a new identifier, the lifecycle operation is:

```text
Existing SMART ID
       │
       ▼
Create NEW SMART ID
       │
       ▼
Use NEW SMART ID
       │
       ▼
Retire OLD SMART ID
(State = 0)
```

The old identifier is never rewritten into a new identity.

The old identifier is never reused.

This preserves the meaning of historical identifiers.

---

## 18. Routing Correctness

A correct implementation should ensure:

1. Engine extraction uses bits 29–49.
2. Local ID extraction uses bits 0–28.
3. Engine determines the routing destination.
4. Local ID is interpreted within the selected Engine namespace.
5. Region is not used as the routing selector.
6. State is not used as the routing selector.
7. Reserved bits do not participate in routing.
8. Version does not replace Engine routing in v1.x.
9. Full identity lookup uses Engine + Local ID.
10. Engine ownership remains authoritative and unambiguous.

---

## 19. Fixed-Position Extraction

The routing fields have fixed bit positions.

For a fixed 64-bit identifier width, extraction is based on fixed masks and shifts or equivalent operations.

Conceptually:

```text
SMART ID
   │
   ├──────────────► Engine
   │                bits 29–49
   │
   └──────────────► Local ID
                    bits 0–28
```

The extraction operation does not require scanning a variable-length identifier.

Its computational complexity is constant with respect to identifier width.

---

## 20. CPU Performance Boundary

SMART ID does not define a universal CPU-cycle count for routing.

Actual execution cost depends on:

* CPU architecture;
* processor generation;
* compiler;
* programming language;
* optimization;
* instruction selection;
* runtime;
* memory behavior;
* surrounding application work.

Therefore statements such as:

```text
"SMART ID routing always takes N CPU cycles"
```

must not be treated as specification claims.

Measured CPU cycles are benchmark results for a particular environment.

---

## 21. Routing vs Parsing

A complete API request may contain several stages:

```text
External request
       │
       ▼
Text / binary parsing
       │
       ▼
64-bit SMART ID
       │
       ▼
Engine extraction
       │
       ▼
Routing
       │
       ▼
Database lookup
```

These stages must not be conflated when reporting performance.

A routing microbenchmark should identify whether parsing is included.

---

## 22. Routing vs Database Performance

A routing decision is not equivalent to database performance.

The end-to-end operation may include:

```text
Parsing
   │
   ▼
Field extraction
   │
   ▼
Routing
   │
   ▼
Network transfer
   │
   ▼
Connection handling
   │
   ▼
Database lookup
   │
   ▼
Record processing
```

A benchmark must state which stages are measured.

The v1.4 database benchmark should not be interpreted as a pure CPU routing benchmark.

---

## 23. Routing vs FPE

Format-preserving encryption may be used when a public representation of the identifier requires cryptographic processing.

That operation is separate from SMART ID field extraction.

Conceptually:

```text
Public representation
       │
       ▼
FPE processing
       │
       ▼
SMART ID representation
       │
       ▼
Engine extraction
       │
       ▼
Routing
```

FPE performance must not be presented as SMART ID routing performance.

SMART ID does not define a proprietary FPE algorithm.

---

## 24. Public ID Boundary

An implementation may maintain separate internal and public representations.

For example:

```text
Internal identity
       │
       ▼
SMART 64-Bit ID
       │
       ▼
Public representation
       │
       ▼
Optional FPE
```

The public representation may be designed for application-specific requirements.

Authentication, authorization, integrity protection, and key management remain application and deployment responsibilities.

---

## 25. Numeric Serialization

When SMART IDs are transported through APIs, implementations should consider numeric representation limits.

In particular, common IEEE-754 JavaScript `Number` representations cannot exactly represent every integer above:

```text
2^53
```

Therefore APIs should not rely on ordinary JavaScript numeric handling for arbitrary 64-bit SMART IDs.

A common safe representation is:

```text
JSON string
```

For example:

```json
{
  "id": "1844674407370955161"
}
```

The exact serialization contract is an implementation/API choice.

The SMART ID format itself remains a 64-bit identifier.

---

## 26. Routing Table Semantics

An implementation may maintain a mapping such as:

```text
Engine ID
    │
    ▼
Authoritative destination
```

For example:

```text
Engine 0  → Destination A
Engine 1  → Destination B
Engine 2  → Destination C
...
```

The physical destination can change over time as infrastructure changes.

The immutable SMART ID still contains the original Engine value.

Therefore infrastructure routing metadata may be updated without rewriting existing identifiers.

---

## 27. Engine Rotation

Engine rotation is a deployment and allocation strategy intended to distribute write activity.

The Engine field itself remains immutable after identifier generation.

Conceptually:

```text
Allocation
   │
   ├── Engine A
   │
   ├── Engine B
   │
   ├── Engine C
   │
   └── ...
```

New identifiers may be allocated under different Engines according to the client's control-plane policy.

Existing identifiers do not change Engine values.

---

## 28. Static Engine Assignment

A static Engine assignment strategy that prevents required rotation or causes uncontrolled concentration of writes is not the intended v1.4 allocation model.

Engine allocation should support the deployment's operational distribution requirements.

The exact provisioning and rotation mechanism is implementation-specific.

---

## 29. Engine Exhaustion vs Local Exhaustion

The Local ID namespace is finite:

```text
536,870,912 identifiers per Engine
```

When a Local ID namespace is exhausted:

```text
Allocation
   │
   ▼
Exhausted
   │
   ▼
FAIL HARD
```

The identifier format does not define the operational recovery mechanism.

The client/control plane may obtain another Engine or take another operational action.

The implementation must not wrap the Local ID and reuse prior identifiers.

---

## 30. Duplicate Detection

A correct implementation must treat duplicate identity generation as a correctness failure.

The relevant invariant is:

```text
No duplicate Engine ownership
+
No duplicate Local ID generation
=
No duplicate SMART identity
```

If the implementation detects an unsafe allocation condition, generation must fail rather than silently produce a conflicting identity.

---

## 31. Crash Recovery

Crash recovery must preserve non-reuse.

After a crash:

```text
Previously allocated IDs
        │
        ▼
Remain permanently consumed
```

An implementation may have gaps after recovery.

Gaps are acceptable.

Reuse is not.

The routing semantics remain unchanged because the Engine and Local ID fields of existing identifiers remain immutable.

---

## 32. Batch Allocation

Batch allocation may reserve a range of Local IDs.

Conceptually:

```text
Engine
  │
  ▼
Reserve batch
  │
  ├── Local A
  ├── Local B
  ├── Local C
  └── ...
```

If the allocator crashes after reservation, unused identifiers in the reserved range may become gaps.

They must not later be reissued as if they had never been allocated.

This protects the non-reuse invariant.

---

## 33. Routing Under Failover

Infrastructure may fail over while an identifier remains unchanged.

Conceptually:

```text
SMART ID
   │
   ▼
Engine value
   │
   ▼
Current authoritative mapping
   │
   ▼
Active destination
```

The Engine field remains part of the immutable identity.

The implementation's current routing map may determine where that Engine is currently served.

Failover mechanisms must preserve authoritative ownership and must not create duplicate allocators for the same Engine.

---

## 34. Network Partition

A network partition can create stale ownership risk.

The dangerous condition is:

```text
Old allocator
      +
New allocator
      ↓
Same Engine
```

This must not be permitted.

The implementation should use an appropriate ownership or fencing mechanism so that only one allocator remains authoritative.

If ownership cannot be established safely:

```text
Generation → FAIL HARD
```

Correctness takes priority over availability.

---

## 35. Routing During Ownership Transition

Ownership transition should be treated explicitly.

Conceptually:

```text
Old Owner
   │
   ▼
Ownership termination / fencing
   │
   ▼
New Owner established
   │
   ▼
Generation resumes
```

The exact sequence depends on the control-plane architecture.

SMART ID defines the required ownership invariant, not the control-plane implementation.

---

## 36. Distributed Routing

For a distributed deployment:

```text
                    SMART ID
                       │
                       ▼
                Extract Engine
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Engine A     Engine B     Engine C
          │            │            │
          ▼            ▼            ▼
       Local IDs    Local IDs    Local IDs
          │            │            │
          └────────────┼────────────┘
                       ▼
                 Record lookup
```

Each Engine represents a distinct identity namespace.

The routing layer determines the current destination associated with the Engine value.

---

## 37. Multi-Engine Correctness

A valid multi-engine implementation must preserve:

* unique Engine ownership;
* unique Local ID allocation within each Engine;
* persistent allocation state;
* non-reuse;
* correct Engine extraction;
* correct Local ID extraction;
* failure on unsafe ownership;
* correct routing mapping.

Multi-engine performance must be measured separately from single-engine performance.

---

## 38. Single-Engine vs Multi-Engine Routing

Single-engine routing:

```text
SMART ID
   │
   ▼
Engine
   │
   ▼
One authoritative destination
   │
   ▼
Local ID lookup
```

Multi-engine routing:

```text
SMART ID
   │
   ▼
Engine
   │
   ▼
Engine-specific destination
   │
   ▼
Local ID lookup
```

The identifier semantics remain the same.

The deployment topology changes.

---

## 39. Simulated Engine Values

A benchmark that uses:

```text
Engine = row_index % 16
```

inside a single writer does not automatically represent 16 independent Engines.

Such a workload may be useful for studying value distribution, but it is not evidence of genuine multi-engine concurrency.

A valid distributed benchmark should use independent authoritative allocation streams.

The existing invalid experiment is documented separately in:

`research/FINDINGS_MULTI_ENGINE_INVALID.md`

---

## 40. Routing Correctness Test

A basic routing correctness test can verify:

```text
Input SMART ID
      │
      ▼
Extract Engine
      │
      ▼
Expected Engine
      │
      ▼
Extract Local ID
      │
      ▼
Expected Local ID
```

The test should confirm that unrelated fields do not alter Engine or Local ID extraction.

---

## 41. Field Independence

For v1.x:

```text
Engine extraction
    depends on bits 29–49

Local ID extraction
    depends on bits 0–28
```

Region, State, Reserved, and Version have separate semantics.

Changing metadata fields must not redefine the identity core.

Any implementation that changes identity semantics based on metadata without a corresponding specification rule is outside the v1.4 model.

---

## 42. Example Conceptual Flow

Consider a SMART ID whose fields decode conceptually as:

```text
Engine  = E
Local ID = L
Region  = R
State   = 1
Version = 0
```

The routing operation is:

```text
SMART ID
   │
   ▼
Engine = E
   │
   ▼
Route to Engine E
   │
   ▼
Local ID = L
   │
   ▼
Lookup identity (E, L)
```

Region `R` is not required to choose the destination.

State `1` indicates lifecycle status rather than destination.

---

## 43. Example Retired Identity

For:

```text
State = 0
```

the identifier remains structurally valid.

Routing semantics remain based on Engine.

After lookup, the application may apply lifecycle policy:

```text
SMART ID
   │
   ▼
Engine routing
   │
   ▼
Record lookup
   │
   ▼
State = 0
   │
   ▼
Retired / disabled
```

State therefore acts as a lifecycle filter rather than a routing field.

---

## 44. Routing and Indexing

The primary key represents the complete identity.

An implementation may use indexes to support lifecycle or operational queries.

For example:

```text
Primary key
    ↓
Engine + Local ID identity

Lifecycle index
    ↓
State filtering
```

The existence of a lifecycle index does not change the routing semantics.

---

## 45. Routing and Storage Locality

SMART ID's bit layout may influence physical key ordering and storage behavior.

The v1.4 empirical work observed clustered-index size differences under the tested MariaDB/InnoDB configurations.

That storage result is separate from the logical routing operation.

Therefore:

```text
Routing semantics
        ≠
Storage benchmark result
```

The benchmark findings are documented in:

`research/FINDINGS_SINGLE_ENGINE.md`

---

## 46. Routing and Performance Claims

The v1.4 evidence does not establish a universal routing performance advantage.

The correct distinction is:

```text
Fixed-position extraction
        │
        ▼
Defined routing semantics
```

versus:

```text
Measured performance
        │
        ▼
Specific implementation + hardware + workload
```

Both must be kept separate.

---

## 47. Implementation Freedom

SMART ID defines:

* field positions;
* identity semantics;
* Engine routing semantics;
* Local ID lookup semantics;
* ownership invariants;
* failure behavior.

SMART ID does not dictate:

* service discovery technology;
* routing proxy;
* database vendor;
* database topology;
* network architecture;
* control-plane implementation;
* programming language;
* deployment platform.

This separation allows different implementations to remain compatible with the identifier semantics.

---

## 48. Security Boundary

Routing is not authentication.

Possession of a valid-looking identifier does not by itself grant access.

Implementations remain responsible for:

* authentication;
* authorization;
* integrity;
* access control;
* audit;
* key management;
* transport security.

SMART ID defines identity and routing semantics, not an application security framework.

---

## 49. Public Identifier Security

If SMART IDs are exposed externally, an implementation may use an additional public representation.

Format-preserving encryption may be considered where appropriate.

However:

```text
FPE
≠
Authentication
≠
Authorization
≠
Integrity
```

These concerns must remain separate.

---

## 50. Routing Summary

The v1.4 routing model is:

```text
┌──────────────────────────────┐
│        64-bit SMART ID       │
└──────────────┬───────────────┘
               │
               ▼
       Extract Engine
        bits 29–49
               │
               ▼
       Route to Engine
               │
               ▼
       Extract Local ID
         bits 0–28
               │
               ▼
     Full Primary-Key Lookup
               │
               ▼
             Record
```

The routing path does not use Region or State as destination selectors.

---

## 51. Final Routing Invariants

A v1.4 implementation should preserve these invariants:

1. **Engine is extracted from bits 29–49.**
2. **Local ID is extracted from bits 0–28.**
3. **Engine determines the routing destination.**
4. **Local ID is interpreted within the Engine namespace.**
5. **The complete identity is Engine + Local ID.**
6. **Region is metadata, not routing.**
7. **State is lifecycle information, not routing.**
8. **Reserved bits are not routing.**
9. **Version does not replace Engine routing in v1.x.**
10. **An Engine has at most one authoritative active allocator.**
11. **Unsafe or ambiguous ownership results in generation failure.**
12. **Local IDs are never reused.**
13. **Local namespace exhaustion results in failure rather than wraparound.**
14. **Routing performance must be measured in its actual implementation environment.**
15. **FPE performance is separate from SMART ID extraction performance.**

---

## 52. Conclusion

SMART 64-Bit ID v1.4 uses a direct fixed-position routing model.

The Engine field provides the destination identity, while the Local ID identifies the record within that Engine namespace.

The correct logical path is:

```text
64-bit ID
→ Engine
→ Engine destination
→ Local ID
→ full primary-key lookup
```

Region, State, Reserved, and Version have separate semantics and are not used as routing selectors in the v1.4 path.

The architecture remains implementation-independent: SMART ID defines the identifier and its correctness requirements, while the client determines the appropriate control-plane, routing infrastructure, storage system, and deployment topology.

**Routing correctness takes priority over performance.**

**Measured performance claims must remain bounded by their actual test environment.**

This routing model is locked for SMART ID Technical Specification v1.4.
