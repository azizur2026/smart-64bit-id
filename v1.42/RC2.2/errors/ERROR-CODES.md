# SMART 64-Bit ID v1.42 — Error Codes

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** `SPECIFICATION.md`
**Document purpose:** Authoritative registry of error identifiers for SMART 64-Bit ID v1.42

## 1. Purpose and status of this registry

This document is the authoritative registry of error identifiers for SMART 64-Bit ID v1.42.

`SPECIFICATION.md` cites a subset of these codes normatively, in its validation order and
non-conforming conditions. This registry is the authoritative source for the definition, category,
and trigger of every code, whether or not the specification cites it.

The registry defines **31 codes, `S64-E001` through `S64-E031`**.

**Compatibility with Release Candidate 1.** Identifiers allocated under RC1 remain valid and
require no migration or re-issue, and both candidates carry Revision `0010`. Two emission
behaviours differ, and RC1 implementations are not required to adopt them:

- profile provenance is `S64-E030` in this revision; RC1 reported that condition as `S64-E015`,
  which retains its original Class-binding meaning here;
- an inadmissible lifecycle transition is `S64-E031`; RC1 had no code for it.

A peer may therefore report a different code for the same condition while both claim `0010`. That
is a documented compatibility note, not a conformance failure of RC1.

`S64-E024` and `S64-E025` are renamed in this revision, from `RETIREMENT_REQUIRED` and
`RETIRED_IDENTIFIER_OPERATION` to `RETIRED_RECORD_MUTATION` and `RETIRED_RECORD_REACTIVATION`,
together with their triggers. The rename is permissible only because v1.42 RC2.2 is unpublished.
After publication, removing a code or redefining an established code's meaning requires a new
Revision; adding a code does not.

The registry does not prescribe logging format, transport of errors, retry policy, or user-facing
message text.

## 2. Code format

Each code has the form `S64-Exxx`, where `xxx` is a three-digit decimal number. The prefix `S64`
denotes the specification family; `E` denotes an error identifier.

A published code's meaning is stable. Codes MUST NOT be silently reused for unrelated conditions.

Codes are grouped by category. The category of a code is part of its definition and is used in the
validation precedence stated in `SPECIFICATION.md` §16.1 and §16.2.

## 3. Categories

| Category | Meaning |
|---|---|
| Input | The input representation or length is not acceptable. |
| Profile | The Version/Revision does not identify a supported profile. |
| Field | A field value is outside the permitted range for the identified profile. |
| Authoritative | The authoritative data associated with the identity is absent, ambiguous, conflicting, unreachable, or disagrees with the encoded identifier. |
| Routing | The identifier cannot be resolved to a physical node through the control table. |
| Admin | An administrative operation would violate a binding or invariant of the profile. |
| Allocation | An allocation operation would violate the coordinate, uniqueness, or non-reuse rules. |
| Retirement | A retirement-related operation or record condition is not acceptable. |
| Lifecycle | An operation on an existing identifier would violate a lifecycle invariant, such as Role immutability, profile provenance, or history-chain resolvability. |
| Conformance | An implementation-level condition indicates that the implementation cannot honor a profile requirement. |

## 4. Validation precedence

Where more than one condition applies, the precedence in `SPECIFICATION.md` §16.1 and §16.2 is
normative.

For authoritative checks, every query required to complete validation MUST complete before a
missing, mismatched, duplicate, or provenance result dependent on that query is reported. If a
required query cannot complete during ordinary operation, the result is `S64-E012`.

A power cut or hardware failure invokes `FAIL_HARD` and overrides ordinary error selection.
`FAIL_HARD` is an operational outcome, not an S64 code.

### 4.1 Identifier validation

1. Input format.
2. Profile identification.
3. Field validity.
4. Authoritative checks, including profile provenance.
5. Routing resolution.

### 4.2 Allocation and administrative operation validation

