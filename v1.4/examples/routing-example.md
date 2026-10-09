# SMART 64-Bit ID — Routing Example

**Example Document — Non-Normative**
**Technical Specification:** v1.4
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document provides a conceptual example of how a SMART 64-Bit ID can be routed.

It is intended to demonstrate the v1.4 routing semantics without prescribing a specific programming language, database, service architecture, or deployment topology.

This document is **non-normative**.

The normative requirements are defined by the SMART ID technical specification and rules documentation.

---

## 2. Core Routing Model

The SMART ID routing path is:

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

The identity is:

```text
Engine + Local ID
```

---

## 3. Example Identifier

For this conceptual example, assume an identifier decodes to:

```text
Engine   = 42
Local ID = 125000
Region   = 18
State    = 1
Version  = 0
Reserved = 0
```

The important routing fields are:

```text
Engine   = 42
Local ID = 125000
```

The other fields have separate semantics.

---

## 4. Step 1 — Receive the Identifier

An application receives a SMART ID through an API request.

Conceptually:

```text
Request
   │
   ▼
SMART ID
```

If the API transports the identifier as text, the application first parses it into an appropriate 64-bit representation.

Parsing is separate from field extraction.

---

## 5. Step 2 — Decode Engine

The implementation extracts bits:

```text
29–49
```

This produces:

```text
Engine = 42
```

Conceptually:

```text
SMART ID
   │
   └── bits 29–49
            │
            ▼
        Engine 42
```

The Engine value is then used to identify the appropriate destination.

---

## 6. Step 3 — Resolve Destination

The implementation maps:

```text
Engine 42
```

to its current authoritative destination.

For example:

```text
Engine 42
    │
    ▼
Engine mapping
    │
    ▼
Destination for Engine 42
```

The actual mapping mechanism is implementation-specific.

It could use:

* a routing table;
* service discovery;
* partition metadata;
* database shard metadata;
* application-level dispatch.

SMART ID does not mandate one mechanism.

---

## 7. Step 4 — Route to Engine

The request is sent to the destination responsible for Engine 42.

Conceptually:

```text
Client
  │
  ▼
Engine 42 mapping
  │
  ▼
Engine 42 destination
```

The destination may be a logical service, database partition, shard, or another implementation-defined component.

The identifier itself remains unchanged.

---

## 8. Step 5 — Extract Local ID

At the destination, the implementation extracts:

```text
bits 0–28
```

For this example:

```text
Local ID = 125000
```

Conceptually:

```text
SMART ID
   │
   └── bits 0–28
            │
            ▼
       Local ID 125000
```

---

## 9. Step 6 — Perform Full Identity Lookup

The lookup identity is:

```text
Engine = 42
Local ID = 125000
```

Conceptually:

```text
(Engine 42, Local ID 125000)
             │
             ▼
       Primary-Key Lookup
             │
             ▼
           Record
```

The complete SMART ID remains the canonical identifier.

---

## 10. Complete Example Flow

The complete operation is:

```text
                         SMART ID
                            │
                            ▼
                    Decode 64-bit value
                            │
                            ▼
                    Extract Engine = 42
                            │
                            ▼
                   Resolve Engine 42
                            │
                            ▼
                    Route to Engine 42
                            │
                            ▼
                  Extract Local ID
                     = 125000
                            │
                            ▼
                 Lookup (42, 125000)
                            │
                            ▼
                         Record
```

---

## 11. Region in This Example

The example includes:

```text
Region = 18
```

Region does not determine the destination.

The routing decision remains:

```text
Engine = 42
```

Therefore:

```text
Region
  │
  └── metadata

Engine
  │
  └── routing
```

Region may be used later for:

* reporting;
* governance;
* historical classification;
* presentation;
* analytics.

---

## 12. State in This Example

The example includes:

```text
State = 1
```

This means:

```text
State = enabled
```

State is not used to determine the Engine destination.

The conceptual sequence is:

```text
SMART ID
   │
   ▼
Engine routing
   │
   ▼
Primary-key lookup
   │
   ▼
State evaluation
```

State can therefore be used as a lifecycle filter after the record is located.

---

## 13. Retired Identifier Example

Suppose the same identity later becomes retired.

The identity remains:

```text
Engine = 42
Local ID = 125000
```

while:

```text
State = 0
```

The conceptual operation becomes:

