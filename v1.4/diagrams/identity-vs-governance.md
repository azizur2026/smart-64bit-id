# SMART 64-Bit ID — Identity vs Governance

**Technical Specification v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

SMART 64-Bit ID separates immutable identity from governance, lifecycle, metadata, and version information.

The 64-bit identifier contains:

```text id="v3l7cz"
50-bit Identity Core
+
14-bit Governance / Metadata
```

This separation is fundamental to the v1.4 model.

---

## 2. High-Level Structure

The complete identifier can be viewed as:

```text id="y4b1j0"
┌────────────────────────────────────────────────────────────────────────────┐
│                         SMART 64-BIT ID                                   │
├───────────────────────────────────────────────┬────────────────────────────┤
│              50-BIT IDENTITY CORE             │ 14-BIT GOVERNANCE / META  │
│                                               │                            │
│        Engine (21) + Local ID (29)           │ Region (8)                 │
│                                               │ State (1)                  │
│                                               │ Reserved (4)               │
│                                               │ Version (1)                │
└───────────────────────────────────────────────┴────────────────────────────┘
```

The identity core determines the immutable identity.

The remaining fields provide metadata, lifecycle, reserved capacity, and version information.

---

## 3. Bit-Level Separation

The fields are positioned as follows:

```text id="s9j6ks"
MSB                                                               LSB
63                                                                  0
┌───────┬────────────┬──────────┬───────┬──────────────────────┬─────────────┐
│Version│  Reserved  │  State   │Region │       Engine         │  Local ID   │
│ 1 bit │   4 bits   │  1 bit   │8 bits │       21 bits        │   29 bits   │
└───────┴────────────┴──────────┴───────┴──────────────────────┴─────────────┘
   │          │          │         │              │                    │
   └──────────┴──────────┴─────────┴──────────────┴────────────────────┘
                    Governance / Metadata
                                     
                         Identity Core
```

More precisely:

```text id="2r1zxm"
Identity Core:
bits 0–49
    ├── Local ID  bits 0–28
    └── Engine    bits 29–49

Governance / Metadata:
bits 50–63
    ├── Region    bits 50–57
    ├── State     bit 58
    ├── Reserved  bits 59–62
    └── Version   bit 63
```

---

## 4. Identity Core

The identity core is:

```text id="s7c9n8"
Local ID + Engine
```

Width:

```text id="4u0h4h"
29 + 21 = 50 bits
```

The theoretical identity space is:

```text id="d6ckcw"
2^50
=
1,125,899,906,842,624
```

The identity core is immutable after generation.

Changing metadata does not create a new identity.

---

## 5. Local ID

Local ID occupies bits:

```text id="nqv7mc"
0–28
```

Width:

```text id="ex8m0r"
29 bits
```

Capacity:

```text id="x6tq5g"
2^29
=
536,870,912
```

Therefore:

**536,870,912 identifiers per Engine.**

Local ID is allocated within the authoritative Engine ownership domain.

It must:

* remain unique within its Engine;
* remain non-reusable;
* remain monotonic within the allocation stream;
* persist across restart;
* fail hard on exhaustion.

---

## 6. Engine

Engine occupies bits:

```text id="j3h1qu"
29–49
```

Width:

```text id="f0o9a7"
21 bits
```

The theoretical Engine namespace is:

```text id="3b0r0v"
2^21
=
2,097,152
```

Engine is part of the immutable identity core.

It also provides the routing destination selector.

The fundamental ownership rule is:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

Stale or concurrent ownership must be prevented.

Fencing, leases, or an equivalent mechanism may be used by implementations.

SMART ID does not mandate a particular control-plane architecture.

---

## 7. Why Engine and Local ID Form Identity

Neither Engine nor Local ID alone is the complete identity.

For example:

```text id="c4tq7x"
Engine = 10
Local ID = 100
```

and:

```text id="b1y8k0"
Engine = 11
Local ID = 100
```

represent different identities.

Therefore the identity tuple is:

```text id="9n8y2m"
(Engine, Local ID)
```

or equivalently:

```text id="r7q1vf"
Engine + Local ID
```

The complete 64-bit SMART ID carries this identity together with governance and metadata fields.

---

## 8. Governance and Metadata

The governance/metadata portion occupies:

```text id="6h3t8f"
bits 50–63
```

Width:

```text id="u7a4mx"
14 bits
```

It consists of:

```text id="0z9r8w"
Region    = 8 bits
State     = 1 bit
Reserved  = 4 bits
Version   = 1 bit

Total     = 14 bits
```

These fields do not form the immutable identity core.

---

## 9. Region

Region occupies:

```text id="2s5v8c"
bits 50–57
```

Width:

```text id="e4q1x7"
8 bits
```