1. Authority, fencing, and epoch: `S64-E019`, `S64-E020`, `S64-E021`.
2. Coordinate and lifecycle: `S64-E023`, `S64-E031`, `S64-E016`, `S64-E018`.
3. Administrative invariants: `S64-E015`, `S64-E010`, `S64-E030`, `S64-E024`, `S64-E025`.
4. Rollover and exhaustion: `S64-E022`, `S64-E029`.
5. Failure policy: `FAIL_HARD`.

No ordering may permit a stale allocator or a prior-generation writer to commit.

### 4.3 Operation-specific categories

Allocation, retirement, lifecycle, and conformance categories apply where the operation is
invoked. An implementation MUST NOT proceed past a failure at an earlier stage, and MUST NOT report
a later-stage condition as though the earlier stages had succeeded.

### 4.4 Input-format precedence within stage 1

Formatting is validated before length. A disallowed character, prefix, whitespace, or separator is
`S64-E011`. A correctly formatted input of incorrect length is `S64-E001`. When both defects are
present, `S64-E011` is reported.

### 4.5 Allocation-stage precedence

**Power-cut and hardware-failure rule.** A detected power cut or hardware failure affecting
allocation state or integrity takes absolute precedence over ordinary allocation codes and
produces `FAIL_HARD`. The implementation MUST stop issuing identifiers, MUST NOT perform a last-ID
lookup, MUST NOT infer an allocation position, and MUST NOT automatically resume or retry. Under
v1.42, recovery is through the QDH lifecycle in `QDH-SPECIFICATION.md`; under pre-v1.42 rules no
recovery existed and the engine was retired permanently.

For ordinary allocation checks, in order:

1. `S64-E019 ALLOCATOR_AUTHORITY_LOST` — the allocator's authority has ended.
2. `S64-E020 CONCURRENT_ALLOCATOR` — more than one authoritative allocator could commit.
3. `S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` — uniqueness, non-reuse, exclusive authority, target
   reservation, host fitness, or an immutable binding cannot be established.
4. `S64-E023 COORDINATE_OUT_OF_RANGE` — Engine or Local outside the permitted range.
5. `S64-E031 LIFECYCLE_TRANSITION_INVALID` — the engine's state does not admit the operation.
6. `S64-E016 RETIRED_COORDINATE_REISSUE` — the requested coordinate is retired.
7. `S64-E018 LOCAL_REUSE_VIOLATION` — the coordinate was allocated and is not retired.
8. `S64-E022 ENGINE_EXHAUSTED` — the Local namespace is exhausted and a forward target has been
   found and safely reserved.
9. `S64-E029 ENGINE_ID_SPACE_EXHAUSTED` — an authoritative search establishes no eligible higher
   Engine remains.

`S64-E022` MUST NOT be reported unless a valid forward target has been reserved. `S64-E029` MUST
NOT be reported unless the authoritative search establishes exhaustion. If the search cannot
complete, report the applicable authority or safety failure instead. No wraparound to a lower
Engine number is permitted.

## 5. Registry

### 5.1 Input

| Code | Name | Trigger |
|---|---|---|
| S64-E001 | INVALID_LENGTH | A correctly formatted input is not exactly 16 hexadecimal characters. |
| S64-E011 | MALFORMED_INPUT | Input contains non-hex characters, prefixes, whitespace, separators, or other disallowed formatting. Reported before `S64-E001` when both apply. |

### 5.2 Profile

| Code | Name | Trigger |
|---|---|---|
| S64-E002 | UNSUPPORTED_PROFILE | Version/Revision does not identify a supported profile. Revision `0000` is obsolete and unsupported. |

### 5.3 Field

| Code | Name | Trigger |
|---|---|---|
| S64-E003 | RESERVED_BITS_NONZERO | Bits 54–57 are nonzero in a v1.42 identifier. |
| S64-E004 | CLASS_ZERO | Encoded Class (bits 50–53) is `0000`. |
| S64-E005 | CLASS_RESERVED | Encoded Class (bits 50–53) is in `1001`–`1111`. |

