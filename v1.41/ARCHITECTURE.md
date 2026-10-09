# SMART 64-Bit ID — Architecture

**Technical Architecture v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document describes the architectural model surrounding SMART 64-Bit ID.

The architecture separates the responsibilities of the SMART identifier itself from the responsibilities of the client application, control plane, database, and security infrastructure.

SMART ID defines the identifier and its required semantics. It does not require a particular deployment topology or infrastructure vendor.

---

## 2. Architectural Model

At a conceptual level, a SMART ID system contains the following responsibilities:

```text
                    ┌─────────────────────────┐
                    │      Client / System     │
                    │                         │
                    │  Application / Service  │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │     Control Plane       │
                    │                         │
                    │ Engine ownership        │
                    │ Engine allocation       │
                    │ Local allocation policy │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │       SMART ID           │
                    │                         │
                    │ Engine + Local Identity │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │ Storage / Database      │
                    │                         │
                    │ Primary key + indexes   │
                    └─────────────────────────┘
```

This is a conceptual architecture rather than a mandatory deployment design.

An implementation may combine, separate, replicate, or distribute these responsibilities provided that the SMART ID invariants remain satisfied.

---

## 3. Architectural Boundary

### 3.1 SMART ID defines

SMART ID defines:

* the 64-bit identifier format;
* field positions and widths;
* identity semantics;
* Engine semantics;
* Local ID semantics;
* routing semantics;
* lifecycle semantics;
* uniqueness requirements;
* non-reuse requirements;
* persistence requirements;
* failure behavior; and
* the cryptographic standards boundary.

### 3.2 SMART ID does not define

SMART ID does not dictate:

* control-plane topology;
* Engine provisioning architecture;
* lease implementation;
* fencing implementation;
* database vendor;
* database topology;
* application framework;
* deployment platform;
* authentication system;
* authorization system;
* network topology;
* monitoring platform; or
* proprietary cryptographic algorithms.

These are implementation and deployment choices.

---

## 4. Control Plane

The control plane is responsible for managing the allocation and ownership information required by the client implementation.

Typical responsibilities may include:

* assigning Engine IDs;
* establishing authoritative Engine ownership;
* preventing conflicting ownership;
* managing leases or fencing;
* coordinating Engine rotation;
* monitoring allocator health;
* responding to Engine exhaustion; and
* maintaining operational state required for safe generation.

SMART ID does not require these responsibilities to be implemented by one centralized service.

A centralized control application is a valid implementation pattern, but it is not part of the mandatory SMART ID architecture.

---

## 5. Engine Ownership

Engine ownership is a fundamental architectural invariant.

At any time:

> **An Engine ID MUST have at most one authoritative active allocator.**

This prevents two independent authorities from generating Local IDs within the same Engine namespace.

The ownership mechanism may use:

* a centralized ownership record;
* a lease;
* a fencing token;
* an epoch;
* a consensus-backed coordination mechanism;
* a transactional ownership table; or
* another mechanism providing equivalent guarantees.

The mechanism itself is an implementation choice.

The required outcome is not.

---

## 6. Stale Ownership

Distributed systems may encounter:

* process crashes;
* delayed restarts;
* network partitions;
* expired sessions;
* delayed messages;
* duplicate service instances; or
* incomplete failure detection.

An implementation must prevent a stale allocator from continuing to generate identifiers after its authority has ended.

Where leases or fencing are used, an expired or fenced allocator must be unable to continue valid ID generation.

If authoritative ownership cannot be established unambiguously, generation must fail hard.

---

## 7. Engine Allocation

The Engine field contains 21 bits, providing:

**2^21 = 2,097,152 possible Engine IDs**

An Engine ID is assigned when an identifier is generated and remains immutable within that identifier.

The client/control plane is responsible for determining which Engine is assigned to a generation authority.

SMART ID does not prescribe how Engine IDs are provisioned.

---

## 8. Engine Rotation

Engine rotation is intended to distribute write activity across available Engine namespaces.

An implementation may rotate Engine ownership or allocation according to:

* capacity;
* workload;
* storage distribution;
* operational policy;
* geographic deployment;
* failure domains; or
* other application requirements.

Engine rotation must not compromise uniqueness or ownership guarantees.

A new Engine may be used when the Local ID namespace of an existing Engine is exhausted or when operational policy requires rotation.

---

## 9. Local Allocation

The Local ID occupies 29 bits.

Each Engine therefore provides:

**2^29 = 536,870,912 identifiers per Engine**

Local allocation must be persistent.

The allocator must ensure that an allocated Local ID cannot be allocated again within the same Engine ownership domain.

Allocation may occur:

* one identifier at a time;
* in batches;
* through a transactional allocator; or
* through another mechanism providing equivalent persistence and uniqueness.