```text
SMART ID
   │
   ▼
Engine 42
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

The identity has not changed.

---

## 14. Identity Replacement Example

If the application requires a new identity, it does not rewrite the old SMART ID.

Instead:

```text
Old SMART ID
      │
      ▼
Create NEW SMART ID
      │
      ▼
Use NEW identity
      │
      ▼
Retire OLD SMART ID
(State = 0)
```

The old identifier is permanently retired.

It is never reused.

---

## 15. Region Does Not Override Engine

Consider:

```text
Engine = 42
Region = 18
```

The destination is selected from:

```text
Engine = 42
```

not:

```text
Region = 18
```

A different Region value does not automatically change the routing destination.

For example:

```text
Region = 18
Engine = 42
```

and:

```text
Region = 25
Engine = 42
```

still have the same Engine routing value.

The application may interpret the Region metadata differently, but routing semantics remain Engine-based.

---

## 16. Engine Mapping Can Change

The operational destination associated with an Engine can change.

For example:

```text
Before:

Engine 42 → Destination A
```

Later:

```text
After:

Engine 42 → Destination B
```

Existing SMART IDs do not need to change.

The current infrastructure mapping determines the active destination.

This separates immutable identity from infrastructure location.

---

## 17. Example of Infrastructure Movement

Conceptually:

```text
                SMART ID
                   │
                   ▼
               Engine 42
                   │
             Current mapping
                   │
          ┌────────┴────────┐
          ▼                 ▼
   Destination A       Destination B
       before              after
```

The SMART ID remains unchanged.

Only the infrastructure mapping changes.

The implementation must ensure that the ownership and routing state remain authoritative during such transitions.

---

## 18. Engine Ownership

Routing and allocation must respect Engine ownership.

The invariant is:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

For Engine 42:

```text
Engine 42
    │
    ▼
At most one authoritative allocator
```

Two independent allocators must not simultaneously generate identifiers for Engine 42.

---

## 19. Stale Allocator Example

Suppose an old allocator loses ownership of Engine 42.

The unsafe condition would be:

```text
Old allocator ──┐
                ├── Engine 42
New allocator ──┘
```

This must be prevented.

A suitable ownership mechanism may use:

* fencing;
* leases;
* centralized coordination;
* another equivalent mechanism.

If ownership cannot be established safely:

```text
Generation
    │
    ▼
FAIL HARD
```

---

## 20. Routing Does Not Grant Authorization

A SMART ID identifies a resource.

It does not automatically authorize access.

For example:

```text
SMART ID
   │
   ▼
Identify record
```

is separate from:

```text
Authenticated requester
   │
   ▼
Authorization policy
   │
   ▼
Permit / deny operation
```

An implementation must provide appropriate security controls.

---

## 21. Public Identifier Example

An application may expose a public representation separately from its internal identifier.

Conceptually:

```text
Internal SMART ID
       │
       ▼
Optional public transformation
       │
       ▼
API representation
```

If FPE is used:

```text
SMART ID
   │
   ▼
FPE
   │
   ▼
Public representation
```

FPE is a separate cryptographic operation.

It is not part of the routing extraction operation.

---

## 22. FPE Boundary

The following are separate measurements:

```text
FPE processing
      ≠
Engine extraction
      ≠
Database lookup
```

A benchmark that includes all three must explicitly state that it is measuring the combined operation.

SMART ID does not define or require a proprietary FPE algorithm.

Implementations must follow applicable recognized cryptographic standards.

---

## 23. Serialization Example

For API transport, an implementation may represent the 64-bit identifier as a string.

For example:

```json
{
  "id": "1234567890123456789"
}
```

This avoids relying on numeric handling that may not represent every 64-bit integer exactly in common JavaScript environments.

The exact API contract is implementation-specific.

---

## 24. Routing Table Example

An implementation may maintain a logical routing map:

```text
Engine ID    Destination
---------    -----------
0            Service A
1            Service B
2            Service C
...
42           Service Q
...
```

The table is not part of the SMART ID itself.

It is deployment metadata.

SMART ID supplies:

```text
Engine = 42
```

The implementation resolves that value through its own routing infrastructure.

---

## 25. Database Shard Example

An implementation may associate Engine 42 with a database shard:

```text
Engine 42
    │
    ▼
Shard Q
    │
    ▼
Primary-key lookup
```

This is an implementation pattern.

SMART ID does not require sharding.

It only defines the semantics of the Engine field.

---

## 26. Service-Based Example

Alternatively:

```text
Engine 42
    │
    ▼
