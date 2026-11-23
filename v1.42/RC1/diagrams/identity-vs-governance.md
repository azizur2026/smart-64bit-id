# SMART 64-Bit ID v1.42 — Identity vs Governance

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Diagrammatic reference for the boundary between identity structure and governance in v1.42

## 1. Purpose

This file presents, in diagrammatic form, the boundary between what the v1.42 profile defines and what the adopting system or authority defines.

The profile defines the identifier: its bit layout, the meaning of its fields, the invariants that must hold for an allocated identifier across its lifetime, the conditions under which an identifier is valid under this profile, and the properties that routing and allocation must preserve. It does not define the systems that implement it, the ontology that Class labels presuppose, the criteria by which an entity is designated self-representing or dependent, the physical or administrative machinery of routing and allocation, or the governance under which any of these are determined (§1).

This file is a reference aid. Where it and the specification differ, the specification governs.

## 2. The two sides

```text
┌─────────────────────────────────────────┐   ┌─────────────────────────────────────────┐
│            IDENTITY (profile)           │   │          GOVERNANCE (adopting           │
│                                         │   │           system / authority)           │
│  what the 64-bit identifier is          │   │  what the adopting system or            │
│  and what must hold for it              │   │  authority determines around it         │
└─────────────────────────────────────────┘   └─────────────────────────────────────────┘
                     │                                         │
                     │      the profile states properties      │
                     │      the system must preserve when      │
                     │      it operates on identifiers         │
                     └──────────────────┬──────────────────────┘
                                        │
                                        ▼
                          ┌───────────────────────────┐
                          │   allocated identifier    │
                          │   (the meeting point)     │
                          └───────────────────────────┘
```

The profile and the governance are not in conflict. They are at different layers. The profile states the properties that must hold; the governance determines the content that fills those properties for a given deployment.

## 3. What the profile defines (identity side)

| Element | What the profile defines | Spec ref |
|---|---|---|
| Bit layout | The 64-bit positions of Local, Engine, Class, Reserved, Role, Revision, Version. | §2 |
| Identity Core | Class + Engine + Local = 54 bits, stable for the allocated identifier. | §3 |
| Class encoding | The binary values 0001–1000 and their labels; 0000 invalid; 1001–1111 reserved. | §5.2 |
| Class agreement | The encoded Class MUST agree with the authoritative Class-property record. | §5.3 |
| Engine–Class binding | Each Engine is bound to exactly one Class; multiple Engines may share a Class. | §6.3 |
| Virtual engine | Class + Engine = 25-bit routing key, mapped to a physical engine address. | §8 |
| Role | 0 = dependent, 1 = self-representing; immutable per allocated identifier. Role is consumed by the application domain layer, not by routing or allocation. | §4 |
| Role change path | Retirement and reallocation, with Class unchanged. Allocation precedes retirement; at most one identifier in a history chain is resolvable at any time. | §4.1, §10.5 |
| Allocation invariants | Local non-reuse within an Engine; no coordinate collision; retired coordinate permanently consumed; permanent coordinate tombstone. | §7, §10.2, §10.3 |
| History chain | Each identifier records the identifier it replaced; at most one identifier in a chain is resolvable at any time. | §10.6 |
| Retention | Retired records retained indefinitely while the allocating profile remains in force; tombstone retained permanently. | §10.3, §10.4 |
| Profile coexistence | v1.4, v1.41, v1.42 coexist; rejection at profile identification; field-level incompatibility is informative. | §13 |
| Serialization | Unsigned 64-bit, big-endian, network byte order. | §15 |
| Validation order | Identifier validation: input → profile → field → authoritative → routing. Administrative validation is a separate procedure. | §16.1, §16.2 |

These are the properties the profile requires. An implementation that cannot preserve them cannot claim conformance (§18).

## 4. What the profile does not define (governance side)

| Element | What the profile does not define | Spec ref |
|---|---|---|
| Class ontology | What a Human, an AI, an Organization, or a Natural / Celestial Object is; criteria for Class membership; authority to determine an entity's Class. | §5.2 |
| Role designation criteria | The legal, organizational, technical, or governance criteria for designating an entity as self-representing or dependent. | §4 |
| Allocation machinery | How Local IDs are allocated, by what mechanism, under what authority. | §7 |
| Workflow status mechanism | How the allocator holds a record non-resolvable during a transition (e.g., "on hold"). The property is normative; the mechanism is not. | §10.1, §10.5 |
| Virtual-engine mechanism | How the virtual-engine table is stored, maintained, or updated. | §8 |
| Physical placement | How physical engines are addressed, reached, or rearranged for load balancing, subject to the Class-binding property. | §8, §6.3 |
| Routing protocol | Transport, message format, retry, caching, or error-reporting mechanism. | §8 |
| Retention mechanism | Storage technology, archive format, or retention duration beyond the profile-conditional requirement. | §10.3 |
| Lifecycle tooling | How retirement, reallocation, and lifecycle history are implemented. | §10 |
| Governance of Reserved values | Any classification authority for the reserved Class values 1001–1111. | §5.2, §14 |
| Law and policy | Any legal, organizational, or governance status of any identified entity. | §4 |