`S64-E010 ROLE_INVALID` is in Lifecycle (§5.10): its trigger is a prohibited operation, not a
field value.

### 5.4 Authoritative

| Code | Name | Trigger |
|---|---|---|
| S64-E006 | CLASS_RECORD_MISSING | The Class + Engine + Local coordinate exists in the allocation registry, but the authoritative Class-property record is absent. |
| S64-E007 | CLASS_MISMATCH | The encoded Class disagrees with the authoritative Class-property record. |
| S64-E008 | ALLOCATION_NOT_FOUND | The complete Identity Core is not present in the allocation registry. |
| S64-E009 | ALLOCATION_CONFLICT | Two or more canonical allocation records exist for the same Identity Core, regardless of lifecycle state. Duplicates MUST be rejected before any record is selected for Class comparison or routing. |
| S64-E012 | VALIDATION_UNAVAILABLE | Authoritative data required to complete validation cannot be reached, or a required query cannot complete. |
| S64-E030 | PROFILE_PROVENANCE_MISMATCH | The profile recorded for an identity disagrees with the profile recorded for the generation epoch in which that identity was allocated, or an attempt is made to change the profile recorded on an existing identity. |

`S64-E012` takes precedence over `S64-E006`, `S64-E007`, `S64-E008`, `S64-E009` and `S64-E030`
whenever the required query cannot complete and the condition therefore cannot be established.

For `S64-E009`, lifecycle state does not change the code. Retirement updates the existing canonical
record and MUST NOT create a second one. Append-only audit events are not canonical records. A
history-chain successor MUST use a different coordinate.

### 5.5 Routing

| Code | Name | Trigger |
|---|---|---|
| S64-E013 | VIRTUAL_ENGINE_NOT_FOUND | Class + Engine does not resolve to a row in the control table. |
| S64-E014 | PHYSICAL_ENGINE_UNREACHABLE | The network address of the node hosting the engine is unreachable. |

### 5.6 Admin

| Code | Name | Trigger |
|---|---|---|
| S64-E015 | ENGINE_CLASS_BINDING_VIOLATION | An operation would violate an Engine's binding to a single Class, including an administrative shift, reallocation, or migration that would associate an identity with an engine of a different Class. Does not describe profile provenance; that is `S64-E030`. |

### 5.7 Allocation

| Code | Name | Trigger |
|---|---|---|
| S64-E016 | RETIRED_COORDINATE_REISSUE | An attempt to allocate at a coordinate that has been retired. Takes precedence over `S64-E018`. |
| S64-E018 | LOCAL_REUSE_VIOLATION | An attempt to allocate a Local coordinate already allocated within that Virtual Engine, where the coordinate is not retired. |
| S64-E019 | ALLOCATOR_AUTHORITY_LOST | An allocator attempts to commit after its authority has ended. |
| S64-E020 | CONCURRENT_ALLOCATOR | More than one authoritative allocator could commit conflicting allocations in the same namespace, including adoption of a live engine as a rollover target. |
| S64-E021 | ALLOCATION_SAFETY_UNESTABLISHED | Safe uniqueness, non-reuse, exclusive authority, target reservation, host fitness, or an immutable binding cannot be established. |
| S64-E022 | ENGINE_EXHAUSTED | The Local namespace is exhausted and the lowest eligible higher Engine in the same Class pool has been found and safely reserved. Reports a completed rollover; not a failure. |
| S64-E023 | COORDINATE_OUT_OF_RANGE | Engine or Local value is outside the permitted range. |
| S64-E029 | ENGINE_ID_SPACE_EXHAUSTED | An authoritative search establishes that no eligible higher Engine remains in the Class pool. May occur before 2^21 - 1. No wraparound is permitted. |

