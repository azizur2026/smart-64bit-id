# SMART 64-Bit ID — Generation Example

**Example Document — Non-Normative**
**Technical Specification:** v1.4
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document provides a conceptual example of how a SMART 64-Bit ID can be generated.

It explains the relationship between Engine ownership, Local ID allocation, field assembly, persistence, lifecycle state, and return of the generated identifier.

This document is an example only. It does not define an alternative architecture and does not replace the normative requirements in the SMART ID Technical Specification v1.4.

---

## 2. Non-Normative Status

The examples in this document are illustrative.

They are intended to explain the v1.4 generation model without prescribing a particular programming language, database, deployment topology, control-plane architecture, or infrastructure platform.

Implementations remain responsible for satisfying the normative SMART ID requirements.

---

## 3. Core Generation Model

A conceptual SMART ID generation sequence is:

```text
Authoritative Engine ownership
        ↓
Local ID allocation
        ↓
SMART ID field assembly
        ↓
Persistence / commit
        ↓
Return SMART ID
```

The important property is that identity allocation must occur under an authoritative Engine ownership model and that an allocated Local ID must never later be reused.

---

## 4. Generation Inputs

A conceptual generation operation may involve:

* an authoritative Engine ID;
* a Local ID allocator associated with that Engine;
* a Region metadata value;
* a State value;
* Reserved bits;
* the SMART ID Version value;
* persistence state;
* concurrency-control state; and
* the application operation requesting an identifier.

Not every implementation needs to expose these values directly to the calling application.

---

## 5. Example Parameters

Consider the following conceptual values:

```text
Engine   = 42
Local ID = 125000
Region   = 18
State    = 1
Reserved = 0
Version  = 0
```

The resulting identifier is assembled according to the fixed v1.4 bit layout.

The exact decimal representation is an encoding result and does not change the meaning of the individual fields.

---

## 6. Step One — Establish Engine Ownership

Before generating Local IDs, the implementation must have an authoritative ownership state for the Engine.

For example:

```text
Engine 42
    ↓
Authoritative allocator
    ↓
Generation permitted
```

The implementation may use a centralized allocator, lease, fencing mechanism, coordination service, database mechanism, or another suitable design.

SMART ID does not mandate which mechanism must be used.

---

## 7. One Authoritative Allocator

The fundamental invariant is:

> At any time, an Engine ID MUST have at most one authoritative active allocator.

For example:

```text
Engine 42
    │
    ├── Allocator A → authoritative
    │
    └── Allocator B → not authoritative
```

Only the authoritative allocator may generate new Local IDs for Engine 42.

---

## 8. Concurrent Ownership Is Not Permitted

An unsafe situation would be:

```text
Engine 42
    ├── Allocator A → active
    └── Allocator B → active
```

If both authorities can independently allocate Local IDs for the same Engine namespace, uniqueness can no longer be guaranteed.

Generation must therefore fail until ownership is unambiguously established.

---

## 9. Stale Ownership

A stale allocator can remain dangerous after a failure, network partition, process restart, or ownership transition.

For example:

```text
Old allocator
    ↓
Engine 42
    ↓
ownership lost

New allocator
    ↓
Engine 42
    ↓
ownership acquired
```

The old allocator must not continue generating identifiers merely because it still possesses locally cached state.

A fencing or equivalent mechanism may be used to prevent stale ownership.

---

## 10. Fencing Is an Implementation Choice

Fencing is a useful implementation technique, but SMART ID does not prescribe a particular fencing technology.

Possible mechanisms include:

* leases;
* epochs;
* ownership tokens;
* generation numbers;
* transactional ownership records;
* coordination services; or
* equivalent mechanisms.

The requirement is the ownership invariant, not a particular implementation.

---

## 11. Generation Failure on Ownership Ambiguity

If the implementation cannot determine which allocator is authoritative, generation must not continue.

Conceptually:

```text
Ownership known
    → continue

Ownership ambiguous
    → FAIL HARD
```

This protects the identity namespace from conflicting allocation.

---

## 12. Existing IDs Are Not Re-Routed by Ownership Changes

Changing the authoritative allocator for an Engine does not change previously generated identifiers.

For example:

```text
Engine 42
    ↓
Allocator A
    ↓
SMART IDs already generated

Allocator A retires
    ↓
Allocator B becomes authoritative
    ↓
Engine 42 continues from persistent allocation state
```

The existing identity values remain unchanged.

---

## 13. Step Two — Load Persistent Local Allocation State

Once authoritative Engine ownership is established, the allocator obtains the persistent Local ID allocation state for that Engine.

Conceptually:

```text
Engine 42
    ↓
Persistent Local-ID state
    ↓
Next available allocation position
```

The persistent state must survive normal process restarts and other expected recovery events.

---

## 14. Local ID Namespace

The Local ID occupies 29 bits.

Therefore:

```text
2^29 = 536,870,912
```

The namespace provides:

**536,870,912 identifiers per Engine.**

This capacity is finite.

---

## 15. Local ID Monotonicity

Local IDs are allocated monotonically within an Engine namespace.

A conceptual sequence is:

```text
124997
124998
124999
125000
125001
125002
```

The exact externally visible ordering of completed application operations may depend on transaction and commit behavior.

The allocation rule itself remains monotonic within the Engine allocation state.

---

## 16. Gaps Are Acceptable

SMART ID does not require gapless allocation.

For example:

```text
125000
125001
125002
[allocation reserved]
[process failure]
125005
```

The unused values do not need to be recovered.

Correctness is based on uniqueness and non-reuse, not on eliminating every numerical gap.

---

## 17. Why Gaps Are Accepted

Attempts to guarantee a completely gapless distributed identifier sequence can create additional coordination requirements and failure dependencies.

SMART ID prioritizes:

1. uniqueness;
2. non-reuse;
3. persistence;
4. correct ownership; and
5. failure safety.

Gaplessness is not a requirement.

---

## 18. Batch Allocation

Implementations may allocate Local IDs in batches.

For example:

```text
Engine 42
    ↓
Reserve 1,000 Local IDs
    ↓
125000–125999
```

The allocator may then issue individual identifiers from that reserved range.

Batch allocation can reduce allocation coordination overhead.

---

## 19. Batch Reservation and Failure

Suppose an allocator reserves:

```text
125000–125999
```

and then fails after using only:

```text
125000–125124
```

The remaining values do not need to be reused.

A subsequent allocation may begin after the reserved range.

This creates a gap but preserves non-reuse.