Service Q
    │
    ▼
Database / storage layer
    │
    ▼
Record
```

Again, the service architecture is implementation-specific.

The SMART ID routing semantics remain unchanged.

---

## 27. Single-Engine Example

In a single-Engine environment:

```text
SMART ID
   │
   ▼
Engine
   │
   ▼
Single destination
   │
   ▼
Local ID
   │
   ▼
Record
```

The same identifier format remains valid.

The deployment simply has one active Engine destination.

---

## 28. Multi-Engine Example

In a multi-Engine environment:

```text
                         SMART ID
                            │
                            ▼
                      Extract Engine
                            │
           ┌────────────────┼────────────────┐
           ▼                ▼                ▼
        Engine 0         Engine 1         Engine 42
           │                │                │
           ▼                ▼                ▼
        Local ID          Local ID         Local ID
           │                │                │
           ▼                ▼                ▼
        Record            Record            Record
```

Each Engine has its own Local ID namespace.

Each Engine must have authoritative ownership.

---

## 29. Genuine Multi-Engine Workload

A genuine multi-engine deployment may use:

```text
Engine 0  ← Writer 0
Engine 1  ← Writer 1
Engine 2  ← Writer 2
...
Engine 15 ← Writer 15
```

Each writer should have independent:

* allocation state;
* transaction stream;
* execution context;
* Engine ownership.

This differs from a single writer that merely changes the Engine field.

---

## 30. Invalid Simulated Multi-Engine Example

The following does **not** automatically represent a genuine multi-engine workload:

```text
Single writer
     │
     ├── Engine 0
     ├── Engine 1
     ├── Engine 2
     ├── ...
     └── Engine 15
```

This may test value distribution.

It does not reproduce independent concurrent Engine authorities.

The existing invalid experiment is documented in:

`research/FINDINGS_MULTI_ENGINE_INVALID.md`

---

## 31. Local ID Namespace

Each Engine has a 29-bit Local ID namespace:

```text
2^29
=
536,870,912
```

Therefore:

**536,870,912 identifiers per Engine.**

The namespace is finite.

It must not wrap around.

---

## 32. Local ID Exhaustion

Conceptually:

```text
Local ID allocation
        │
        ▼
Namespace exhausted
        │
        ▼
FAIL HARD
```

The implementation must not allocate an already-used Local ID.

The operational recovery mechanism is outside the identifier format.

A client/control plane may obtain another Engine if appropriate.

---

## 33. Local ID Gaps

Gaps are allowed.

For example:

```text
Allocated:

1000
1001
1002
1003
1004

Failure

1005
1006
```

The implementation may resume later at:

```text
1007
```

The unused or abandoned values remain consumed.

The objective is uniqueness and non-reuse, not gaplessness.

---

## 34. Crash Recovery Example

Suppose a batch is reserved:

```text
1000–1099
```

and the allocator fails after reserving it.

The implementation may later continue from:

```text
1100
```

rather than attempting to reuse the abandoned range.

This preserves non-reuse.

---

## 35. Batch Allocation

A client may allocate Local IDs in batches:

```text
Engine 42
    │
    ▼
Reserve batch
    │
    ├── 1000
    ├── 1001
    ├── 1002
    └── ...
```

The exact batch size is an implementation choice.

Batch allocation must preserve:

* uniqueness;
* persistence;
* monotonicity within the allocation stream;
* non-reuse;
* correct failure behavior.

---

## 36. Persistence

Local ID allocation state must survive process restarts.

Conceptually:

```text
Allocator
   │
   ▼
Persistent allocation state
   │
   ▼
Restart
   │
   ▼
Continue without reuse
```

The persistence mechanism is implementation-specific.

---

## 37. Concurrent Allocation

Where multiple workers share an Engine allocation domain, the implementation must prevent duplicate Local IDs.

Possible mechanisms include:

* row-level locking;
* serialized allocation;
* atomic database operations;
* another equivalent concurrency mechanism.

The specific mechanism is not mandated by SMART ID.

The uniqueness invariant is mandatory.

---

## 38. Control Application

A client may use a centralized control application:

```text
                    Control Application
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
       Engine 0         Engine 1         Engine 42
          │                │                │
          ▼                ▼                ▼
       Allocator         Allocator         Allocator