For `S64-E022` and `S64-E029`, eligibility MUST be established from authoritative state. A
candidate is an engine in `STATE_UNALLOCATED`, or an existing engine whose prior allocator authority
has been conclusively invalidated. An engine under a live lease MUST NOT be adopted.

### 5.8 Retirement

| Code | Name | Trigger |
|---|---|---|
| S64-E017 | RETIRED_RECORD_MISSING | A retired identifier's record is absent, has not been retained as required, or a required coordinate-consumption tombstone is absent. |
| S64-E024 | RETIRED_RECORD_MUTATION | An attempt to modify a retired record's immutable fields: the Identity Core, the encoded Class, the recorded profile, the Role, or the recorded generation epoch. |
| S64-E025 | RETIRED_RECORD_REACTIVATION | An attempt to transition a retired record back to active, or to treat a retired Identity Core as free or allocatable. |

### 5.9 Conformance

| Code | Name | Trigger |
|---|---|---|
| S64-E026 | PROFILE_BOUNDARY_VIOLATION | An operation would apply one profile's rules to an identifier of another profile, or convert across profiles by rewriting, truncating, or masking bits. |
| S64-E027 | FIELD_EXTRACTION_INVALID | Field extraction produces a value inconsistent with the defined bit positions. |
| S64-E028 | SERIALIZATION_NONCANONICAL | Serialization or deserialization does not preserve all 64 bits in canonical unsigned big-endian form. |

### 5.10 Lifecycle

| Code | Name | Trigger |
|---|---|---|
| S64-E010 | ROLE_INVALID | A request to change the Role of an existing identifier, or any operation expressing a Role change without retirement and reallocation. Both Role values are valid during field validation. |
| S64-E031 | LIFECYCLE_TRANSITION_INVALID | A requested Virtual Engine lifecycle transition is not permitted by the state machine, or the engine's state does not admit the requested operation. |

## 6. Code-to-specification cross-reference

Informative.

| Code | Cited in SPECIFICATION.md | Status |
|---|---|---|
| S64-E001 | §16.1 step 1 | Cited |
| S64-E002 | §16.1 step 2 | Cited; `0000` obsolete |
| S64-E003 | §14, §16.1 step 3 | Cited |
| S64-E004 | §2.1, §16.1 step 3 | Cited |
| S64-E005 | §2.1, §16.1 step 3 | Cited |
| S64-E006 | §5.3, §16.1 step 4 | Cited |
| S64-E007 | §2.1, §5.1, §5.3, §8, §16.1 step 4 | Cited |
| S64-E008 | §5.3, §16.1 step 4 | Cited |
| S64-E009 | §5.3, §16.1 step 4 | Cited |
| S64-E010 | §4.1, §16.1 step 3, §16.2 step 3 | Cited |
| S64-E011 | §16.1 step 1 | Cited |
| S64-E012 | §16.1 step 4 | Cited |
| S64-E013 | §8, §16.1 step 5 | Cited |
| S64-E014 | §8, §16.1 step 5 | Cited |
| S64-E015 | §5.4, §6.3, §10.5, §16.2 step 3 | Cited |
| S64-E016 | §10.2, §16.2 step 2, §18, §19 | Cited |
| S64-E017 | §10.3, §18, §19 | Cited |
| S64-E018 | §7.2, §16.2 step 2, §18, §19 | Cited |
| S64-E019 | §7.4, §10.7.2, §16.2 step 1 | Cited |
| S64-E020 | §6.4, §7.4, §16.2 step 1 | Cited |
| S64-E021 | §7.1–§7.4, §16.2 step 1 | Cited |
| S64-E022 | §6.4, §16.2 step 4 | Cited |
| S64-E023 | §6.1, §6.2, §16.2 step 2 | Cited |
| S64-E024 | §10.3, §16.2 step 3, §17 | Cited |
| S64-E025 | §10.1, §10.2, §16.2 step 3 | Cited |
| S64-E026 | §13.4, §15 | Cited |
| S64-E027 | §16 | Cited |
| S64-E028 | §15 | Cited |
| S64-E029 | §6.5, §16.2 step 4 | Cited |
| S64-E030 | §13.1, §16.1 step 4, §16.2 step 3 | Cited |
| S64-E031 | §16.2 step 2 | Cited |

