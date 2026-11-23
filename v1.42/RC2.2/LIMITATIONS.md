# SMART 64-Bit ID v1.42 — Limitations and Non-Guarantees

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010

This note clarifies the boundaries of the format and its governance model. It does not amend
`SPECIFICATION.md`.

## 1. No time-ordering guarantee

The v1.42 layout contains no timestamp field. Numeric order therefore does not represent
generation-time order. The format does not promise time-sortability or encode creation time.
Applications needing temporal metadata must maintain it separately.

## 2. Uniqueness depends on correct namespace governance

The uniqueness coordinate is the 54-bit Identity Core: Class + Engine + Local. The bit layout alone
cannot prevent two independent authorities from assigning the same coordinate. Implementations need
authoritative Engine-pool assignment and crash-safe, non-reusing Local allocation.

Each Class has its own 21-bit Engine pool, so the same Engine number in two Classes is two different
Virtual Engines. v1.42 states that binding as a property; it does not define the authority that
registers Engine numbers or that decides which Class an Engine belongs to. Permanently retiring an
Engine number, and duplicating the control table so that a v1.41 engine's Class survives node loss,
are governance and deployment obligations that the profile states as requirements but does not
implement.

## 3. Class is not a universal ontology

Class is a four-bit encoded taxonomy value defined by SMART. It does not prove an entity's legal
status, ownership, biological nature, authority, or external classification.

Because each Class has an independent Engine pool, Class is part of the uniqueness coordinate rather
than a label attached to it: `(1, 120, 500)` and `(2, 120, 500)` are different identities. The
profile assigns the binary values and their labels; it does not adjudicate membership in a Class.

## 4. Routing scope

The normative routing selector is Class + Engine. Local is looked up within the resolved Virtual
Engine namespace. The Virtual Engine ID is the 25-bit concatenation of Class and Engine: a row in the
control table, not a hash.

Network and hardware addresses are locators only. The profile does not define the physical
resolution mechanism, the administrative tooling for placement changes, or the address-allocation
practice behind them. Those belong to the surrounding system, subject to the Class-binding property
and the rule that an address never serves as identity or as authentication.

## 5. Role is not a relationship graph

Role is an immutable per-identifier designation. It does not encode ownership, a parent/child
graph, legal agency, or the identity of an associated device or person. Those relationships require
external records.

Role is fixed for the allocated identifier but not for the entity; a change of designation is
expressed by retirement and reallocation. The profile does not define the criteria by which a
designation is determined. Role is consumed by the application domain layer and is not read by the
routing or allocation layers.

## 6. No authentication, secrecy, or authorization

A SMART ID is not a credential and does not authenticate its presenter. The format provides no
encryption, signatures, access control, or proof of ownership. In v1.42 the Class field directly
exposes the entity category to anyone able to inspect the identifier; applications with
confidentiality requirements should account for that.

## 7. No universal performance claim

The identifier layout alone does not guarantee faster queries, smaller indexes, lower CPU cost, or
superior throughput compared with UUIDs, Snowflake-like IDs, or other schemes. Results depend on
schema, workload, database engine, indexing, hardware, caching, concurrency, and allocation design.

Because Class and Engine occupy the most-significant bits, concurrent inserts across different
Classes produce scattered B-tree page writes. This is an inherent trade-off of spatial prefix
routing: the prefix that makes routing fast also makes multi-class inserts non-sequential at the
index layer. Mitigation is a database-layer concern, not an identifier-format concern.

## 8. Infrastructure remains implementation-specific

v1.42 defines the QDH lifecycle normatively: quarantine, database-engineering verification, hardware
sanitization and attestation, atomic epoch commit, and controlled reactivation. It does not define
the database product, the attestation technology, the sanitization tooling, the anchor service, the
consensus mechanism, or the deployment topology that implement those steps.

An implementation must preserve the normative properties while choosing its own infrastructure. A
QDH process that cannot establish durable evidence, host fitness, or lease revocation must suspend
allocation rather than proceed.

## 9. Retention cost and identifier-lifecycle alignment

