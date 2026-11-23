# SMART 64-Bit ID v1.42 — Technical Package

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010
**Normative source:** `SPECIFICATION.md`
**Error registry:** `errors/ERROR-CODES.md`

This folder contains the supporting technical package for the v1.42 profile. The normative
specification governs if a summary, diagram, example, test vector, or explanatory document
differs from it.

## Start here

- Normative specification — `SPECIFICATION.md`
- Error codes — `errors/ERROR-CODES.md`
- QDH specification — `QDH-SPECIFICATION.md`
- QDH error codes — `QDH-ERROR-CODES.md`
- QDH logging and lifecycle — `QDH-LOGGING-AND-LIFECYCLE.md`
- Architecture — `ARCHITECTURE.md`
- Normative rules summary — `RULES.md`
- Serialization and security boundary — `STANDARDS.md`
- Limitations and non-guarantees — `LIMITATIONS.md`
- Industry alignment — `INDUSTRY_ALIGNMENT.md`
- Technical overview — `papers/SMART_64BIT_ID_TECHNICAL_OVERVIEW_v1.42.md`
- Bibliography — `BIBLIOGRAPHY.md`
- Release evidence record — `RELEASE-CHECKLIST.md`
- Operator deployment checklist — `OPERATOR-CHECKLIST.md`
- Response to technical review — `REVIEW-RESPONSE.md`

## Schemas

- MySQL 8.0.16+ — `qdh_schema_mysql.sql`, deployed into a database named `qdh_schema`
- PostgreSQL 11+ — `qdh_schema_postgresql.sql`

Both build in a single pass against an empty database.

## Diagrams

- Bit layout — `diagrams/bit-layout.md`
- Identity core and control area — `diagrams/identity-vs-governance.md`
- Routing flow — `diagrams/routing-flow.md`

## Examples and test vectors

- Generation example — `examples/generation-example.md`
- Test vectors — `examples/test-vectors.md`
- Routing example — `examples/routing-example.md`
- Integration patterns — `examples/integration-patterns.md`
- Audit hash vectors — `tests/golden/audit_hash_vectors.json`

Test vectors describe expected outcomes. Their presence in this package does not, by itself,
establish that an implementation has been tested or conforms.

## Core facts

- The 54-bit Identity Core is Class + Engine + Local, and it is the uniqueness key. A Virtual
  Engine is identified by Class + Engine; its Local namespace is unique only within that Virtual
  Engine. Two coordinates are distinct if any component differs, so `(1, 120, 500)` and
  `(2, 120, 500)` are different identities.

- Each supported Class has its own independent 21-bit Engine pool. The same numerical Engine
  value in two Classes is two different Virtual Engines. Engine numbers are unique only within a
  Class pool.

- In v1.42 the Class field carries the encoded taxonomy value. Encoded Class `0000` is invalid;
  `1001`–`1111` is reserved. The encoded Class must agree with the authoritative Class-property
  record; disagreement is a hard stop (`S64-E007`).

- Each Virtual Engine is permanently bound to one Class. The binding must not be changed, and an
  allocated identity must not be transferred to a different Class without retirement and
  reallocation (`S64-E015`).

- The normative routing selector is Class + Engine. The Virtual Engine ID is the 25-bit
  concatenation of Class and Engine, resolving through the Virtual Engine control table to the
  network address of the hosting node. A network or hardware address is a locator: it is not
  identity and does not authenticate a host.

- Role is immutable for the allocated identifier, and is consumed by the application-domain layer
  rather than by routing or allocation. A designation change is expressed by retirement and
  reallocation, with the Class unchanged.

- Allocation and retirement follow the sequence in `SPECIFICATION.md` §10.5: the successor is
  allocated inactive, its Class-property record is created, the history chain is linked, and only
  then does the source retire and the successor activate. At most one identifier in a chain is
  resolvable at any time.

- State (active/retired) is a record-level property and is not encoded in the 64-bit identifier.
  Workflow status such as "on hold" is allocator-level.