```

This is an implementation choice.

SMART ID does not require centralized control.

---

## 39. Distributed Control Plane

Alternatively, an implementation may use distributed coordination:

```text
Coordinator A
      │
      ├── Engine ownership
      │
Coordinator B
      │
      └── Engine ownership
```

The architecture must still guarantee:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

The mechanism may differ.

The invariant does not.

---

## 40. Routing During Control-Plane Failure

If the control plane cannot establish safe ownership, new identifier generation should fail.

Existing identifiers can remain routable according to the deployment's routing infrastructure if their destination remains available.

Conceptually:

```text
Existing identity
      │
      ▼
Routing
      │
      ▼
Record

New generation
      │
      ▼
Ownership unavailable
      │
      ▼
FAIL HARD
```

This separates routing of existing identities from safe allocation of new identities.

---

## 41. Engine Rotation Example

A deployment may rotate allocation across Engines:

```text
Time →
Engine 0 → Engine 1 → Engine 2 → Engine 3
```

This can distribute future write activity.

Existing identifiers remain associated with their original Engine.

---

## 42. Static Assignment

A deployment should not rely on an indefinitely static Engine assignment if its operational strategy requires Engine rotation.

The exact rotation policy is implementation-specific.

The SMART ID requirement is that each generated identifier has an authoritative Engine.

---

## 43. Identity Comparison

Two SMART IDs can be compared by their complete identity.

Conceptually:

```text
ID A:
Engine = 42
Local ID = 125000

ID B:
Engine = 42
Local ID = 125001
```

These are different identities because the Local IDs differ.

Similarly:

```text
ID A:
Engine = 42
Local ID = 125000

ID B:
Engine = 43
Local ID = 125000
```

These are different identities because the Engines differ.

---

## 44. Metadata Comparison

Metadata can differ independently of identity semantics.

For example, Region may have different governance interpretation.

State may change through lifecycle.

Version identifies the format.

These comparisons should not be confused with identity comparison.

---

## 45. Routing Correctness Test

A conceptual test may use:

```text
Expected Engine = 42
Expected Local ID = 125000
```

Then verify:

```text
Extracted Engine == 42
Extracted Local ID == 125000
```

The test should also verify that:

```text
Region
State
Reserved
Version
```

do not unexpectedly change Engine or Local ID extraction.

---

## 46. Example Test Matrix

| Test                                         | Expected Result      |
| -------------------------------------------- | -------------------- |
| Same Engine, different Local ID              | Different identity   |
| Different Engine, same Local ID              | Different identity   |
| Same identity, State changes                 | Same identity        |
| Same identity, Region interpretation changes | Same identity        |
| Reserved bits non-zero in v1.x               | Invalid v1.x value   |
| Version 0                                    | v1.x                 |
| Version 1                                    | Reserved for v2      |
| Local ID exhausted                           | FAIL HARD            |
| Ambiguous Engine ownership                   | Generation FAIL HARD |

---

## 47. Full Conceptual Request

A complete request might be:

```text
Client
  │
  ▼
API
  │
  ▼
SMART ID
  │
  ▼
Parse identifier
  │
  ▼
Extract Engine
  │
  ▼
Resolve Engine destination
  │
  ▼
Route request
  │
  ▼
Extract Local ID
  │
  ▼
Primary-key lookup
  │
  ▼
Evaluate lifecycle
  │
  ▼
Authorization / application policy
  │
  ▼
Response
```

The exact ordering of application-specific security and policy checks may differ.

The example illustrates the logical separation of concerns.

---

## 48. Routing Performance

A routing implementation may benchmark:

```text
Field extraction
+
Routing decision
```

Separately, it may benchmark:

```text
Database lookup
```

And separately:

```text
FPE
```

These should not be presented as one universal SMART ID performance number.

---

## 49. CPU Cycle Claims

A benchmark may measure CPU cycles for Engine extraction.

For example:

```text
Processor X
Compiler Y
Implementation Z
Measured result
```

That is an environment-specific measurement.

It must not become a universal specification statement such as:

```text
"SMART ID routing always takes N cycles."
```

Actual execution depends on implementation and hardware.

---

## 50. Database Example

Suppose Engine 42 maps to a database shard:

```text
Engine 42
    │
    ▼
Database Shard Q
    │
    ▼
Primary key:
(Engine, Local ID)
    │
    ▼