---

## 20. Randomized Non-Zero Starting Position

An implementation may choose to start Local ID allocation from a randomized non-zero position.

For example:

```text
Local ID start = 37,421
```

instead of:

```text
Local ID start = 0
```

This is an optional implementation behavior.

---

## 21. Namespace Cost of Randomized Starting

A randomized starting position consumes part of the finite Local ID namespace.

Therefore, an implementation using this technique should account for the reduced remaining range.

Randomization does not increase the total capacity of the 29-bit field.

---

## 22. Step Three — Check Local ID Exhaustion

Before allocating a new Local ID, the implementation must ensure that capacity remains.

The maximum number of Local IDs per Engine is:

```text
536,870,912
```

Once the namespace is exhausted, the allocator must not wrap around.

---

## 23. Exhaustion Behavior

Conceptually:

```text
Local ID capacity available
    → allocate

Local ID capacity exhausted
    → FAIL HARD
```

The allocator must not silently generate a duplicate by restarting from zero.

---

## 24. No Wraparound

An unsafe implementation would behave like:

```text
536,870,911
    ↓
0
```

after reaching the end of the namespace.

SMART ID does not permit this behavior.

The namespace is finite and must not wrap.

---

## 25. No Reuse

Previously allocated Local IDs must never be reused within the same Engine namespace.

This remains true even when:

* an application record is deleted;
* a transaction is rolled back after allocation;
* an allocator restarts;
* a service is redeployed;
* an Engine changes ownership; or
* a previously allocated identifier is no longer actively referenced.

---

## 26. Deletion Does Not Recycle Identity

Suppose:

```text
Engine = 42
Local ID = 125000
```

is associated with a record that is later deleted.

The pair:

```text
Engine 42 + Local ID 125000
```

must not be returned to the allocation pool.

The identifier remains permanently consumed.

---

## 27. Rollback Does Not Require Reuse

Suppose an application transaction obtains:

```text
Local ID = 125001
```

but a later operation fails.

The implementation does not need to return 125001 to the allocator.

The next successful allocation may therefore be:

```text
125002
```

The resulting gap is acceptable.

---

## 28. Crash Recovery

Crash recovery must preserve the non-reuse rule.

Consider:

```text
Allocator
    ↓
allocates Local ID
    ↓
process crashes
```

After recovery, the implementation must not accidentally regenerate the same Local ID.

Persistent allocation state must therefore be designed so that allocated identifiers cannot be unknowingly reissued.

---

## 29. Persistence Requirement

The Local ID allocation state must be persistent across normal restarts.

Conceptually:

```text
Runtime memory
      ↓
Persistent allocation state
      ↓
Restart
      ↓
Recover next safe allocation position
```

An implementation must not rely only on volatile process memory for identity allocation.

---

## 30. Concurrency

Where multiple execution paths can allocate from the same persistent state, concurrency control is required.

Possible mechanisms include:

* row-level locking;
* transactional allocation;
* atomic database operations;
* serialized allocator state;
* distributed coordination; or
* another equivalent mechanism.

The specific mechanism is implementation-dependent.

---

## 31. Concurrent Local Allocation

An unsafe pattern would be:

```text
Worker A → reads 125000
Worker B → reads 125000

Worker A → returns 125000
Worker B → returns 125000
```

This creates duplicate identity.

A correct implementation ensures that only one allocation operation obtains each Local ID.

---

## 32. Atomic Allocation Concept

A conceptual safe sequence is:

```text
Read allocation state
        ↓
Atomically reserve next value
        ↓
Persist updated state
        ↓
Return allocated Local ID
```

The actual implementation may combine these operations into a database transaction or another atomic mechanism.

---

## 33. Step Four — Assemble the SMART ID

After obtaining a valid Engine and Local ID, the implementation assembles the complete 64-bit identifier.

The v1.4 layout is:

```text
Bits  0–28   Local ID   29 bits
Bits 29–49   Engine     21 bits
Bits 50–57   Region      8 bits
Bit     58   State       1 bit
Bits 59–62   Reserved    4 bits
Bit     63   Version     1 bit
```

---

## 34. Identity Core

The immutable identity core is:

```text
Local ID + Engine
```

Together:

```text
29 bits + 21 bits = 50 bits
```

The identity core provides the unique namespace represented by the Engine and Local ID combination.

---

## 35. Governance and Metadata

The remaining 14 bits are:

```text
Region   = 8 bits
State    = 1 bit
Reserved = 4 bits
Version  = 1 bit
```

These fields provide metadata, lifecycle, reserved capacity, and format-version information.

They are not substitutes for the identity core.

---

## 36. Region at Generation Time

Region is generation-time metadata.

For example:

```text
Region = 18
```

may represent the classification applicable when the identifier was generated.

Region is not part of the identity core.

---

## 37. Region Is Not a Routing Selector

Generation does not use Region to determine the destination Engine.

The Engine field provides the routing identity.

Conceptually:

```text
SMART ID
    ↓
Engine
    ↓
Routing
```

not:

```text
SMART ID
    ↓
Region
    ↓
Routing
```

---

## 38. Region Remapping

An implementation may need to present a different regional classification for governance or reporting purposes.

Such remapping does not change the immutable identity core.

Historical interpretation may retain the original generation-time Region value.

---

## 39. State at Generation

A newly generated active identifier normally uses:

```text
State = 1
```

where State 1 represents enabled.

State is a lifecycle marker.

It is not a routing selector.

---

## 40. Retiring an Identifier

If an identity must be permanently retired, the existing identifier can transition to:

```text
State = 0
```

where State 0 represents retired or disabled.

The old identifier is not returned to the allocation pool.

---

## 41. Identity Replacement

If a transferred object or lifecycle event requires a new identifier, the conceptual sequence is:

```text
Create NEW SMART ID
        ↓
Associate new identity
        ↓
Retire OLD SMART ID
        ↓
State(old) = 0
```

The old identity remains permanently retired.

---

## 42. Reserved Bits

The v1.4 Reserved field contains four bits.

The current conceptual value is:

```text
Reserved = 0
```

Implementations should not assign private meanings to these bits in a way that conflicts with future specification governance.

---

## 43. Version

The v1.4 format uses:

```text
Version = 0
```

Version 0 represents the v1.x format family.

The Version field provides a mechanism for future format evolution.

---

## 44. Step Five — Persist the Identifier

After field assembly, the implementation persists the identity according to its application design.

A conceptual sequence is:

```text
Generate
   ↓
Persist
   ↓
Commit
   ↓
Return
```

The persistence model may differ between implementations.

---

## 45. Persistence and Uniqueness

The persistence layer should enforce or otherwise reliably maintain the uniqueness of the SMART identity.

A duplicate Engine + Local ID combination is not an acceptable normal condition.

If a duplicate is detected as a violation of the identity allocation invariant, generation must fail hard rather than silently replacing one identity with another.

---

## 46. Full Identity Key

The identity represented by:

```text
Engine = 42
Local ID = 125000
```

is the combination of both values.

Conceptually:

```text
Engine 42
    +
Local ID 125000
    =
SMART identity core
```

Neither field alone represents the complete identity.

---

## 47. Generation Does Not Depend on Routing

Routing and generation are related but separate operations.

Generation creates the identifier.

Routing later interprets the Engine field.

Conceptually:

```text
Generation
    ↓
SMART ID
    ↓
Routing
```

The routing process does not generate the identifier.

---

## 48. Generation Does Not Grant Authorization

Possessing a SMART ID does not establish permission to access the corresponding resource.

Authorization remains an application and security concern.

Conceptually:

```text
SMART ID
    ≠
Authorization
```

An application must independently authenticate and authorize requests.

---

## 49. Cryptography Is Not Required for Core Assembly

The SMART ID bit layout does not require proprietary cryptography to assemble the internal identifier.

The identifier can be constructed according to the fixed field layout.

Cryptographic processing, where needed, is a separate implementation concern.

---

## 50. Public Identifier Transformation

An application may expose a transformed public representation of an internal SMART ID.

For example:

```text
Internal SMART ID
       ↓
Optional FPE
       ↓
Public representation
```

This transformation is separate from the internal identity-generation process.

---

## 51. FPE Boundary

Format-preserving encryption does not replace the SMART identity model.

It is a public-ID processing mechanism that may be used when an implementation requires a transformed representation.

FPE is not authentication, authorization, or integrity protection.

---

## 52. Security Boundary

The SMART ID specification defines identifier semantics.

It does not define an application's complete security architecture.

Implementations remain responsible for:

* authentication;
* authorization;
* key management;
* integrity protection;
* secure transport;
* access control;
* credential management; and
* operational security.

---

## 53. String Serialization

SMART IDs should be serialized as strings in JSON and similar external interfaces.

For example:

```json
{
  "id": "1234567890123456789"
}
```

This avoids relying on numeric parsing behavior that may not safely represent all 64-bit integer values in environments with lower-precision numeric types.

---

## 54. Internal Numeric Representation

An implementation may use a native 64-bit integer internally when the platform provides reliable support.

The external representation should not assume that every application environment can safely represent an arbitrary unsigned 64-bit value as a generic floating-point number.

---

## 55. Generation and API Response

A conceptual API sequence might be:

```text
Client request
      ↓
Generation service
      ↓
Validate authoritative Engine ownership
      ↓
Allocate Local ID
      ↓
Assemble SMART ID
      ↓
Persist
      ↓
Return string representation
```

The actual API architecture is implementation-dependent.

---

## 56. Control-Plane Architecture Is Not Prescribed

SMART ID does not require a centralized control application.

A client may choose:

```text
Centralized allocation
```

or:

```text
Distributed allocation with ownership coordination
```

or another architecture that satisfies the required invariants.

The responsibility remains with the client to guarantee authoritative, non-conflicting Engine ownership.

---

## 57. Centralized Example

A conceptual centralized arrangement could be:

```text
Applications
      ↓
Control application
      ↓
Engine allocation
      ↓
Engine-specific Local allocation
      ↓
SMART ID
```

This can be practical, but it is not a SMART ID architectural requirement.

---

## 58. Distributed Example

A conceptual distributed arrangement could be:

```text
Allocator A → Engine 1
Allocator B → Engine 2
Allocator C → Engine 3
```

Each Engine has a single authoritative active allocator.

Ownership coordination prevents two active authorities from independently generating the same Engine namespace.

---

## 59. Engine Rotation

Engine rotation may be used to distribute allocation activity and write patterns.

For example:

```text
Engine 41
    ↓
allocation period

Engine 42
    ↓
allocation period

Engine 43
    ↓
allocation period
```

Rotation policy is an implementation and operational decision.

Static Engine assignment is not the intended allocation strategy where Engine rotation is required to distribute writes.

---

## 60. Existing Engine State During Rotation

When an Engine is rotated out of active allocation, existing identifiers remain valid.

For example:

```text
Engine 41
    ↓
no longer receiving new allocations

Existing Engine 41 IDs
    ↓
remain valid identities
```

Rotation does not rewrite historical identifiers.

---

## 61. Local Exhaustion and Operational Response

If an Engine reaches the end of its Local ID namespace:

```text
Engine 42
    ↓
Local namespace exhausted
    ↓
FAIL HARD
```

The operational response may include obtaining another Engine ID or applying another control-plane policy.

SMART ID does not prescribe the client's operational recovery architecture.

---

## 62. Control-Plane Failure

If the control plane cannot establish authoritative Engine ownership, new generation may need to stop.

For example:

```text
Ownership service unavailable
        ↓
New allocation cannot be safely authorized
        ↓
Generation fails
```

Existing SMART IDs do not become invalid merely because the control plane is temporarily unavailable.

---

## 63. Routing During Generation-Service Failure

Generation and routing have different availability properties.

An implementation may continue routing already-created identifiers even when new ID generation is temporarily unavailable, provided the routing and storage systems remain operational.

Conceptually:

```text
New generation
    → unavailable

Existing ID routing
    → may remain available
```

The exact availability behavior depends on the deployment architecture.

---

## 64. Failure of Persistent Allocation State

If the implementation cannot safely establish the next Local ID allocation position, it must not guess.

An unsafe response would be:

```text
Persistent state unavailable
    ↓
Guess next Local ID
```

A safe conceptual response is:

```text
Persistent state unavailable
    ↓
Generation fails
```

This protects the non-reuse invariant.

---

## 65. Failure of Uniqueness Guarantee

If an implementation detects that uniqueness can no longer be guaranteed, it must stop generation rather than continue with potentially conflicting identifiers.

Conceptually:

```text
Uniqueness guaranteed
    → continue

Uniqueness uncertain
    → FAIL HARD
```

---

## 66. Failure Priority

The generation model prioritizes correctness over availability.

The simplified principle is:

```text
Duplicate identity
    = unacceptable

Temporary generation failure
    = acceptable
```