Region represents generation-time regional or country classification metadata.

It is not:

* an identity component;
* a routing selector;
* an authorization mechanism.

Region may support:

* reporting;
* governance;
* presentation;
* historical classification;
* operational analytics.

---

## 10. Generation-Time Meaning of Region

Region can be understood as a snapshot associated with identifier generation.

Conceptually:

```text id="j2c7py"
Identifier generated
        │
        ▼
Generation-time Region
        │
        ▼
Stored as metadata
```

Later infrastructure or organizational changes do not require rewriting the identity core.

Presentation or governance systems may remap Region values according to their policies.

Historical interpretation should preserve the original generation-time meaning where required.

---

## 11. Region Does Not Determine Identity

Two identifiers may have the same Engine and Local ID only if they are the same identity.

Region does not distinguish otherwise identical identity-core values.

Conceptually:

```text id="o0e6gn"
Identity Core
     │
     ├── Region A
     │
     └── Region B
```

Changing Region metadata alone must not be treated as creating a new identity.

The actual identity remains determined by the Engine + Local ID combination.

---

## 12. Region Does Not Determine Routing

The routing path is:

```text id="f8z7cn"
SMART ID
   │
   ▼
Engine
   │
   ▼
Destination
```

It is not:

```text id="v9x4rp"
SMART ID
   │
   ▼
Region
   │
   ▼
Destination
```

Region remains outside the core routing path.

This prevents metadata from being confused with the immutable routing identity.

---

## 13. State

State occupies:

```text id="q7b3n6"
bit 58
```

Width:

```text id="a1k5r8"
1 bit
```

Current v1.x semantics:

```text id="8g2f4j"
State = 1 → enabled
State = 0 → retired / disabled
```

State is lifecycle information.

It is not part of the immutable identity core.

---

## 14. State Is Not Routing

State does not determine which Engine receives a request.

The distinction is:

```text id="z7d3m1"
Engine
  ↓
Routing

State
  ↓
Lifecycle
```

After the appropriate record has been located, an implementation may use State as an index-level or application-level lifecycle filter.

---

## 15. Retirement Semantics

An identity that is no longer valid for active use is retired rather than reused.

Conceptually:

```text id="x6n1pd"
Existing SMART ID
       │
       ▼
State = 1
       │
       ▼
Lifecycle event
       │
       ▼
State = 0
       │
       ▼
Retired permanently
```

If the entity or identity requires a new identifier:

```text id="m3p8q4"
Create NEW SMART ID
       │
       ▼
Use NEW identity
       │
       ▼
Retire OLD SMART ID
```

The old SMART ID is never reused.

---

## 16. Why State Is Separate

Separating lifecycle from identity provides an important semantic boundary.

The identity answers:

> Which identifier is this?

State answers:

> Is this identifier currently enabled or retired?

These questions are related but not identical.

Therefore State is not included in the identity core.

---

## 17. Reserved Bits

Reserved bits occupy:

```text id="y4p2c8"
59–62
```

Width:

```text id="z5h7v2"
4 bits
```

Current v1.x requirement:

```text id="k6m1t4"
Reserved = 0
```

The bits are reserved for future governance or specification evolution.

Applications should not assign independent v1.x semantics to these bits.

---

## 18. Version

Version occupies:

```text id="j1q6z9"
bit 63
```

Width:

```text id="p3w8c5"
1 bit
```

Current semantics:

```text id="b7m2k4"
Version = 0 → v1.x
Version = 1 → reserved for v2
```

Version identifies the format generation.

It is not a routing field.

---

## 19. Governance Does Not Mean Mutable Identity

The term governance/metadata does not mean every field is freely mutable.

The distinction is:

```text id="c5r9m2"
Identity Core
    │
    └── Immutable

Governance / Metadata
    │
    ├── Region → metadata semantics
    ├── State → lifecycle semantics
    ├── Reserved → reserved
    └── Version → immutable format marker
```

Version is part of the governance/format boundary but remains immutable after generation.

---

## 20. Identity Immutability

Once a SMART ID is generated:

```text id="d7x3k1"
Engine
  +
Local ID
  =
Immutable Identity
```

The identity core must not be rewritten to represent another entity.

If a new identity is required:

```text id="q8m4v6"
Generate NEW SMART ID
```

The old identifier remains historical and may be retired.

---

## 21. Non-Reuse

The identity namespace is permanently consumed once an identifier has been allocated.

This applies even when:

* a record is deleted;
* an identity is retired;
* an allocation batch is partially unused;
* an allocator crashes;
* an Engine changes operational ownership;
* a service is replaced.

The implementation must not recycle old Local IDs.

---

## 22. Local Namespace Exhaustion