---

## 10. Allocation and Commit Order

Allocation order and database commit order are conceptually separate.

For example, an implementation may reserve a batch of Local IDs before creating the corresponding records.

If a later transaction fails, unused or previously allocated values may remain as gaps.

This is acceptable.

SMART ID prioritizes:

1. uniqueness;
2. non-reuse;
3. persistence; and
4. correctness

over gapless sequential numbering.

---

## 11. Crash Recovery

A crash must not cause previously allocated Local IDs to become available again.

An implementation must persist sufficient allocation state to ensure that recovery advances from a safe point.

Possible outcomes after failure include:

```text
Allocated IDs
     │
     ├── committed record
     │
     └── failed operation
              │
              ▼
           GAP
```

A gap is acceptable.

Reusing the value is not.

---

## 12. Local ID Exhaustion

The 29-bit Local ID namespace is finite.

When all usable Local IDs for an Engine have been allocated, that Engine is exhausted.

The allocator must not wrap to zero or reuse earlier values.

Exhaustion is a **FAIL HARD** condition for that Engine.

Operational response may include:

* selecting another available Engine;
* provisioning another Engine;
* rotating ownership; or
* invoking another control-plane policy.

These responses are outside the identifier format itself.

---

## 13. Routing Architecture

SMART ID routing is based on fixed bit positions.

The conceptual path is:

```text
                    SMART ID
                       │
                       ▼
              ┌─────────────────┐
              │ Extract Engine  │
              │   bits 29–49    │
              └────────┬────────┘
                       │
                       ▼
                 Route to Engine
                       │
                       ▼
              ┌─────────────────┐
              │ Extract Local   │
              │   bits 0–28     │
              └────────┬────────┘
                       │
                       ▼
                Primary-key lookup
```

The Region field is not involved in this routing path.

The State field is not involved in routing.

---

## 14. Routing and Region Separation

Region is generation-time metadata.

It does not determine the Engine.

It does not determine the database shard.

It does not determine the routing destination.

An implementation may use Region independently for:

* reporting;
* governance;
* analytics;
* presentation;
* historical classification; or
* other application-level purposes.

Using Region as a routing selector would be an application-specific extension rather than SMART ID routing semantics.

---

## 15. Routing and State Separation

State is a lifecycle filter.

State values indicate whether the identifier is currently enabled or retired/disabled.

State does not select a routing destination.

The normal conceptual sequence is:

```text
SMART ID
   │
   ▼
Engine routing
   │
   ▼
Local/primary-key lookup
   │
   ▼
State evaluation
```

This prevents lifecycle state from being confused with physical routing.

---

## 16. Primary-Key Architecture

An implementation may use the complete 64-bit SMART ID as a primary key.

The Engine and Local fields provide routing and identity structure while the complete identifier remains available for exact lookup.

A conceptual database record may therefore contain:

```text
SMART_ID
ENGINE
LOCAL_ID
REGION
STATE
VERSION
PAYLOAD
```

The actual physical schema is implementation-specific.

The specification does not require these fields to be stored separately if equivalent behavior is provided.

---

## 17. Database Interaction

SMART ID is independent of database vendor.

A database implementation must nevertheless support the guarantees required by the allocation and storage model.

Relevant requirements include:

* persistent allocation state;
* appropriate concurrency control;
* uniqueness enforcement;
* crash-safe persistence;
* reliable primary-key storage; and
* suitable transaction semantics.

The reference empirical findings use MariaDB/InnoDB, but those technologies are not requirements of SMART ID.

---

## 18. Concurrency

Where multiple workers can allocate Local IDs within an Engine, the implementation must provide an authoritative serialization or equivalent concurrency-control mechanism for the allocation state.

Possible mechanisms include:

* row-level locking;
* transactional sequence allocation;
* serialized allocation service;
* atomic compare-and-swap mechanisms;
* distributed coordination; or
* another mechanism providing equivalent uniqueness guarantees.

The specification does not require a particular mechanism.

The required property is that concurrent allocation cannot produce duplicate Local IDs under the same authoritative Engine.

---

## 19. Distributed Generation

SMART ID can be used in systems with multiple generation authorities provided that Engine ownership remains unambiguous.

The distributed model is therefore conceptually:

```text
                 Control Plane
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
       Engine A    Engine B    Engine C
          │           │           │
          ▼           ▼           ▼
       Local IDs   Local IDs   Local IDs
```

Each active Engine must have a single authoritative allocator.

Multiple Engines may operate concurrently.

Multiple authoritative allocators for the same Engine may not.

---

## 20. Failure Domain

SMART ID treats identity duplication as more severe than allocation interruption.

When an implementation cannot guarantee uniqueness, it should stop generation rather than continue with uncertain state.