A temporary inability to generate an identifier is preferable to knowingly generating a conflicting identity.

---

## 67. Example: Successful Generation

Consider:

```text
Engine ownership = valid
Local state       = persistent
Next Local ID     = 125000
Region             = 18
State              = 1
Reserved           = 0
Version            = 0
```

The conceptual process is:

```text
1. Confirm Engine 42 ownership.
2. Allocate Local ID 125000.
3. Persist allocation state.
4. Assemble all v1.4 fields.
5. Persist the resulting identity.
6. Commit the operation.
7. Return the SMART ID.
```

---

## 68. Example: Ownership Failure

Suppose two allocators both believe they own Engine 42.

```text
Allocator A → claims Engine 42
Allocator B → claims Engine 42
```

The correct response is not to select one arbitrarily during generation.

Instead:

```text
Ownership ambiguity
        ↓
FAIL HARD
        ↓
Resolve authoritative ownership
        ↓
Resume generation
```

---

## 69. Example: Local Exhaustion

Suppose Engine 42 has consumed its complete 29-bit namespace.

The next generation request encounters:

```text
Local ID capacity = exhausted
```

The allocator must not:

```text
wrap to 0
```

or:

```text
reuse an old Local ID
```

Instead:

```text
FAIL HARD
```

The client control plane can then determine an operational response.

---

## 70. Example: Crash After Allocation

Suppose:

```text
Local ID 125000
```

has been allocated and persistent state has advanced, but the application process crashes before completing its higher-level operation.

After restart, the implementation must not issue:

```text
125000
```

again.

The next safe allocation must reflect the persistent state.

A gap is acceptable.

---

## 71. Example: Crash During Batch Allocation

Suppose an implementation reserves:

```text
125000–125999
```

and crashes after successfully using only:

```text
125000–125050
```

The remaining reserved values may be abandoned.

The next allocation can begin after the reserved range.

This behavior preserves non-reuse.

---

## 72. Example: Record Deletion

Suppose:

```text
Engine = 42
Local ID = 125000
```

is associated with an application record.

If the application later deletes that record, the Local ID is not recycled.

The namespace remains consumed.

---

## 73. Example: Lifecycle Retirement

Suppose an identity must be retired.

The conceptual process is:

```text
Existing SMART ID
        ↓
State = 0
        ↓
Permanently retired
```

If a new identity is required:

```text
Generate NEW SMART ID
        ↓
Associate new identity
        ↓
Retire old identity
```

---

## 74. Example: Region Metadata

Suppose:

```text
Region = 18
```

at generation time.

Later governance systems may classify the resource differently.

That does not change:

```text
Engine
Local ID
```

The identity core remains immutable.

---

## 75. Example: Version Handling

A v1.x implementation generates:

```text
Version = 0
```

An implementation encountering an unsupported future Version value should follow its compatibility and protocol handling policy rather than silently interpreting it as a different v1.x format.

Versioning is part of format governance.

---

## 76. Example: Reserved Bits

For v1.4:

```text
Reserved = 0
```

The implementation should not depend on an unofficial private meaning for these bits.

Future specification versions may assign formal semantics.

---

## 77. Generation Versus Allocation

It is useful to distinguish:

```text
Engine allocation
```

from:

```text
Local ID allocation
```

Engine allocation determines which namespace is authoritative.

Local ID allocation consumes a unique position within that namespace.

The two operations solve different problems.

---

## 78. Engine Uniqueness

The Engine namespace contains:

```text
2^21 = 2,097,152
```

possible Engine values.

An Engine ID must not be concurrently and authoritatively allocated to multiple active allocators.

The total Engine namespace is therefore a finite governance resource.

---

## 79. Local Capacity Per Engine

Each Engine provides:

```text
2^29
```

Local ID positions.

Therefore:

```text
536,870,912
```

identifiers are available per Engine before exhaustion.

This capacity does not increase through reuse.

---

## 80. The Combined Identity Space

The identity core contains:

```text
21 Engine bits
+
29 Local ID bits
=
50 bits
```

Therefore the theoretical identity-core space is:

```text
2^50
=
1,125,899,906,842,624
```

possible Engine + Local ID combinations.

This is the theoretical namespace size, not a promise that every deployment will consume or expose the entire space.

---

## 81. Metadata Does Not Increase Identity Capacity

Region, State, Reserved, and Version are outside the 50-bit identity core.

Changing these fields does not create new immutable identity positions.

For example:

```text
Same Engine + Local ID
Region 18
```

and:

```text
Same Engine + Local ID
Region 19
```

do not represent two different identity-core positions.

---

## 82. Generation Ordering

The generation sequence should not be confused with application commit ordering.

For example:

```text
Local ID 125000 allocated first
Local ID 125001 allocated second
```

does not necessarily guarantee that the application record associated with 125000 becomes externally visible before the record associated with 125001.

Transaction scheduling and commit behavior can affect observable ordering.

---

## 83. Batch Ordering

With batch allocation:

```text
Batch A → 125000–125999
Batch B → 126000–126999
```

individual application operations may complete in a different order.

The identity values remain valid because uniqueness and non-reuse do not depend on commit-order serialization.

---

## 84. Generation Is Not Gapless Sequencing

SMART ID should therefore not be interpreted as a globally gapless sequence.

It is an immutable identity allocation system with:

* Engine namespaces;
* Local ID allocation;
* persistence;
* non-reuse;
* bounded capacity; and
* explicit failure semantics.

---

## 85. Generation and Routing Relationship

A generated SMART ID can later be routed by extracting its Engine field.

Conceptually:

```text
Generation
    ↓
[Engine + Local + Metadata]
    ↓
SMART ID
    ↓
Extract Engine
    ↓
Route
    ↓
Extract Local ID
    ↓
Full lookup
```

The same immutable identity is therefore useful for both generation and deterministic routing.

---

## 86. Generation and Database Lookup

A database implementation may store the complete SMART ID as a primary key.

Conceptually:

```text
SMART ID
    ↓
Primary-key index
    ↓
Record
```

The database technology is not prescribed by SMART ID.

---

## 87. Internal and Public Identity

An implementation may maintain:

```text
Internal database identity
        +
SMART public identifier
```

or may use SMART ID directly as its primary identity.

The choice depends on application requirements.

---

## 88. Dual-ID Pattern

A conceptual dual-ID design might be:

```text
Internal PK
    ↓
Database operations

SMART ID
    ↓
External references
```