Each Engine has:

```text id="w3f7n2"
536,870,912
```

possible Local ID values.

When exhausted:

```text id="j5r8c1"
Local namespace exhausted
        │
        ▼
FAIL HARD
```

The identifier must not wrap around.

The operational response is outside the identifier format.

The client/control plane may obtain another Engine or take another operational action.

---

## 23. Engine Ownership Boundary

Identity correctness depends on authoritative Engine ownership.

The invariant is:

```text id="k2d7p9"
One Engine ID
      │
      ▼
At most one authoritative active allocator
```

If two allocators independently believe they own the same Engine, the system enters an unsafe state.

Implementations should use fencing, leases, or an equivalent mechanism.

If safe ownership cannot be established:

```text id="n4x8q2"
Generation → FAIL HARD
```

---

## 24. Control-Plane Independence

SMART ID defines the ownership requirement but does not dictate the control-plane architecture.

Possible implementations may use:

* a centralized allocator service;
* distributed coordination;
* leases;
* fencing;
* a database-backed allocator;
* another equivalent design.

The architectural choice belongs to the client or implementation.

The requirement is the invariant, not the mechanism.

---

## 25. Identity and Routing

Identity and routing are related but not identical concepts.

The identity core is:

```text id="r1m7c4"
Engine + Local ID
```

Routing uses:

```text id="v2n8k5"
Engine
```

Lookup uses:

```text id="q6p3x9"
Engine + Local ID
```

Therefore:

```text id="a8d4w1"
Engine → routing

Engine + Local ID → identity lookup
```

---

## 26. Governance and Routing Separation

Governance fields should not silently become routing fields.

The v1.4 boundary is:

```text id="z3m6q8"
                 SMART ID
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
 Identity Core           Governance / Metadata
        │                       │
        ├── Engine              ├── Region
        └── Local ID            ├── State
                                ├── Reserved
                                └── Version
        │
        ▼
 Routing + Lookup
```

This separation is part of the v1.4 semantic model.

---

## 27. State and Historical Meaning

A retired identifier remains meaningful as a historical identifier.

For example:

```text id="g5r1n7"
SMART ID
   │
   ├── Engine + Local ID
   │      → identity
   │
   └── State = 0
          → retired
```

Retirement does not erase the identifier's historical identity.

This allows systems to distinguish:

* an identifier that never existed;
* an identifier that existed and was retired;
* an identifier that is currently enabled.

---

## 28. Version and Compatibility

Version provides a format-level marker.

For v1.x:

```text id="f4n7c2"
Version = 0
```

A future version may define different semantics.

Existing v1.x identifiers must remain interpretable according to the v1.x specification.

Version does not create a second routing mechanism within v1.x.

---

## 29. Reserved Capacity

Reserved bits provide space for future specification evolution without assigning unsupported semantics today.

Current state:

```text id="m9x3q7"
Reserved = 0000
```

Implementations should preserve these values according to the specification.

Future use requires an explicit specification change.

---

## 30. Public Representation

A public identifier may be represented separately from the internal SMART ID.

Conceptually:

```text id="v5k1p8"
Internal SMART ID
       │
       ▼
Public representation
       │
       ▼
Optional FPE
```

This does not change the identity/governance model.

Format-preserving encryption is a cryptographic implementation concern and is separate from the 64-bit field semantics.

---

## 31. FPE Boundary

The distinction is:

```text id="c7m2r9"
SMART ID structure
       │
       ▼
Identity + routing semantics

FPE
       │
       ▼
Public identifier transformation
```

FPE is not:

* authentication;
* authorization;
* integrity protection;
* access control.

SMART ID does not define or require a proprietary cryptographic algorithm.

Implementations must follow applicable recognized cryptographic standards.

---

## 32. Security Boundary

The identifier itself does not constitute an application security framework.

Implementations remain responsible for:

* authentication;
* authorization;
* access control;
* integrity;
* secure transport;
* key management;
* audit;
* operational security.

A valid SMART ID does not by itself grant permission to access the associated record.

---

## 33. Serialization Boundary

A 64-bit SMART ID should be serialized carefully when transported through APIs.

Many common JavaScript environments represent numbers using IEEE-754 double precision.

Not every 64-bit integer can therefore be represented exactly as an ordinary JavaScript `Number`.

A safe API representation is commonly:

```json id="s1k8q4"
{
  "id": "1234567890123456789"
}
```

The serialization format is an API implementation choice.

The underlying SMART ID remains a 64-bit identifier.

---

## 34. Identity vs Metadata Example

Consider:

```text id="e4q7m2"
Engine   = 100
Local ID = 5000
Region   = 12
State    = 1
Version  = 0
```

The identity is:

```text id="p8n3v5"
Engine + Local ID
=
(100, 5000)
```

The other values describe metadata and lifecycle:

```text id="q2m7c9"
Region  = 12
State   = enabled
Version = v1.x
```

Changing Region does not change the identity.

Changing State from enabled to retired does not change the identity.

Changing Version is not a normal mutable operation; it identifies the format version associated with the identifier.

---

## 35. Identity Transfer Example

Suppose an existing identity must be replaced.

The correct conceptual operation is:

```text id="x1q6m8"
OLD SMART ID
    │
    ▼
Create NEW SMART ID
    │
    ▼
NEW identity becomes active
    │
    ▼
OLD State = 0
```

The old identity is preserved as a historical record.

No reuse occurs.

---

## 36. Deletion Does Not Create Reuse

If an application deletes a database record:

```text id="n7c2v5"
Record deleted
      │
      ▼
SMART ID remains consumed
```

A later record must not receive the same Local ID within the same Engine namespace.

This preserves the permanent non-reuse property.

---

## 37. Crash Recovery and Identity

If an allocator crashes after consuming an identifier range:

```text id="r8m3q1"
Allocated range
      │
      ▼
Crash
      │
      ▼
Range remains consumed
```

The implementation may continue from a later Local ID after recovery.

This can produce gaps.

Gaps are acceptable.

Identity reuse is not.

---

## 38. Batch Allocation and Governance

Batch allocation affects Local ID consumption but does not alter the identity/governance boundary.

For example:

```text id="k4p9d2"
Engine
  │
  ▼
Reserve Local ID batch
  │
  ├── ID 1
  ├── ID 2
  ├── ID 3
  └── ...
```

If some values remain unused after failure, they may become permanent gaps.

This does not make them available for reuse.

---

## 39. Engine Rotation

Engine rotation affects future allocation, not existing identity.

Conceptually:

```text id="w6n2r8"
Allocation policy
      │
      ├── Engine A
      ├── Engine B
      ├── Engine C
      └── ...
```

A newly generated identifier may use a different Engine.

An existing identifier does not change its Engine field.

---

## 40. Storage Behavior

The identity/governance separation is a logical semantic boundary.

It should not be confused with a guarantee about physical storage layout.

The v1.4 benchmark observed smaller clustered indexes in the tested MariaDB/InnoDB configurations.

That result is workload-specific.

Therefore:

```text id="p5x7m1"
Logical identity model
        ≠
Universal storage guarantee
```

---

## 41. Empirical Evidence Boundary

The valid single-engine research found approximate latency parity with the traditional identifier baseline and observed a clustered-index size reduction under the tested configurations.

These results do not change the identity/governance semantics.

Research findings remain empirical observations.

See:

`research/FINDINGS_SINGLE_ENGINE.md`

---

## 42. Invalid Multi-Engine Evidence

The previously tested 16-Engine experiment used a single writer cycling through simulated Engine values.

That experiment is explicitly classified as:

**INVALID AS MULTI-ENGINE EVIDENCE**

It does not establish distributed multi-engine performance.

The reason is methodological:

```text id="q8d1m6"
Simulated Engine values
        ≠
Independent Engine authorities
```

See:

`research/FINDINGS_MULTI_ENGINE_INVALID.md`

---

## 43. Benchmark Boundary

A benchmark may separately measure:

```text id="g2v6p9"
Identity generation
Routing extraction
Database lookup
Storage behavior
FPE
Security mechanisms
```

These measurements must not be silently combined.

In particular:

```text id="m4q8r2"
SMART ID extraction
        ≠
FPE performance
        ≠
Authentication performance
        ≠
Database performance
```

---

## 44. Correctness Hierarchy

The identity/governance model follows this priority:

```text id="n1x5c7"
Identity correctness
       │
       ▼
Ownership correctness
       │
       ▼
Lifecycle correctness
       │
       ▼
Routing correctness
       │
       ▼
Performance
```

A system that produces duplicate identities is incorrect regardless of throughput.

---

## 45. Implementation Freedom

SMART ID defines:

* identity structure;
* identity immutability;
* Engine ownership semantics;
* Local ID allocation semantics;
* routing semantics;
* lifecycle semantics;
* required failure behavior.

SMART ID does not dictate:

* control-plane topology;
* Engine provisioning technology;
* lease implementation;
* fencing implementation;
* database vendor;
* deployment topology;
* authentication architecture;
* authorization architecture;
* cryptographic library.

The implementation is responsible for selecting appropriate mechanisms.

---

## 46. Governance Fields and Application Policy

Applications may use Region and State for policies such as:

* filtering;
* reporting;
* governance;
* archival workflows;
* lifecycle management;
* historical analysis.