Examples of hard-failure conditions include:

* conflicting Engine ownership;
* duplicate Engine ownership;
* duplicate Local ID detection;
* Local ID counter corruption;
* exhausted Local namespace;
* ambiguous allocator authority; or
* recovery state that cannot establish a safe non-reuse point.

Operational systems may retry after authority or state has been safely restored.

---

## 21. Identity Transfer

SMART ID does not modify an existing identifier when ownership or identity responsibility changes in a way that requires a new identifier.

The conceptual process is:

```text
Existing SMART ID
       │
       ▼
Transfer / replacement event
       │
       ▼
Generate NEW SMART ID
       │
       ├──────────────► New identity enabled
       │
       ▼
Old SMART ID
State = 0
       │
       ▼
Permanently retired
```

The old identifier must not be reused.

This preserves historical identity relationships while allowing the current identity to change.

---

## 22. Public Identifier Architecture

SMART ID may be used directly as a public identifier or may be wrapped by an application-level public-ID mechanism.

Where FPE is used:

```text
Internal SMART ID
        │
        ▼
Cryptographic public-ID layer
        │
        ▼
External representation
```

The cryptographic layer is separate from SMART ID routing.

A public representation must not be interpreted as providing authentication or authorization by itself.

---

## 23. Security Architecture Boundary

SMART ID is not an authentication protocol.

It is not an authorization framework.

It does not define:

* user authentication;
* service authentication;
* session management;
* access-control policy;
* key storage;
* secret rotation;
* transport encryption; or
* application security policy.

These functions belong to the surrounding system.

Implementations using public identifiers must select appropriate cryptographic and security mechanisms according to applicable standards and deployment requirements.

---

## 24. Deployment Independence

SMART ID can be integrated into different deployment models.

Examples include:

* a single database;
* multiple database instances;
* database shards;
* multiple application services;
* geographically distributed systems;
* cloud deployments;
* on-premises deployments; or
* hybrid systems.

These are deployment choices.

The SMART ID invariants remain unchanged.

---

## 25. Reference Control-Plane Pattern

A practical implementation may use a centralized control application:

```text
                 ┌──────────────────┐
                 │ Control Service  │
                 └────────┬─────────┘
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
          Engine 1     Engine 2     Engine 3
             │            │            │
             ▼            ▼            ▼
          Allocator    Allocator    Allocator
             │            │            │
             └────────────┼────────────┘
                          ▼
                    SMART IDs
```

This pattern can simplify authoritative ownership management.

However, it is explicitly an **implementation pattern**, not a mandatory SMART ID architectural requirement.

---

## 26. Architectural Invariants

The following invariants are mandatory:

### Invariant 1 — Engine Ownership

At most one authoritative active allocator may own an Engine at any time.

### Invariant 2 — Local Uniqueness

A Local ID may not be allocated twice within the same authoritative Engine namespace.

### Invariant 3 — Non-Reuse

An allocated SMART ID must never be reused.

### Invariant 4 — No Wraparound

Local ID exhaustion must not cause counter wraparound.

### Invariant 5 — Hard Failure

A condition capable of producing duplicate identity must result in generation failure.

### Invariant 6 — Routing Separation

Region and State must not alter the defined Engine → Local routing path.

### Invariant 7 — Lifecycle Separation

Retirement changes lifecycle state; it does not make the identifier available for reuse.

### Invariant 8 — Version Integrity

The Version field must be interpreted according to the applicable SMART ID specification.

---

## 27. What the Architecture Guarantees

When correctly implemented, the architecture provides:

* deterministic Engine extraction;
* deterministic Local ID extraction;
* Engine-scoped allocation;
* persistent allocation;
* non-reuse;
* explicit lifecycle retirement;
* controlled distributed generation; and
* a clear separation between identifier semantics and surrounding infrastructure.

The architecture does not guarantee:

* universal database performance;
* universal storage savings;
* universal network performance;
* automatic security;
* automatic high availability;
* automatic disaster recovery; or
* a particular distributed-systems topology.

Those properties depend on implementation and deployment.

---

## 28. Summary

SMART 64-Bit ID is intentionally designed as an identifier specification with a defined architectural boundary.

The identifier defines:

**Identity → Engine → Local ID → Lifecycle**

while the surrounding client/control plane determines how Engine ownership, provisioning, persistence, deployment, and operational recovery are implemented.

The central architectural rule is:

> **The implementation may choose its control-plane architecture, but it must guarantee authoritative Engine ownership, Local ID uniqueness, persistence, non-reuse, and hard failure when those guarantees cannot be maintained.**

SMART ID v1.4 therefore separates the fixed technical invariants of the identifier from implementation-specific infrastructure decisions.