In v1.42 a retired Identity Core is permanently consumed, and a retired record must be retained for
as long as the profile under which it was allocated remains in force. A coordinate-consumption
tombstone must be retained permanently, independent of the full record's retention. These are
normative properties, not choices, and their operational cost grows monotonically with the number of
retirements. QDH reclamation does not relieve this cost: it resumes allocation above the first
never-consumed coordinate and never releases a consumed one.

SMART v1.42's retirement model is consistent with established identifier-lifecycle practice. GS1
requires that an allocated GTIN shall not be reallocated to another trade item; the earlier four-year
non-reuse period has been deprecated, with narrow exceptions for items never produced and withdrawn
items reintroduced unchanged. NIST SP 800-53 IA-4 requires organizations to prevent reuse of
identifiers for an organization-defined period, defining this as preventing assignment of previously
used identifiers to different individuals, groups, roles, or devices. ISO 8000-115:2024 specifies
identifier syntax and resolution principles while leaving the methods of creation and resolution
outside its scope. SMART v1.42 follows the same direction: a retired coordinate is consumed
permanently, with no release point. This is affordable because each Virtual Engine has a 2^29
namespace. The profile does not prescribe the resolution or allocation mechanism, consistent with
the boundary ISO 8000-115 draws. See `BIBLIOGRAPHY.md`.

## 10. Profile coexistence and mutual invalidity

v1.41 (`Version 0, Revision 0001`) and v1.42 (`Version 0, Revision 0010`) are the active profiles of
the Version 0 family and coexist; neither supersedes the other. Revision `0000` (v1.4) is obsolete
and unsupported.

Under normal validation a cross-profile identifier is rejected at profile identification because its
Version/Revision does not select the target profile. This is the decisive rejection. Independently,
if force-read under the other profile's field rules, a v1.42 identifier has nonzero Class-marker bits
under v1.41 rules, and a v1.41 identifier has encoded Class `0000` under v1.42 rules. The field-level
observation is informative; profile selection is normative. An implementation must not treat a
failed validation under one profile as evidence that an identifier belongs to another.

## 11. QDH assurance boundaries

QDH is a controlled recovery process, not a proof of correctness. Four limits should be stated
plainly:

- A hash-chained audit trail provides tamper-evidence only. Non-repudiation against a privileged
  database attacker requires external anchoring of root hashes to a store outside that attacker's
  control. An implementation that does not anchor externally must not claim non-repudiation.

- Hardware attestation is only as strong as the trust roots it accepts. A revoked, expired, stale, or
  non-allowlisted root must block reactivation; a deployment that cannot revoke a root independently
  of the orchestrator loses the guarantee.

- Sanitization follows the operator's policy under NIST SP 800-88 vocabulary. The profile requires
  the two-stage verification and validation model; it does not certify that a given hardware
  platform achieves a given assurance level.

- If durable evidence of the first never-consumed coordinate is lost, reclamation must suspend. QDH
  has no mechanism to reconstruct consumption from identifiers or from a last-ID lookup, and it must
  not pretend otherwise.

## 12. Research boundary

Historical benchmark notes outside this package document their own test conditions and limitations.
They are not evidence of v1.42 performance unless a new study explicitly defines and tests the v1.42
profile.

## Deployment assumptions for privileged functions

The reference schemas harden the default configuration; they cannot control how an
operator deploys them. The following are assumptions, not guarantees:

- The installer and the schema owner are trusted.
- Untrusted roles are not granted `CREATE` in any schema referenced by a privileged
  function's `search_path`.
- Ownership of privileged functions is never granted to ordinary application roles.
- Deployment-specific grants are audited; the defaults in the schema file are a
  starting point, not a description of the running system.

## Detection coverage of the audit-gap view

qdh_audit_gap reports engines whose current lifecycle state is STATE_QUARANTINED
and for which no NODE_QUARANTINE_TRIGGERED event exists at the current
generation_epoch. An engine quarantined without evidence that has since advanced
to STATE_DE_VERIFYING or later is not reported. Deployments needing continuous
detection must alert when the row appears, or retain the gap record independently
of the engine state.