The profile does not adjudicate any of these. A conformance claim under the profile is not an assertion about any of them (§1, §4, §5.2).

## 5. The meeting point: an allocated identifier

An allocated identifier sits at the intersection. The profile determines its structure and the properties that must hold. The governance determines, for a given deployment, which entity receives the identifier, which Class is assigned to that entity's Engine, which Role is designated, and which authority makes those determinations.

```text
                     profile defines                governance determines
                     ───────────────                ──────────────────────
   bit layout             ✓
   field meanings         ✓
   Identity Core          ✓
   Engine–Class binding   ✓
   allocation invariants  ✓
   history chain          ✓
   retention              ✓
   validation order       ✓

   which entity gets it                                  ✓
   which Class is assigned                               ✓
   which Role is designated                              ✓
   which authority decides                               ✓
   what "Human" means                                    ✓
   what "self-representing" means                        ✓
   how allocation is implemented                         ✓
   how routing is implemented                            ✓
   how retention is implemented                          ✓
```

The profile requires that whatever the governance determines, the resulting identifier satisfies the profile's properties. It does not require, and cannot verify, that the governance's determinations are correct in any external sense.

## 6. Class: encoded value vs taxonomy authority

The Class field is the clearest case of the boundary, and the easiest to misread, so it is drawn separately.

```text
   encoded Class (bits 50–53)               Class-property record
   ─────────────────────────                ──────────────────────
   the profile assigns the binary           the adopting system maintains
   values and their labels                  this record for each identity

                    └──────────┬──────────┘
                               │
                               ▼
                    MUST agree (§5.3)
                    disagreement = S64-E007 CLASS_MISMATCH
```

The profile assigns the binary values and their labels. It requires that the encoded Class agree with the authoritative Class-property record. It does not define an ontology, does not establish criteria for Class membership, and does not confer authority on any party to determine an entity's Class (§5.2).

The assignment of a Class to an allocated identity is an external governance act. The profile requires only that the encoded Class agree with the authoritative record.

## 7. Role: encoded designation vs designation criteria

The Role field is the second case, drawn on the same pattern.

```text
   Role bit (58)                            designation criteria
   ─────────────                            ────────────────────
   the profile encodes 0 = dependent,       the adopting system or authority
   1 = self-representing                    determines which applies

                    └──────────┬──────────┘
                               │
                               ▼
                    Role is immutable for the allocated identifier (§4.1)
                    change = retirement + reallocation
```

The profile encodes the designation. It does not define the criteria by which a designation is made, and a conformance claim under the profile is not an assertion that a particular designation is correct for a particular entity (§4).

A change of designation is a governance event. The profile requires that it be expressed by retirement and reallocation, with Class unchanged, not by rewriting the identifier (§4.1). Role is consumed by the application domain layer; it is not read by the routing or allocation layers.

## 8. Why the boundary is drawn this way

The profile is a version-scoped specification. It can state properties and require them of adopting systems. It cannot verify what it cannot observe: whether a given entity is correctly classified, whether a designation is legally correct, whether an allocation mechanism is safe in a way the profile can test, or whether a retained record survives a decade of operational change.

Drawing the boundary explicitly does two things. First, it prevents a reader from believing the profile licenses or forbids things it is silent on. Silence is not permission (§10.4). Second, it prevents a conformance claim under the profile from being read as an assertion about matters the profile does not adjudicate.

The boundary is not a disclaimer. It is a precise statement of what the profile is accountable for and what the adopting system is accountable for.

## 9. Summary

The v1.42 profile defines the identifier: its bit layout, field meanings, Identity Core, Class encoding and agreement requirement, Engine–Class binding, virtual-engine routing key, Role encoding and immutability, allocation invariants, history chain, retention requirement, profile coexistence, serialization, and validation order.

The adopting system or authority determines the content: which entity receives an identifier, which Class is assigned, which Role is designated, what the Class labels mean, what the designation criteria are, and how allocation, routing, and retention are implemented.

The meeting point is the allocated identifier. The profile requires that it satisfy the profile's properties. The governance determines what fills those properties for a given deployment.