Record
```

The exact database schema is implementation-specific.

The conceptual identity remains:

```text
Engine + Local ID
```

---

## 51. Secondary Index Example

An application may maintain a secondary index on lifecycle state:

```text
State = 1
```

for enabled records.

The conceptual query path could be:

```text
Application query
    │
    ▼
Lifecycle index
    │
    ▼
Candidate records
```

This does not change the SMART ID routing path.

State remains lifecycle metadata.

---

## 52. Region Query Example

An application may query by Region:

```text
Region = 18
```

This is an application or governance query.

It is not equivalent to:

```text
Route to Region 18
```

unless the application separately defines such infrastructure behavior.

SMART ID itself does not define Region as a routing selector.

---

## 53. Historical Query Example

A system may retain:

```text
SMART ID
Region
State
Generation timestamp
```

for historical reporting.

This can help answer questions such as:

* where the identifier was classified at generation;
* whether it is currently retired;
* which format version generated it.

The identifier itself remains immutable.

---

## 54. Public API Example

A conceptual API response may contain:

```json
{
  "id": "1234567890123456789",
  "state": "enabled"
}
```

The string representation is an API choice.

The API may expose additional application metadata.

Those additional fields do not become part of the SMART ID specification.

---

## 55. Security Example

A request may contain:

```text
SMART ID = identifier
Access token = authentication
Authorization policy = permission
```

These are separate concepts.

A valid SMART ID should not be treated as proof of requester identity or permission.

---

## 56. Invalid Assumption Example

Incorrect assumption:

```text
Region = destination
```

Correct v1.4 interpretation:

```text
Region = metadata
Engine = routing field
```

---

## 57. Invalid Assumption Example — State

Incorrect:

```text
State = 0
   │
   ▼
Route somewhere else
```

Correct:

```text
State = 0
   │
   ▼
Retired / disabled lifecycle state
```

Routing remains Engine-based.

---

## 58. Invalid Assumption Example — FPE

Incorrect:

```text
FPE speed = SMART ID routing speed
```

Correct:

```text
FPE
   │
   └── separate cryptographic operation

SMART extraction
   │
   └── separate identifier operation
```

---

## 59. Invalid Assumption Example — Multi-Engine

Incorrect:

```text
One writer
+
Engine = row_index % 16
=
16-engine benchmark
```

Correct:

```text
16 authoritative Engines
+
16 independent writers
+
16 independent allocation streams
=
genuine multi-engine workload
```

---

## 60. Conceptual Summary

The routing example can be reduced to:

```text
SMART ID
   │
   ▼
Engine
   │
   ▼
Destination
   │
   ▼
Local ID
   │
   ▼
Full identity lookup
   │
   ▼
Record
```

And the semantic boundaries are:

```text
Engine
  → routing

Engine + Local ID
  → identity

Region
  → metadata

State
  → lifecycle

Reserved
  → future governance

Version
  → format generation
```

---

## 61. Non-Normative Notice

This document is an illustrative example.

It does not:

* define a new SMART ID requirement;
* mandate a database architecture;
* mandate a routing product;
* mandate a control-plane topology;
* define an API contract;
* define an authentication system;
* define an authorization system;
* define a cryptographic algorithm.

Where this example conflicts with the normative v1.4 specification, the normative specification takes precedence.

---

## 62. Final Example

A complete conceptual lookup can therefore be represented as:

```text
┌──────────────────────────┐
│       SMART 64-Bit ID    │
└────────────┬─────────────┘
             │
             ▼
      Extract Engine
       bits 29–49
             │
             ▼
      Engine destination
             │
             ▼
      Extract Local ID
        bits 0–28
             │
             ▼
   Engine + Local ID
             │
             ▼
    Primary-Key Lookup
             │
             ▼
          Record
             │
             ▼
     Lifecycle / Policy
```

This example demonstrates the v1.4 routing model without prescribing a particular implementation.

---

## 63. Conclusion

SMART 64-Bit ID provides a fixed-position identity and routing structure.

For the example identifier:

```text
Engine = 42
Local ID = 125000
```

the routing decision is determined by Engine 42, followed by lookup using the complete Engine + Local ID identity.

Region remains metadata.

State remains lifecycle information.

Reserved bits remain reserved.

Version remains a format marker.

Control-plane architecture, routing infrastructure, storage technology, security architecture, and cryptographic implementation remain implementation choices subject to the v1.4 requirements.

**This example is non-normative and does not modify the SMART ID Technical Specification v1.4.**