The two identifiers can serve different operational purposes.

This is an integration pattern, not a requirement of the SMART ID specification.

---

## 89. Public-ID Exposure

If SMART ID is exposed externally, the implementation should consider whether direct exposure is appropriate for its application.

Possible considerations include:

* enumeration concerns;
* information disclosure;
* API design;
* access control;
* authorization;
* public-ID transformation; and
* rate limiting.

These concerns belong to application security architecture.

---

## 90. FPE Is Not Identity Allocation

A public-ID FPE layer does not allocate Engine or Local IDs.

The conceptual separation is:

```text
SMART generation
        ↓
Internal SMART ID
        ↓
Optional public representation
```

The FPE mechanism must not be confused with the identity-generation mechanism.

---

## 91. Standards Boundary

SMART ID implementations that use FPE and related cryptographic mechanisms must use them in accordance with applicable internationally recognized and approved cryptographic standards and their current authoritative revisions.

SMART ID does not define or require a proprietary cryptographic algorithm.

The actual cryptographic implementation remains an implementation responsibility.

---

## 92. Security Does Not Change Generation Semantics

Adding authentication, authorization, encryption, or other security mechanisms does not change the core allocation rules.

The implementation still must maintain:

```text
Authoritative Engine ownership
        +
Unique Local allocation
        +
Persistence
        +
Non-reuse
        +
Correct field assembly
```

---

## 93. Generation Test Scenario

A conceptual generation test may verify:

```text
1. Engine ownership is established.
2. Local allocation state is persistent.
3. A Local ID is allocated.
4. The allocation cannot be duplicated concurrently.
5. The SMART fields are assembled correctly.
6. The identifier is persisted.
7. The returned identifier matches the persisted identity.
```

---

## 94. Restart Test

A conceptual restart test can verify:

```text
Generate ID
    ↓
Restart allocator
    ↓
Generate another ID
```

The second generation must not reuse the first Local ID.

---

## 95. Concurrent Allocation Test

A conceptual concurrency test can run multiple allocation requests against one authoritative Engine.

The expected property is:

```text
N successful allocations
        ↓
N distinct Local IDs
```

No two successful allocations may return the same Engine + Local ID identity.

---

## 96. Ownership Transition Test

A conceptual ownership test may verify:

```text
Allocator A owns Engine 42
        ↓
A is fenced / ownership expires
        ↓
Allocator B becomes authoritative
        ↓
B resumes from persistent state
```

The test should confirm that A cannot continue producing valid allocations after losing authority.

---

## 97. Exhaustion Test

A conceptual exhaustion test should verify that when the Local namespace is exhausted:

```text
Next allocation
    ↓
FAIL HARD
```

and not:

```text
Next allocation
    ↓
wraparound
```

---

## 98. Gap Test

A conceptual failure test may intentionally create an unused allocation position.

The expected result is:

```text
Gap
    ↓
accepted
```

provided that the implementation preserves uniqueness and non-reuse.

---

## 99. Lifecycle Test

A conceptual lifecycle test may verify:

```text
State = 1
    ↓
retirement
    ↓
State = 0
```

If a new identity is required:

```text
New SMART ID generated
    ↓
Old SMART ID remains retired
```

---

## 100. Region Test

A conceptual Region test can verify that Region changes or presentation remapping do not alter:

```text
Engine
Local ID
```

The identity core remains stable.

---

## 101. Version Test

A v1.x generation test should verify:

```text
Version = 0
```

and:

```text
Reserved = 0
```

unless a future specification explicitly changes those semantics.

---

## 102. Invalid Generation Pattern

The following conceptual pattern is invalid:

```text
Allocator A owns Engine 42
Allocator B also generates for Engine 42
```

The implementation must not rely on probability or application discipline alone to prevent the resulting collision.

Authoritative ownership must be enforced.

---

## 103. Invalid Local Allocation Pattern

The following is invalid:

```text
Worker A → Local 125000
Worker B → Local 125000
```

when both are successful allocations within the same Engine namespace.

This violates the uniqueness invariant.

---

## 104. Invalid Reuse Pattern

The following is invalid:

```text
Allocate 125000
Delete record
Reuse 125000
```

Deletion does not release an identity for reuse.

---

## 105. Invalid Wraparound Pattern

The following is invalid:

```text
Maximum Local ID
        ↓
Local ID = 0
```

The correct behavior is exhaustion failure.

---

## 106. Invalid Crash-Recovery Pattern

The following is invalid:

```text
Allocated 125000
Crash
Restart
Allocate 125000 again
```

Persistent recovery must prevent such reuse.

---

## 107. Invalid Ownership-Recovery Pattern

The following is invalid:

```text
Allocator A loses Engine ownership
        ↓
Network partition
        ↓
Allocator A continues generating
```

An implementation must have a mechanism that prevents stale authority from continuing to generate identifiers.

---

## 108. Invalid Security Assumption

The following assumption is invalid:

```text
Valid SMART ID
    =
Authorized request
```

An identifier is not an authorization credential by itself.

---

## 109. Invalid FPE Assumption

The following assumption is invalid:

```text
FPE
    =
authentication
```

or:

```text
FPE
    =
authorization
```

or:

```text
FPE
    =
integrity protection
```

Those are separate security concerns.

---

## 110. Invalid Routing Assumption

The following routing path is not part of the SMART v1.4 routing model:

```text
SMART ID
    ↓
Region
    ↓
Engine
```

The routing selector is the Engine field.

---

## 111. Invalid State Routing

State should not be used as the destination routing selector.

For example:

```text
State = 0
    ↓
route to another Engine
```

is not SMART ID routing semantics.

State is lifecycle information and may be used as an index-level filter.

---

## 112. Invalid Architecture Assumption

The following statement is too strong:

> SMART ID requires a centralized control application.

SMART ID does not mandate a particular control-plane topology.

A centralized control application may be a practical implementation choice.

---

## 113. Valid Architecture Boundary

The stronger and correct statement is:

> SMART ID does not mandate a particular Engine allocation or control-plane architecture. The client is responsible for ensuring authoritative and non-conflicting Engine ownership.

This preserves the specification boundary.

---

## 114. Generation Responsibility Boundary

SMART ID defines:

* the 64-bit structure;
* identity semantics;
* Engine and Local ID allocation rules;
* uniqueness invariants;
* routing semantics;
* lifecycle semantics;
* required failure behavior; and
* standards commitments.

The client implementation defines:

* control-plane topology;
* Engine provisioning;
* fencing technology;
* storage technology;
* deployment topology;
* authentication;
* authorization; and
* operational policies.

---

## 115. Conceptual End-to-End Example

A complete conceptual flow is:

```text
Application requests new identity
        ↓
Authoritative Engine ownership confirmed
        ↓
Engine = 42
        ↓
Persistent Local state loaded
        ↓
Local ID = 125000 allocated
        ↓
Allocation state persisted
        ↓
Region = 18
State = 1
Reserved = 0
Version = 0
        ↓
64-bit SMART ID assembled
        ↓
Identity persisted
        ↓
Transaction committed
        ↓
SMART ID returned
```

---

## 116. Later Routing

The generated identifier can subsequently be routed:

```text
SMART ID
    ↓
Extract Engine = 42
    ↓
Route to Engine 42
    ↓
Extract Local ID = 125000
    ↓
Full primary-key lookup
```

This is a separate operation from generation.

---

## 117. Later Retirement

If the identity eventually becomes retired:

```text
SMART ID
    ↓
State = 0
```

The identity is not reused.

If a replacement identity is required:

```text
Generate new SMART ID
        ↓
Use new identity
        ↓
Retire old identity
```

---

## 118. Conceptual Generation State Machine

A simplified conceptual state machine is:

```text
UNAUTHORIZED
      ↓
OWNERSHIP ESTABLISHED
      ↓
ALLOCATION AVAILABLE
      ↓
LOCAL ID RESERVED
      ↓
IDENTIFIER ASSEMBLED
      ↓
IDENTIFIER PERSISTED
      ↓
COMMITTED
```

Failure at a safety-critical stage should stop generation rather than produce an uncertain identity.

---

## 119. Ownership Failure State

An ownership failure may be represented conceptually as:

```text
OWNERSHIP UNKNOWN
      ↓
GENERATION STOPPED
      ↓
OWNERSHIP RESTORED
      ↓
GENERATION RESUMES
```

The implementation should not manufacture an Engine ownership result when authority is uncertain.

---

## 120. Exhaustion State

A Local namespace may reach:

```text
ALLOCATION AVAILABLE
      ↓
LOCAL CAPACITY EXHAUSTED
      ↓
FAIL HARD
```

The Engine cannot silently recycle the namespace.

---

## 121. Persistence Failure State

If persistent allocation state cannot be safely updated:

```text
Allocation attempted
      ↓
Persistence failure
      ↓
Safe recovery required
```

The implementation must not assume that a value can be reused merely because the higher-level application operation did not complete.

---

## 122. Why Correctness Comes First

Identifier generation is foundational infrastructure.

A performance optimization that creates duplicate identities is not a valid optimization.

Therefore:

```text
Correctness
    >
Availability of unsafe generation
    >
Gaplessness
    >
Micro-optimization
```

The exact operational priorities of a deployment may differ, but identity correctness remains fundamental.

---

## 123. Relationship to Benchmarking

Generation behavior should be benchmarked separately from database lookup and routing benchmarks.

For example:

```text
Generation benchmark
    ≠
Routing benchmark
    ≠
FPE benchmark
    ≠
Database lookup benchmark
```

A measured improvement in one area must not automatically be presented as an improvement in another.

---

## 124. Generation Performance Claims

SMART ID does not claim a universal generation throughput or latency value.

Actual performance depends on:

* allocator design;
* persistence technology;
* concurrency;
* transaction behavior;
* storage hardware;
* network conditions;
* control-plane coordination; and
* deployment topology.

Performance claims must therefore be tied to their actual experimental conditions.

---

## 125. CPU Cost

The bit assembly operation is based on fixed field positions.

The SMART ID specification does not claim a universal number of CPU cycles for generation.

Actual CPU cost depends on:

* implementation language;
* compiler;
* processor architecture;
* instruction selection;
* optimization;
* memory behavior; and
* surrounding system work.

---

## 126. FPE Performance Separation

If an implementation applies FPE to a public representation, the FPE processing cost should be measured separately.

For example:

```text
SMART ID assembly
        ↓
benchmark A

FPE transformation
        ↓
benchmark B
```

The two measurements should not be combined into an unsupported claim about SMART ID bit assembly itself.

---

## 127. Database Performance Separation

Likewise:

```text
ID generation
```

and:

```text
database insertion
```

are separate components of an end-to-end workload.

A database benchmark should identify which component is being measured.

---

## 128. Reproducibility

A generation benchmark should document at least:

* Engine allocation model;
* number of concurrent allocators;
* Local allocation mechanism;
* persistence mechanism;
* transaction configuration;
* batch size;
* hardware;
* operating system;
* database version where applicable;
* failure behavior; and
* measurement method.

Without this information, performance comparisons may be difficult to reproduce.

---

## 129. Multi-Engine Testing

A genuine multi-engine experiment should use independent authoritative Engine ownership.

For example:

```text
Writer A → Engine 1
Writer B → Engine 2
Writer C → Engine 3
...
Writer P → Engine 16
```

Each writer should have an independent allocation stream appropriate to the experiment.

Simply cycling Engine values inside one writer does not reproduce genuine multi-engine allocation behavior.

---

## 130. Invalid Simulated Multi-Engine Experiment

The following is not sufficient evidence of distributed multi-engine behavior:

```text
One writer
One connection
One allocation loop
        ↓
Engine = row_index % 16
```

This changes field values but does not create sixteen independent authoritative allocation streams.

Such a result should not be described as a genuine multi-engine distributed benchmark.

---

## 131. Genuine Multi-Engine Experiment

A stronger experiment would involve:

```text
16 independent authoritative Engine owners
        ↓
16 independent writers
        ↓
16 independent allocation streams
        ↓
concurrent persistence
```

The exact infrastructure can vary, but the experimental design must represent the property being claimed.

---

## 132. Example Allocation Table

A conceptual allocation table could look like:

| Engine | Local ID range | Authority   |
| -----: | -------------: | ----------- |
|      1 |            0–N | Allocator A |
|      2 |            0–N | Allocator B |
|      3 |            0–N | Allocator C |
|      4 |            0–N | Allocator D |

The table is illustrative only.

Actual Engine ownership and allocation state are implementation concerns.

---

## 133. Generation Invariants

A correct implementation preserves these core properties:

```text
One authoritative allocator per active Engine
+
No duplicate Engine ownership
+
No duplicate Local ID allocation
+
Persistent allocation state
+
No reuse
+
No wraparound
+
Explicit exhaustion failure
+
Correct 64-bit field assembly
```