Such policies are application-level behavior.

They must not redefine the identity semantics without a specification change.

---

## 47. Region Remapping

Region may be presented through an external mapping.

For example:

```text id="b8m2q6"
Stored Region Code
       │
       ▼
Governance mapping
       │
       ▼
Displayed regional classification
```

The mapping may evolve.

The original generation-time metadata remains part of the identifier's historical context.

---

## 48. State Filtering

State can support efficient lifecycle filtering.

Conceptually:

```text id="r3p7n1"
Primary-key lookup
       │
       ▼
Record
       │
       ▼
State
       │
       ├── 1 → enabled
       │
       └── 0 → retired / disabled
```

This does not make State part of the routing key.

---

## 49. Reserved Bits and Forward Compatibility

Reserved bits should remain controlled by the specification.

Applications should not interpret them as:

```text id="x7q2m9"
private flags
custom routing
authorization bits
application identity
```

unless a future specification explicitly assigns such semantics.

This protects compatibility.

---

## 50. Version and Specification Evolution

The Version bit allows future specification evolution.

Current:

```text id="c6m1r8"
Version = 0
```

Future reserved:

```text id="p2x7q4"
Version = 1
```

A future version requires explicit specification.

Implementations should not invent v2 semantics while claiming v1.x compliance.

---

## 51. What Belongs to Identity

The following belong to the identity core:

```text id="h5n8q2"
✓ Engine
✓ Local ID
```

Together:

```text id="m7c3p9"
✓ 50-bit identity core
```

These fields define the immutable identity.

---

## 52. What Belongs to Governance / Metadata

The following belong to the governance/metadata boundary:

```text id="k2r6v1"
✓ Region
✓ State
✓ Reserved
✓ Version
```

Their meanings are different:

| Field    | Primary Meaning          |
| -------- | ------------------------ |
| Region   | Generation-time metadata |
| State    | Lifecycle                |
| Reserved | Future governance        |
| Version  | Format version           |

---

## 53. What Does Not Belong to Identity

The following are not identity components:

* Region;
* State;
* Reserved bits;
* application routing tables;
* database location;
* service location;
* authentication state;
* authorization policy;
* FPE representation;
* network address.

These may affect how an application operates around the identifier without changing the identifier's immutable identity.

---

## 54. What Does Not Belong to SMART ID Architecture

SMART ID does not require:

* a specific cloud provider;
* a specific database;
* a specific message broker;
* a specific service mesh;
* a specific control-plane product;
* a specific programming language;
* a specific operating system;
* a specific authentication provider.

These are implementation choices.

---

## 55. Dual-ID Application Pattern

An application may use both:

```text id="w1q5m8"
Internal database primary key
          +
Public SMART ID
```

This can separate:

* internal storage concerns;
* public identifier concerns;
* API representation;
* external identifier protection.

The dual-ID pattern is an application architecture choice.

SMART ID does not require it.

---

## 56. FPE and Dual-ID Pattern

If a public SMART ID representation is protected with FPE:

```text id="g6p2x9"
Internal SMART ID
       │
       ▼
FPE
       │
       ▼
Public representation
```

FPE remains a public-representation mechanism.

It does not alter the underlying identity semantics.

---

## 57. Security and Governance

Governance fields should not be treated as security controls by themselves.

For example:

```text id="n3m7q1"
State = 1
```

does not mean:

> "The requester is authorized."

It only represents the defined lifecycle state.

Authorization remains an application security decision.

---

## 58. Lifecycle and Governance

Lifecycle management is related to governance but remains distinct from identity.

The conceptual relationship is:

```text id="r5c8m2"
Identity
   │
   ├── remains immutable
   │
   ▼
Lifecycle
   │
   ├── enabled
   └── retired
```

A lifecycle transition changes State semantics, not the identity core.

---

## 59. Governance and Historical Records

A historical record may retain:

* SMART ID;
* generation-time Region;
* lifecycle State;
* Version.

This can support audit and historical interpretation without modifying the identity.

The application remains responsible for deciding how long such historical data is retained.

---

## 60. Data Integrity

The SMART ID structure does not itself provide a checksum or authentication tag.

Integrity may be provided through:

* database constraints;
* application validation;
* transport integrity;
* cryptographic mechanisms;
* authenticated storage.

SMART ID does not define a proprietary integrity mechanism.

---

## 61. Authentication Boundary

A SMART ID is an identifier, not an authentication credential.

Conceptually:

```text id="v4n8p2"
SMART ID
   │
   ▼
Identifies resource
```

versus:

```text id="m1q6c9"
Authentication
   │
   ▼
Identifies / verifies requester
```

These are separate security concerns.

---

## 62. Authorization Boundary

Authorization determines whether an authenticated requester may perform an action.

