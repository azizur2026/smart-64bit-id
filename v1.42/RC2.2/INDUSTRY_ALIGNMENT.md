# SMART 64-Bit ID v1.42 — Industry Alignment Note

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010
**Status note:** Non-normative comparison and scope note. This is not a certification or claim of
formal compliance with an external standard.

## 1. Design objective

SMART v1.42 separates a persistent identity core from an upper representation/control area. The
54-bit Identity Core is Class + Engine + Local and is the uniqueness coordinate. The routing selector
is Class + Engine, resolved through the Virtual Engine control table. In v1.42 the Class field
carries the encoded taxonomy value, and each Class has its own independent 21-bit Engine pool, so the
same Engine number in two Classes denotes two different Virtual Engines.

This is a particular architectural choice, not a universal replacement for other identifier designs.

## 2. Comparison dimensions

When comparing identifier systems, evaluate at least:

- whether generation requires synchronized wall-clock time;

- whether numeric order approximates creation time;

- how uniqueness is coordinated across allocation domains, and whether the coordinate includes the
  taxonomy or only a namespace and a counter;

- how an allocator recovers after crash, restore, failover, quarantine, or ownership transfer, and
  whether recovery preserves permanent non-reuse;

- whether the format exposes shard, class, or role metadata;

- how identifiers are stored and indexed in the target database;

- how profile/version evolution is handled, including whether an upgrade invalidates previously
  allocated identifiers;

- how the system retains retired identifiers and their permanently consumed coordinates; and

- whether the design supports the application's privacy and security requirements.

SMART v1.42 encodes no time and promises no chronological ordering. Its allocation-safety model
depends on authoritative per-Class engine pools, non-reusing Local allocation, durable evidence, and
epoch-fenced writes. Timestamp-based and random identifiers make different trade-offs; the right
choice depends on workload and system constraints.

## 3. No unsupported superiority claim

The specification does not establish that SMART is faster, more scalable, more secure, or more
storage-efficient than every alternative. Any such claim needs a defined workload, controlled
methodology, baseline, raw results, and reproducible conditions. Database measurements do not
automatically establish allocator or distributed-routing performance. The cost of coordinate
permanence and retired-record retention is real and should be included in any comparison.

## 4. Security alignment

An identifier format is distinct from authentication and authorization. Applications should not treat
possession of an identifier as proof of identity or permission. Cryptographic protections and key
management are outside the format.

In v1.42 the Class field directly exposes the entity category; applications with confidentiality
requirements should account for that in their security design. Addresses stored in the control table
are locators, not authenticators: host trust comes from hardware attestation and a signed,
epoch-bound lease.

## 5. Version boundaries

The v1.41 and v1.42 profiles are not interchangeable and coexist as the active profiles of the
Version 0 family. Revision `0000` (v1.4) is obsolete and unsupported.

Layout differences matter: v1.41 uses bits 50–53 as a zero Class marker with bits 54–57 Reserved;
v1.42 uses bits 50–53 as the encoded Class, also with bits 54–57 Reserved. The obsolete v1.4 layout
used bits 50–57 as an 8-bit Region field, which is why it cannot be reinterpreted as either active
profile.

A decoder must select the profile before interpreting these bits. Under normal validation a
cross-profile identifier is rejected at profile identification, and that is the decisive rejection.
Field-level incompatibilities are informative only.

## 6. Identifier-lifecycle alignment

SMART v1.42's retirement model is consistent with established identifier-lifecycle practice. GS1
requires that an allocated GTIN shall not be reallocated to another trade item; the earlier four-year
non-reuse period has been deprecated, with narrow exceptions for items never produced and withdrawn
items reintroduced unchanged. NIST SP 800-53 IA-4 requires organizations to prevent reuse of
identifiers for an organization-defined period. ISO 8000-115:2024 specifies identifier syntax and
resolution principles while leaving the methods of creation and resolution outside its scope.

SMART v1.42 follows the same direction: a retired coordinate is consumed permanently, with no release
point. QDH reclamation changes how a quarantined engine returns to service, not whether a consumed
coordinate can be reused: allocation resumes above the first never-consumed coordinate. See
`BIBLIOGRAPHY.md`.

## 7. Research boundary

Historical benchmark notes outside this package document their own test conditions and limitations.
They are not evidence of v1.42 performance unless a new study explicitly defines and tests the v1.42
profile.
