# SMART 64-Bit ID v1.42 — Technical Package

**Status:** Release Candidate 1 — cross-check in progress  
**Profile:** Version 0, Revision 0010  
**Normative source:** `SPECIFICATION.md`

This folder contains the supporting technical package for the v1.42 profile. The normative specification governs if a summary, diagram, example, test vector, or explanatory document differs from it.

## Start here

- Normative specification — `SPECIFICATION.md`
- Architecture — `ARCHITECTURE.md`
- Normative rules summary — `RULES.md`
- Serialization and security boundary — `STANDARDS.md`
- Limitations and non-guarantees — `LIMITATIONS.md`
- Industry alignment — `INDUSTRY_ALIGNMENT.md`
- Error codes — `errors/ERROR-CODES.md`
- Technical overview — `papers/SMART_64BIT_ID_TECHNICAL_OVERVIEW_v1.42.md`
- Bibliography — `BIBLIOGRAPHY.md`
- Release checklist — `RELEASE-CHECKLIST.md`

## Diagrams

- Bit layout — `diagrams/bit-layout.md`
- Identity core and control area — `diagrams/identity-vs-governance.md`
- Routing flow — `diagrams/routing-flow.md`

## Examples and test vectors

- Generation example — `examples/generation-example.md`
- Test vectors — `examples/test-vectors.md`
- Routing example — `examples/routing-example.md`
- Integration patterns — `examples/integration-patterns.md`

Test vectors describe expected outcomes. Their presence in this package does not, by itself, establish that an implementation has been tested or conforms to the specification.

## Core facts

- The 54-bit Identity Core consists of Class + Engine + Local.

- In v1.42, the Class field carries the encoded taxonomy value. Encoded Class `0000` is invalid; `1001`–`1111` is reserved. The encoded Class must agree with the authoritative Class-property record associated with Engine + Local. A disagreement requires the specified hard-stop behavior.

- Each Engine is bound to exactly one Class. Multiple Engines may be bound to the same Class, but an Engine must not be bound to more than one Class. An existing Engine must not be reclassified or reassigned to another Class. A Class change requires a new Engine.

- The allocation uniqueness coordinate is Engine + Local; Class does not partition the allocation namespace. A canonical Engine + Local coordinate must not be allocated more than once, regardless of record lifecycle state.

- The normative routing selector is Class + Engine. The virtual-engine ID is the 25-bit concatenation of Class and Engine, mapped to a physical engine address.

- Role occupies the upper 10 bits structurally but is semantically immutable for an allocated identifier. Role is not immutable for the entity: a designation change is expressed through the specified retirement and reallocation workflow, with the Class value unchanged. Role is consumed by the application-domain layer, not by routing or allocation.

- Allocation and retirement follow the transition rules in `SPECIFICATION.md`. The new identifier is created inactive, linked into the history chain, activated, and then the source identifier is retired, subject to the specified atomicity and lookup requirements. At most one identifier in a history chain may be resolvable as the current identity at any time.

- State (active/retired) is a record-level property, not encoded in the 64-bit identifier. Workflow status during a transition, such as “on hold,” is allocator-level and implementation-specific.

- A retired Engine + Local coordinate is permanently consumed and must not be reissued under any profile of the SMART 64-Bit ID family. There is no release point. A coordinate-consumption tombstone is retained permanently.

- A retired record is retained indefinitely for as long as required by the profile under which it was allocated.

- Reserved bits 54–57 must be zero in v1.42. Bit 54 remains Reserved; the 5-bit Class expansion is deferred.

- Canonical binary serialization is unsigned 64-bit big-endian/network byte order.

- v1.4, v1.41, and v1.42 are separate profiles. They coexist; none supersedes another. Under normal validation, a cross-profile identifier is rejected at profile identification because its Version/Revision does not select the target profile. Field-level incompatibilities are informative; profile selection is decisive.

## Rollover and failure handling

- When a Local namespace is exhausted, rollover searches for the lowest eligible Engine ID numerically greater than the exhausted Engine ID. Lower Engine IDs are never revisited.

- Engine IDs bound to another Class are skipped and never reclassified or reassigned. An Engine ID already bound to the requested Class is eligible only if it has at least one unconsumed Local identifier.

- An unbound Engine ID may be selected only if its binding to the requested Class is established atomically before allocation and remains immutable thereafter. Reservation must prevent concurrent allocators from claiming the same target incompatibly or committing duplicate coordinates.

- `E022` applies only when a valid eligible forward target has been found and safely reserved. `E029` applies only when authoritative state establishes that no eligible forward Engine ID remains. This can occur before the maximum numeric Engine ID is reached.

- If authoritative state is unavailable or target eligibility and reservation safety cannot be established, the allocator must fail closed using the applicable specified error. It must not infer a valid target or terminal exhaustion without the required evidence.

- A power cut or hardware failure affecting allocation state or integrity requires `FAIL_HARD`. No identifier may be issued, no last-ID lookup may be used to continue allocation, and no automatic resume or retry is permitted.

The normative specification and error registry define the applicable precedence and outcomes. This summary does not replace those definitions.

## Project and legal documents

- Version 1.42 changelog — `CHANGELOG.md`
- License — `LICENSE`
- Copyright notice — `COPYRIGHT`
- Commercial license terms — `COMMERCIAL-LICENSE.md`
- Contributing guide — `CONTRIBUTING.md`
- Contributor License Agreement — `CLA.md`
- AI contribution policy — `AI_CONTRIBUTIONS.md`

These documents accompany the v1.42 technical package. The normative requirements for the identifier format remain defined by `SPECIFICATION.md`.

## Release status and conformance

This package is marked Release Candidate 1 while cross-checking remains in progress. Documentation updates alone do not establish implementation conformance, security certification, or production readiness.

Before making a conformance or release claim, review the complete package, validate cross-references, run applicable test vectors against the implementation, and retain evidence of the results. Use `RELEASE-CHECKLIST.md` to track the required checks.

If this README conflicts with the normative specification, `SPECIFICATION.md` takes precedence.