SMART ID does not define:

* roles;
* permissions;
* access-control lists;
* policy engines;
* tenant authorization.

Applications must implement appropriate authorization mechanisms.

---

## 63. Multi-Tenancy

SMART ID does not inherently define tenant identity.

An implementation may associate an Engine or other metadata with a tenant according to its architecture.

Such associations must not be confused with the core SMART ID specification.

The identity remains Engine + Local ID.

---

## 64. Tenant Transfer

If application ownership changes between tenants, the identifier does not automatically change.

The application must define whether:

* the identity remains the same;
* a new identity is required;
* the old identity is retired.

If a new identity is required, the v1.4 retirement pattern applies:

```text id="k9m3r7"
NEW SMART ID
+
OLD State = 0
```

---

## 65. Region and Multi-Tenancy

Region may correlate with a deployment region or organizational classification.

It does not inherently encode:

* tenant ID;
* customer ID;
* authorization;
* routing destination.

Such interpretations are implementation-specific.

---

## 66. Engine and Multi-Tenancy

An implementation may choose to associate Engine namespaces with tenants.

However:

```text id="p7x2m4"
Engine
≠
Tenant
```

unless the implementation explicitly defines that relationship.

SMART ID itself defines Engine as an identity/routing component.

---

## 67. Governance Mapping

The overall conceptual model is:

```text id="n6q1r8"
                  SMART ID
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
  Identity Core           Governance / Metadata
        │                         │
        │                         ├── Region
        │                         ├── State
        │                         ├── Reserved
        │                         └── Version
        │
        ├── Engine
        └── Local ID
```

This boundary should remain clear in implementation documentation.

---

## 68. Identity Lifecycle

The lifecycle can be represented as:

```text id="m2v8c5"
Generate
   │
   ▼
Enabled
   │
   ▼
Lifecycle event
   │
   ▼
Retired
```

At no point does the lifecycle transition change the identity core.

---

## 69. Identity Replacement

When replacement is required:

```text id="q4n7p1"
Old Identity
     │
     ▼
Replacement decision
     │
     ▼
New Identity
     │
     ▼
Old Identity retired
```

This preserves non-reuse.

---

## 70. Identity and Version

Version is not part of the identity core even though it is part of the 64-bit representation.

This allows the specification to distinguish:

```text id="x5m2r8"
Identity
+
Format version
```

without treating the format marker as the resource's identity.

Version remains immutable after generation.

---

## 71. Identity and Reserved Fields

Reserved fields provide future capacity but do not currently alter identity.

For v1.x:

```text id="p8q3m6"
Reserved = 0
```

No identity interpretation should be derived from these bits.

---

## 72. Identity and Region Changes

If a business or governance classification changes:

```text id="k6r1v9"
Region classification changes
        │
        ▼
Governance update / remapping
```

This does not automatically create a new identity.

Historical generation-time meaning should remain available where required.

---

## 73. Identity and State Changes

State may change through lifecycle operations:

```text id="c3n8m5"
State = 1
   │
   ▼
Lifecycle transition
   │
   ▼
State = 0
```

The identity remains:

```text id="y7q2p4"
Engine + Local ID
```

---

## 74. Identity and Database Location

A database or service may move an Engine's operational storage location.

For example:

```text id="r1m6c8"
Engine 42
   │
   ├── before → Database A
   │
   └── after  → Database B
```

The SMART ID does not change.

The deployment's routing map changes.

This is another reason to separate immutable identity from operational infrastructure.

---

## 75. Identity and Network Location

Network addresses are not encoded into the identity core.

Therefore:

```text id="w8p2m5"
SMART ID
   │
   ▼
Engine
   │
   ▼
Current infrastructure mapping
   │
   ▼
Network destination
```

The network address remains an operational concern.

---

## 76. Governance and Infrastructure

Governance metadata may be used by infrastructure tooling.

However, the implementation should not silently redefine:

```text id="n4c7x1"
Region
State
Version
```

as network-routing or security mechanisms unless that behavior is explicitly defined by the relevant system.

---

## 77. Identity Core Capacity

The identity core has:

```text id="q5m1r8"
50 bits
```

Therefore:

```text id="c7n3v6"
2^50
=
1,125,899,906,842,624
```

possible Engine + Local ID combinations.

This is the theoretical namespace size.

Operational limits may be smaller depending on Engine allocation, Local ID consumption, deployment policy, and reserved capacity.

---

## 78. Per-Engine Capacity

Each Engine has:

```text id="x2p8m4"
29-bit Local ID namespace
```

Capacity:

```text id="m6q1r9"
536,870,912 identifiers per Engine
```

The namespace is finite.

When exhausted:

```text id="v3c7n5"
FAIL HARD
```

No wraparound or reuse is permitted.

---

## 79. Engine Namespace

The Engine field provides:

```text id="k8m2p6"
21 bits
```

with:

```text id="r1q7c4"
2^21
=
2,097,152
```

possible Engine values.

The actual number of concurrently active Engines is a deployment decision.

---

## 80. Governance Capacity

The governance/metadata portion contains:

```text id="n5x3m8"
14 bits
```

distributed as:

```text id="p2q7c1"
Region    = 8 bits
State     = 1 bit
Reserved  = 4 bits
Version   = 1 bit
```

The Reserved portion is deliberately left without application semantics in v1.x.

---

## 81. Identity Extraction

Conceptually:

```text id="h8m3r6"
64-bit SMART ID
      │
      ├── bits 0–28  → Local ID
      │
      └── bits 29–49 → Engine
```

These two fields reconstruct the identity core.

The metadata fields can be decoded separately.

---

## 82. Governance Extraction

Conceptually:

```text id="c6p1v9"
64-bit SMART ID
      │
      ├── bits 50–57 → Region
      ├── bit 58     → State
      ├── bits 59–62 → Reserved
      └── bit 63     → Version
```

These fields do not replace the identity core.

---

## 83. Full Decode

A full SMART ID decode produces:

```text id="m7q2n5"
SMART ID
   │
   ├── Local ID
   ├── Engine
   ├── Region
   ├── State
   ├── Reserved
   └── Version
```

The semantic groups are:

```text id="x3c8p1"
Identity:
  Local ID + Engine

Governance / Metadata:
  Region + State + Reserved + Version
```

---

## 84. Decode Does Not Change Identity

Decoding fields is a read operation.

It does not alter the identifier.

Conceptually:

```text id="r6m2q8"
SMART ID
   │
   ▼
Decode
   │
   ├── Identity fields
   └── Metadata fields
```

The identifier remains immutable.

---

## 85. Comparison Semantics

The identity core provides the canonical identity comparison.

Conceptually:

```text id="n1c7m4"
Compare Engine
      +
Compare Local ID
      │
      ▼
Identity comparison
```

Metadata differences do not necessarily imply different identity.

The application must distinguish identity equality from metadata equality.

---

## 86. Example Metadata Difference

Two representations may conceptually contain:

```text id="p8q2r5"
Engine   = 20
Local ID = 300
Region   = 1
State    = 1
```

and:

```text id="m4c7n1"
Engine   = 20
Local ID = 300
Region   = 2
State    = 1
```

The identity core is the same:

```text id="x6v2q9"
Engine + Local ID = (20, 300)
```

Therefore Region alone does not define identity.

Whether such a representation can coexist as two distinct stored identifiers depends on the complete 64-bit value and implementation constraints; the specification does not treat Region as the identity key.

---

## 87. State Difference

Similarly:

```text id="k3m8p1"
Engine   = 20
Local ID = 300
State    = 1
```

versus:

```text id="q7n2c5"
Engine   = 20
Local ID = 300
State    = 0
```

represents the same identity core with different lifecycle state.

State is therefore not part of the identity definition.

A lifecycle transition should update the state semantics according to the implementation's persistence model.

---

## 88. Governance Changes and Audit

Governance-related changes should be auditable where required.

Examples include:

* lifecycle transitions;
* Region interpretation;
* operational Engine mapping;
* version handling.

Audit records should not rewrite historical SMART IDs.

---

## 89. No Hidden Identity Fields

The implementation should not silently add additional identity semantics to:

* Region;
* State;
* Reserved;
* Version.

If additional identity dimensions are required, they should be addressed explicitly through a specification change or an application-level identifier model.

---

## 90. No Hidden Routing Fields

Similarly, the implementation should not silently route on:

* Region;
* State;
* Reserved;
* Version.

The v1.4 routing selector is Engine.

---

## 91. No Hidden Security Fields

The SMART ID fields should not be treated as:

* password;
* authentication token;
* authorization credential;
* integrity signature.

Security controls remain separate.

---

## 92. Public Exposure

A SMART ID may be publicly exposed according to application requirements.

If exposure creates security or privacy concerns, the application may use an additional public representation.

That does not alter the internal identity semantics.

---

## 93. FPE and Standards

Where FPE is used:

> **SMART ID implementations MUST use format-preserving encryption and related cryptographic mechanisms in accordance with applicable internationally recognized and approved cryptographic standards and their current authoritative revisions.**

SMART ID does not define or require a proprietary cryptographic algorithm.

The implementation remains responsible for selecting appropriate standards-compliant mechanisms.

---

## 94. Certification Boundary

SMART ID itself does not claim that every implementation is cryptographically certified.