- Profile provenance is recorded per identity and per generation. A profile upgrade opens a new
  generation and does not invalidate identities allocated before it; `S64-E030` compares an
  identity against the profile of the generation in which it was allocated, not against the
  engine's current profile.

- A consumed Local coordinate is never reused, including across reclamation. The first
  never-consumed coordinate is established from durable evidence, never by a last-ID lookup.

- A coordinate-consumption tombstone is retained permanently, independent of the retention period
  for the full retired record.

- Reserved bits 54–57 must be zero in v1.42. Bit 54 remains Reserved; the 5-bit Class expansion is
  deferred.

- Canonical binary serialization is unsigned 64-bit big-endian network byte order.

- v1.41 and v1.42 are the active profiles of the Version 0 family and coexist. Revision `0000`
  (v1.4) is obsolete and unsupported (`S64-E002`). Cross-profile identifiers are rejected at
  profile identification; field-level incompatibilities are informative, profile selection is
  decisive.

## Rollover and failure handling

- When a Local namespace is exhausted, rollover searches Engine numbers numerically greater than
  the exhausted Engine, ascending, within the same Class pool. Lower numbers are never revisited;
  there is no wraparound.

- A candidate is a Virtual Engine in `STATE_UNALLOCATED`, or an existing engine whose prior
  allocator authority has been conclusively invalidated before adoption. An engine under a live
  lease is never a candidate (`S64-E020`).

- A forward reservation must exist before the final Local coordinate is issued; rollover is not a
  failure-recovery path.

- `S64-E022` reports a completed rollover with a safely reserved target. `S64-E029` reports
  terminal pool exhaustion, which can occur before Engine 2,097,151.

- If authoritative state or reservation safety cannot be established, allocation fails closed with
  `S64-E021`. It must not infer a target or declare exhaustion.

- A power cut or hardware failure invokes `FAIL_HARD`: no identifier is issued, no last-ID lookup,
  no automatic resume or retry.

## QDH — quarantine, database engineering, hardware engineering

`FAIL_HARD` remains an operational outcome. Under v1.42 it is recoverable only through the QDH
lifecycle in `QDH-SPECIFICATION.md`: quarantine, durable-evidence verification of the first
never-consumed coordinate, hardware sanitization and attestation, atomic epoch commit, then
controlled reactivation with a new epoch-bound lease. Reclamation never reuses a coordinate and
never changes the engine's profile. Engines permanently retired under pre-v1.42 rules are not
eligible.

## Project and legal documents

- Version 1.42 changelog — `CHANGELOG.md`
- License — `LICENSE`
- Copyright notice — `COPYRIGHT`
- Commercial license terms — `COMMERCIAL-LICENSE.md`
- Contributing guide — `CONTRIBUTING.md`
- Contributor License Agreement — `CLA.md`
- AI contribution policy — `AI_CONTRIBUTIONS.md`

## Compatibility with Release Candidate 1

RC1 of this profile remains supported. Identifiers allocated under RC1 remain valid and require no
migration or re-issue, and both candidates carry Revision `0010`.

RC1 and RC2.2 are therefore indistinguishable on the wire, and profile selection cannot tell them
apart. Two emission behaviours differ:

- profile provenance is `S64-E030` here; RC1 reported that condition as `S64-E015`, which retains
  its original Class-binding meaning;
- an inadmissible lifecycle transition is `S64-E031`; RC1 had no code for it.

A peer may report a different code for the same condition while both claim `0010`. That is a
documented compatibility note, not a conformance failure of RC1. Implementations built against RC1
must adopt `S64-E030` and `S64-E031` before claiming conformance to this revision.

## Release status and conformance

This package is Release Candidate 2, finalized for publication. Documentation does not establish
implementation conformance, certification, or production readiness. Before making a conformance
claim, review the complete package, validate cross-references, run the test vectors and the golden
audit vectors against the implementation, and retain evidence of the results. Use
`RELEASE-CHECKLIST.md`.