## 7. Notes on specific codes

### 7.1 S64-E010 ROLE_INVALID

Role is immutable for the allocated identifier. A change of designation is expressed by retirement
and reallocation. `S64-E010` is not a field-validation error; both Role values are valid.

### 7.2 S64-E016 and S64-E018 precedence

At a retired coordinate `S64-E016` applies, not `S64-E018`. Coordinate permanence governs retired
coordinates; Local non-reuse applies to allocated, non-retired coordinates.

### 7.3 S64-E017 RETIRED_RECORD_MISSING

Implements the retention rule in `SPECIFICATION.md` §10.3 and the per-profile rule in §10.4.
Applies when a retired record cannot be produced where the retaining profile requires it, or when a
required tombstone is absent. Does not apply to another profile's retired records.

### 7.4 S64-E022 and S64-E029

`S64-E022` concerns an exhausted Local namespace with a safely reserved forward target. `S64-E029`
concerns the Class pool as a whole. Neither may be reported without the evidence the specification
requires; if evidence is missing, report `S64-E012` or `S64-E021`. `S64-E022` is distinct from
`S64-E008`, which concerns a specific coordinate's presence in the registry.

### 7.5 S64-E024 RETIRED_RECORD_MUTATION

Applies to modification of a retired record's immutable fields. It is not a "retirement required"
code: `SPECIFICATION.md` §10.5 intentionally allocates the successor before retiring the source,
and that sequence does not violate this code.

### 7.6 S64-E025 RETIRED_RECORD_REACTIVATION

Applies when a retired record is reactivated, or a retired Identity Core is treated as free or
allocatable. The Identity Core has no release point.

### 7.7 S64-E026 PROFILE_BOUNDARY_VIOLATION

Covers §13.4 cases where an implementation would accept, reinterpret, convert, rewrite, truncate,
or mask a cross-profile identifier. Distinct from `S64-E002`, which applies when the profile is not
supported at all.

### 7.8 S64-E027 and S64-E028

Conformance-category codes reporting implementation defects rather than input defects.

### 7.9 S64-E030 PROFILE_PROVENANCE_MISMATCH

Compares an identity's recorded profile against the profile of the generation epoch in which it was
allocated, as recorded in the control-table lineage. The engine's current `active_profile` governs
new allocations only. A profile upgrade therefore does not invalidate previously allocated
identities, and no identity record may be rewritten to match a new profile.

### 7.10 S64-E031 LIFECYCLE_TRANSITION_INVALID

Reports a transition outside the eight-state machine, or an operation the engine's state does not
admit. Distinct from missing evidence, which is a QDH diagnostic (`QDH-E016`).

### 7.11 S64-E009 ALLOCATION_CONFLICT

Exactly one canonical allocation record MUST exist for each Identity Core ever allocated. More than
one is `S64-E009`, regardless of lifecycle state. Duplicates MUST be rejected before any record is
selected for Class comparison or routing; Class agreement MUST NOT be used to choose between
conflicting records.

## 8. Summary

31 codes across 10 categories: 2 input, 1 profile, 3 field, 6 authoritative, 2 routing, 1 admin,
8 allocation, 3 retirement, 3 conformance, 2 lifecycle.

Every code is cited by `SPECIFICATION.md` or by `QDH-SPECIFICATION.md`; none is registry-only.

## 9. SQL State mapping

### 9.1 Purpose

The S64 codes are the vendor-code layer. The SQL State column is a reporting mapping for RDBMS log
compatibility, following a dual-code pattern. Most conditions are raised before any SQL statement
executes; for in-database conditions the SQL State may be native. Where no class fits, HY000 is
used.