---

## 134. Generation Checklist

Before treating a generation implementation as production-ready, an implementation should verify:

* Engine ownership is authoritative.
* Stale ownership is fenced or equivalently prevented.
* Local allocation is persistent.
* Concurrent allocation cannot duplicate values.
* Allocated values are never reused.
* Exhaustion fails hard.
* Crash recovery does not reuse values.
* Region is treated as metadata.
* State is treated as lifecycle.
* Reserved bits follow v1.4 semantics.
* Version follows v1.4 semantics.
* SMART IDs are correctly assembled.
* Persistence and uniqueness are reliable.
* Security is handled separately.
* FPE is handled separately from core generation.

---

## 135. Minimal Conceptual Pseudocode

The following pseudocode is illustrative only:

```text
generate():
    authority = establish_engine_authority()

    if authority is not valid:
        FAIL HARD

    local_id = allocate_persistent_local_id(authority.engine)

    if local_id is exhausted:
        FAIL HARD

    smart_id = assemble(
        local_id,
        authority.engine,
        region,
        state=1,
        reserved=0,
        version=0
    )

    persist(smart_id)

    return smart_id
```

This is conceptual pseudocode, not a reference implementation.

---

## 136. Important Pseudocode Boundary

The pseudocode intentionally does not prescribe:

* a database;
* a programming language;
* a locking mechanism;
* a lease service;
* a control-plane topology;
* a cryptographic library;
* a network protocol; or
* a deployment platform.

Those are implementation choices.

---

## 137. Conceptual Failure Handling

A more explicit conceptual model is:

```text
if engine_ownership_is_ambiguous:
    FAIL HARD

if local_namespace_is_exhausted:
    FAIL HARD

if allocation_state_cannot_be_safely_persisted:
    FAIL HARD

if uniqueness_cannot_be_guaranteed:
    FAIL HARD

otherwise:
    allocate
    assemble
    persist
    return
```

The exact exception and recovery mechanism is implementation-dependent.

---

## 138. Why FAIL HARD Exists

FAIL HARD is intended to prevent silent corruption of the identity namespace.

Examples include:

* duplicate ownership;
* duplicate allocation;
* uncertain persistence state;
* Local namespace exhaustion; and
* unsafe recovery conditions.

Stopping generation is preferable to silently producing an identifier whose uniqueness or validity cannot be trusted.

---

## 139. Application-Level Retry

An application may retry a failed generation request according to its own error-handling policy.

However, retries must not cause reuse of an already allocated Local ID.

A retry should represent a new generation attempt under a valid allocation state.

---

## 140. Idempotency Consideration

Application-level idempotency is separate from SMART ID allocation.

For example:

```text
Request A
    ↓
SMART ID generated
    ↓
response lost
```

A client retry may require application-level idempotency handling.

SMART ID itself does not define an API request-idempotency protocol.

---

## 141. Generation and Transactions

Where the application uses transactional persistence, the implementation should clearly distinguish:

```text
ID allocation
```

from:

```text
business transaction success
```

An identifier can be consumed even if the surrounding business transaction later fails.

That behavior is compatible with non-reuse.

---

## 142. Generation and Replication

Replication behavior is implementation-dependent.

If allocation state is replicated, the replication design must preserve the authoritative allocation invariant and prevent conflicting authorities from generating the same Engine namespace.

SMART ID does not prescribe a particular replication architecture.

---

## 143. Generation and Failover

Failover is safe only when ownership transfer is unambiguous.

Conceptually:

```text
Primary allocator
    ↓
failure
    ↓
ownership fenced
    ↓
secondary allocator becomes authoritative
    ↓
persistent state recovered
    ↓
generation resumes
```

The exact failover mechanism is implementation-specific.

---

## 144. Generation and Network Partitions

A network partition can create stale ownership risk.

An implementation must therefore consider:

```text
Can an old allocator continue generating
while a new allocator believes it is authoritative?
```

If the answer can be yes, the ownership design is unsafe.

---

## 145. Generation Safety Principle

The key safety property is:

> At any time, an Engine ID MUST have at most one authoritative active allocator.

This remains true during:

* startup;
* normal operation;
* restart;
* failover;
* network partitions;
* maintenance;
* scaling; and
* ownership rotation.

---

## 146. Local Allocation Safety Principle

The corresponding Local allocation property is:

> A Local ID allocated within an Engine namespace MUST NOT be allocated again.

This remains true across:

* restart;
* failure;
* deletion;
* rollback;
* batch reservation;
* ownership transition; and
* recovery.

---

## 147. Identity Immutability

Once generated, the Engine + Local ID identity core is immutable.

Metadata and lifecycle semantics must not be used to reinterpret the identity as another identity.

If a genuinely new identity is required:

```text
Generate a new SMART ID.
```

---

## 148. Example Identity Transfer

Suppose an application resource moves between administrative contexts.

A conceptual model is:

```text
Old SMART ID
    ↓
new ownership/context
    ↓
Generate NEW SMART ID if required
    ↓
Retire OLD SMART ID
```

The old identity is not rewritten into the new one.

---

## 149. Generation Does Not Define Business Ownership

SMART ID Engine ownership is an allocation authority concept.

It should not automatically be interpreted as:

```text
business owner
legal owner
customer owner
data owner
```

Those concepts belong to the application domain.

---

## 150. Region Does Not Define Legal Sovereignty

Region is metadata.

It may represent a generation-time geographic or jurisdictional classification, but the SMART ID field itself should not be treated as a complete legal or regulatory determination.

Applications remain responsible for their own governance semantics.

---

## 151. State Does Not Define Availability

State provides lifecycle semantics.

An application may have additional operational states such as:

```text
pending
processing
suspended
archived
```

Those states need not be encoded into the one-bit SMART State field.

---

## 152. Generation and Application State

An implementation may maintain a richer application lifecycle model outside SMART ID.

For example:

```text
SMART State = enabled
Application State = processing
```

or:

```text
SMART State = retired
Application State = archived
```

The detailed application state remains outside the SMART ID field.

---

## 153. Version Compatibility

A future SMART ID specification may define a different Version value.

A v1.x implementation should not silently reinterpret a future format as v1.x.

Compatibility behavior should be explicitly defined by the implementation and future specification.

---

## 154. Reserved Capacity

Reserved bits exist to provide future governance capacity.

Their presence should not be interpreted as permission for implementations to create incompatible private formats.

Future use should be established by the governing specification.