Compliance depends on:

* selected algorithm;
* cryptographic library;
* implementation;
* configuration;
* key management;
* deployment;
* applicable jurisdiction;
* applicable certification requirements.

Certification claims must therefore be made at the appropriate implementation and deployment level.

---

## 95. Control-Plane Boundary

The identity/governance model does not require a centralized allocator.

A reference implementation may use centralized control because it is practical.

However:

> **SMART ID does not mandate a particular Engine allocation or control-plane architecture.**

The client is responsible for ensuring authoritative and non-conflicting Engine ownership.

---

## 96. Fencing Boundary

Fencing is an implementation mechanism for enforcing the ownership invariant.

The invariant is:

```text id="z6p1m8"
One Engine
   │
   ▼
At most one authoritative active allocator
```

The exact fencing mechanism is not part of the identifier format.

---

## 97. Database Boundary

SMART ID does not require:

* MariaDB;
* MySQL;
* PostgreSQL;
* SQLite;
* a particular storage engine;
* a particular indexing strategy.

The v1.4 empirical findings used MariaDB/InnoDB, but those measurements are evidence for the tested environment only.

---

## 98. Deployment Boundary

SMART ID can be deployed in different environments.

Possible deployment patterns include:

```text id="p3n7c2"
Single service
Multi-service
Sharded database
Distributed application
Regional deployment
Hybrid infrastructure
```

The identifier semantics remain the same provided the v1.4 requirements are preserved.

---

## 99. Identity vs Infrastructure

The conceptual boundary is:

```text id="m8q1r5"
SMART ID
   │
   ▼
Immutable Identity
   │
   ▼
Engine + Local ID

Infrastructure
   │
   ▼
Current destination
```

Infrastructure may change.

The identity remains stable.

---

## 100. Final Conceptual Model

The v1.4 SMART ID model can be summarized as:

```text id="c5m9p2"
                       SMART 64-BIT ID
                              │
             ┌────────────────┴────────────────┐
             │                                 │
             ▼                                 ▼
      50-BIT IDENTITY CORE             14-BIT GOVERNANCE /
             │                              METADATA
       ┌─────┴─────┐                    ┌─────┴──────────┐
       │           │                    │        │       │
       ▼           ▼                    ▼        ▼       ▼
    Engine      Local ID              Region   State  Reserved
      21           29                   8       1       4
     bits         bits                 bits    bit     bits
                                             
                         Version = 1 bit
```

Operational semantics:

```text id="x7n2q4"
Engine
  │
  ▼
Routing destination

Engine + Local ID
  │
  ▼
Immutable identity

Region
  │
  ▼
Metadata / governance

State
  │
  ▼
Lifecycle

Reserved
  │
  ▼
Future governance

Version
  │
  ▼
Format generation
```

---

## 101. Final Invariants

The identity/governance boundary requires:

1. **Identity core = Engine + Local ID.**
2. **Identity core width = 50 bits.**
3. **Governance/metadata width = 14 bits.**
4. **Local ID occupies bits 0–28.**
5. **Engine occupies bits 29–49.**
6. **Region occupies bits 50–57.**
7. **State occupies bit 58.**
8. **Reserved occupies bits 59–62.**
9. **Version occupies bit 63.**
10. **Identity is immutable after generation.**
11. **Local IDs are never reused.**
12. **Local ID exhaustion results in failure rather than wraparound.**
13. **Engine ownership must remain authoritative and non-conflicting.**
14. **Region is metadata, not identity or routing.**
15. **State is lifecycle information, not identity or routing.**
16. **Reserved bits have no independent v1.x application semantics.**
17. **Version identifies format generation and is immutable.**
18. **FPE is separate from identity and routing semantics.**
19. **Authentication and authorization are separate security concerns.**
20. **Control-plane architecture remains an implementation choice.**

---

## 102. Conclusion

SMART 64-Bit ID v1.4 deliberately separates immutable identity from governance and metadata.

The **50-bit identity core** consists of:

```text id="r4m8c1"
Engine + Local ID
```

The **14-bit governance/metadata boundary** consists of:

```text id="n6q2p7"
Region + State + Reserved + Version
```

This separation provides clear semantic boundaries:

```text id="x3v9m5"
Identity
   │
   └── Engine + Local ID

Governance / Metadata
   │
   ├── Region
   ├── State
   ├── Reserved
   └── Version
```

Engine supports routing.

Local ID completes the identity within the Engine namespace.

Region provides generation-time metadata.

State represents lifecycle.

Reserved bits remain available for future governance.

Version identifies the format generation.

None of the governance/metadata fields replace the immutable identity core.

This identity-versus-governance model is locked for SMART ID Technical Specification v1.4.