### 9.2 Mapping table

| S64 vendor code | SQL State | Trigger environment |
|---|---|---|
| S64-E001 INVALID_LENGTH | 22000 | Input: wrong length |
| S64-E011 MALFORMED_INPUT | 22000 | Input: non-hex or disallowed formatting |
| S64-E002 UNSUPPORTED_PROFILE | 0A000 | Profile selection |
| S64-E003 RESERVED_BITS_NONZERO | 22000 | Field: Reserved bits nonzero |
| S64-E004 CLASS_ZERO | 22000 | Field: encoded Class `0000` |
| S64-E005 CLASS_RESERVED | 22000 | Field: encoded Class `1001`–`1111` |
| S64-E006 CLASS_RECORD_MISSING | HY000 | Authoritative: Class record absent |
| S64-E007 CLASS_MISMATCH | HY000 | Authoritative: encoded Class disagrees |
| S64-E008 ALLOCATION_NOT_FOUND | HY000 | Authoritative: coordinate absent |
| S64-E009 ALLOCATION_CONFLICT | 23000 | Authoritative: duplicate canonical records |
| S64-E010 ROLE_INVALID | 44000 | Lifecycle: Role change in place |
| S64-E012 VALIDATION_UNAVAILABLE | 08000 | Authoritative: data or query unavailable |
| S64-E013 VIRTUAL_ENGINE_NOT_FOUND | 42S02 | Routing: Class + Engine not in control table |
| S64-E014 PHYSICAL_ENGINE_UNREACHABLE | 08000 | Routing: node address unreachable |
| S64-E015 ENGINE_CLASS_BINDING_VIOLATION | 44000 | Admin: shift, reallocation, migration across Classes |
| S64-E016 RETIRED_COORDINATE_REISSUE | 23000 | Allocation: retired coordinate |
| S64-E017 RETIRED_RECORD_MISSING | HY000 | Retirement: record or tombstone absent |
| S64-E018 LOCAL_REUSE_VIOLATION | 23000 | Allocation: Local reuse |
| S64-E019 ALLOCATOR_AUTHORITY_LOST | HY000 | Allocation: stale allocator |
| S64-E020 CONCURRENT_ALLOCATOR | HY000 | Allocation: concurrent authority |
| S64-E021 ALLOCATION_SAFETY_UNESTABLISHED | HY000 | Allocation: safety unestablished |
| S64-E022 ENGINE_EXHAUSTED | 2200H | Allocation: exhausted and reserved |
| S64-E023 COORDINATE_OUT_OF_RANGE | 22023 | Allocation: value out of range |
| S64-E024 RETIRED_RECORD_MUTATION | 44000 | Retirement: immutable field mutation |
| S64-E025 RETIRED_RECORD_REACTIVATION | 44000 | Retirement: reactivation attempt |
| S64-E026 PROFILE_BOUNDARY_VIOLATION | 0A000 | Conformance: cross-profile operation |
| S64-E027 FIELD_EXTRACTION_INVALID | HY000 | Conformance: extraction defect |
| S64-E028 SERIALIZATION_NONCANONICAL | HY000 | Conformance: serialization defect |
| S64-E029 ENGINE_ID_SPACE_EXHAUSTED | 2200H | Allocation: no eligible higher Engine |
| S64-E030 PROFILE_PROVENANCE_MISMATCH | HY000 | Authoritative: provenance disagrees |
| S64-E031 LIFECYCLE_TRANSITION_INVALID | 44000 | Lifecycle: transition not permitted |

### 9.3 Notes

The SQL State column is reporting metadata, not a replacement for the vendor code. An
implementation exposing SMART errors through SQL SHOULD report both. Severity is not defined by
this profile. Native vendor numbers MAY be exposed alongside the S64 code; the profile defines only
the S64 layer and this mapping.