---

## 155. Generation Documentation

A production implementation should document:

* how Engine ownership is established;
* how stale owners are fenced;
* where Local allocation state persists;
* how concurrency is controlled;
* how exhaustion is detected;
* how crashes are recovered;
* how batch allocation works;
* how failures are surfaced;
* how SMART IDs are serialized; and
* how security and public-ID transformations are handled.

---

## 156. Example Documentation Record

A deployment record might conceptually state:

```text
Engine ownership:
    Lease + fencing

Local allocation:
    Persistent transactional counter

Batch size:
    1,000

Region:
    Generation-time metadata

State:
    1 on creation

Reserved:
    0

Version:
    0

Public representation:
    Optional FPE

External serialization:
    String
```

This is an example deployment description, not a SMART requirement.

---

## 157. Implementation Review Questions

Before deployment, an implementation team can ask:

1. Who is authoritative for each Engine?
2. How are stale allocators prevented from generating?
3. Where is Local allocation state persisted?
4. How is concurrent allocation serialized or atomically controlled?
5. What happens at exhaustion?
6. Can any crash cause reuse?
7. Can any rollback cause reuse?
8. Can any Engine ownership transition create concurrent authority?
9. Are Region and State incorrectly used for routing?
10. Is FPE incorrectly treated as authentication or authorization?

---

## 158. Correctness Review

A generation implementation should be rejected if it depends on:

* accidental uniqueness;
* random collision avoidance instead of namespace allocation;
* wraparound;
* record deletion for ID recycling;
* volatile-only allocation state;
* ambiguous Engine ownership;
* unsupported assumptions about crash behavior; or
* undocumented reinterpretation of reserved fields.

---

## 159. Operational Review

Operational teams should also understand:

```text
Engine exhaustion
    ≠
System-wide identity exhaustion
```

An individual Engine can exhaust its 29-bit Local namespace while other Engines remain available.

The client's control plane can determine how to provision or activate another Engine.

---

## 160. System-Wide Capacity

The theoretical identity-core namespace is:

```text
2^50
```

combinations.

However, practical capacity depends on:

* the number of provisioned Engines;
* Local ID consumption;
* allocation policy;
* reserved operational capacity;
* deployment topology; and
* application requirements.

The theoretical namespace is not a guaranteed operational capacity.

---

## 161. Generation and Storage Density

The SMART ID structure may have storage characteristics that differ from conventional database identifiers.

Those effects belong to database and workload benchmarking rather than to the logical generation algorithm itself.

A generation example should therefore not claim a universal storage advantage.

---

## 162. Generation and Benchmark Evidence

Measured results should be presented with:

* exact environment;
* workload;
* configuration;
* methodology;
* sample size;
* limitations; and
* whether the test is valid for the claim being made.

The v1.4 research documents provide the appropriate benchmark boundaries.

---

## 163. No Universal Performance Guarantee

This example does not claim that SMART ID generation is universally faster than another identifier system.

Performance depends on implementation and environment.

The primary SMART ID guarantees concern identity semantics and correctness.

---

## 164. Conceptual Summary

The generation model can be reduced to:

```text
1. Establish authoritative Engine ownership.
2. Obtain persistent Local allocation state.
3. Allocate a unique Local ID.
4. Never reuse or wrap the Local ID.
5. Fail hard on exhaustion or unsafe allocation conditions.
6. Assemble the fixed v1.4 fields.
7. Persist the identity safely.
8. Return the generated SMART ID.
```

---

## 165. Final Generation Flow

The complete conceptual flow is:

```text
Application request
        ↓
Authoritative Engine ownership
        ↓
Engine selected
        ↓
Persistent Local allocation
        ↓
Local ID allocated
        ↓
Exhaustion / uniqueness checks
        ↓
Region metadata
        ↓
State = enabled
        ↓
Reserved = 0
        ↓
Version = 0
        ↓
64-bit field assembly
        ↓
Persistence
        ↓
Commit
        ↓
Return SMART ID
```

---

## 166. Final Safety Flow

When a safety condition fails:

```text
Ownership ambiguous
        ↓
FAIL HARD

Local namespace exhausted
        ↓
FAIL HARD

Uniqueness uncertain
        ↓
FAIL HARD

Persistent allocation state unsafe
        ↓
FAIL HARD
```

No unsafe identifier is generated merely to preserve availability.

---

## 167. Final Architecture Boundary

The generation process does not require one particular control-plane architecture.

It may be implemented using centralized or distributed mechanisms, provided that the implementation preserves:

```text
one authoritative allocator per Engine
+
persistent Local allocation
+
no reuse
+
no wraparound
+
correct failure behavior
```

---

## 168. Final Identity Boundary

SMART ID generation establishes:

```text
Engine + Local ID
```

as the immutable identity core.

Region, State, Reserved, and Version provide metadata, lifecycle, future capacity, and format governance.

They do not replace the identity core.

---

## 169. Final Security Boundary

The generated identifier is not itself an authentication or authorization mechanism.

Optional public-ID cryptographic processing is separate.

Implementations remain responsible for:

```text
Authentication
Authorization
Integrity
Key management
Transport security
Operational security
```

in accordance with their deployment requirements.

---

## 170. Final Specification Boundary

This example does not modify Technical Specification v1.4.

The normative requirements remain defined by the official specification and related project documents.

This document exists to make the generation model easier to understand through conceptual examples.

---

## 171. Final Principle

The core generation principle is:

> **Establish authoritative ownership, allocate uniquely from persistent state, never reuse identity, and fail hard whenever correctness cannot be guaranteed.**

---

## 172. Non-Normative Notice

This document is a conceptual example.

It does not prescribe a particular:

* database;
* programming language;
* allocator implementation;
* control-plane topology;
* lease mechanism;
* fencing mechanism;
* storage engine;
* deployment architecture;
* authentication system;
* authorization system; or
* cryptographic implementation.

Those remain implementation choices subject to the SMART ID v1.4 requirements.

---

## 173. Closing Conceptual Flow

```text
AUTHORITATIVE ENGINE
        ↓
PERSISTENT LOCAL ALLOCATION
        ↓
UNIQUE LOCAL ID
        ↓
64-BIT FIELD ASSEMBLY
        ↓
PERSIST
        ↓
COMMIT
        ↓
RETURN SMART ID
```

**Correctness first. Non-reuse always. Exhaustion fails hard.**

**This example is non-normative and does not modify the SMART ID Technical Specification v1.4.**
