# SMART 64-Bit ID v1.42 — Error Codes

**Status:** Release Candidate 1 — cross-check in progress  
**Specification family:** SMART 64-Bit ID  
**Profile:** Version 0, Revision 0010  
**Companion document:** SPECIFICATION.md  
**Document purpose:** Authoritative registry of error identifiers for SMART 64-Bit ID v1.42

## 1. Purpose and status of this registry

This document is the authoritative registry of error identifiers for SMART 64-Bit ID v1.42.

The specification `SPECIFICATION.md` cites a subset of these codes normatively, in its validation order and non-conforming conditions. This registry is the authoritative source for the definition, category, and trigger of every code, whether or not the specification cites it.

This document is a pre-release candidate. Before v1.42 is published, its error-code definitions MUST be finalized consistently with `SPECIFICATION.md`. A correction made before publication to resolve an ambiguity or defect in this release candidate does not, by itself, require a new Revision.

Before publication, proposed error-code definitions may be corrected or removed to resolve an ambiguity or defect in this release candidate without automatically requiring a new Revision. After publication, changes to established error codes MUST follow the published profile's versioning and compatibility rules. Removing a code or redefining an established code's meaning requires a new Revision. Adding a code or making an additive registry change that does not alter an established code's meaning does not by itself constitute a profile revision.

The specification cites the codes used normatively; this registry MAY contain additional codes for diagnostic conditions not normatively cited.

The registry does not prescribe logging format, transport of errors, retry policy, or user-facing message text. Those are matters for the systems that adopt the profile. The registry defines the code, its category, and the condition that triggers it.

## 2. Code format

Each code has the form `S64-Exxx`, where `xxx` is a three-digit decimal number. The prefix `S64` denotes the SMART 64-Bit ID specification family; the `E` denotes an error identifier; the number is assigned by this registry.

A published code's meaning is stable. Codes MUST NOT be silently reused for unrelated conditions.

Codes are grouped by category. The category of a code is part of its definition and is used in the validation precedence stated in `SPECIFICATION.md` §16.1 and §16.2.

## 3. Categories

| Category | Meaning |
|---|---|
| Input | The input representation or length is not acceptable. |
| Profile | The Version/Revision does not identify a supported profile. |
| Field | A field value is outside the permitted range for the identified profile. |
| Authoritative | The authoritative data associated with the identity is absent, ambiguous, conflicting, unreachable, or disagrees with the encoded identifier. |
| Routing | The identifier cannot be resolved to a physical engine through the virtual-engine table. |
| Admin | An administrative operation would violate a binding or invariant of the profile. |
| Allocation | An allocation operation would violate the coordinate, uniqueness, or non-reuse rules. |
| Retirement | A retirement-related operation or record condition is not acceptable. |
| Lifecycle | An operation on an existing identifier would violate a lifecycle invariant, such as Role immutability or history-chain resolvability. |
| Conformance | An implementation-level condition indicates that the implementation cannot honor a profile requirement. |

## 4. Validation precedence

Where more than one condition applies to a single input or operation, the precedence stated in `SPECIFICATION.md` §16.1 and §16.2 is normative.

For authoritative checks, every query required to complete validation MUST complete successfully before a missing record, mismatched record, duplicate record, or other result dependent on that query is reported. If a required authoritative query cannot complete during ordinary operation, the result MUST be `S64-E012 VALIDATION_UNAVAILABLE`, rather than a missing-record, mismatch, or duplicate-record code whose determination depends on the unavailable query.

A power cut or hardware failure affecting allocation state or integrity invokes `FAIL_HARD` and overrides ordinary error selection. `FAIL_HARD` is an operational outcome, not an S64 error code.

### 4.1 Identifier validation

The stages are applied in this order:

1. Input format.
2. Profile identification.
3. Field validity.
4. Authoritative checks.
5. Routing resolution.

### 4.2 Administrative operation validation

Administrative operations MUST validate the Engine-to-Class binding before committing a change.

1. Engine-to-Class binding check.
2. Commit.

An operation MUST NOT commit if the binding check fails.

### 4.3 Operation-specific categories

Allocation, retirement, lifecycle, and conformance categories apply where their operation is invoked, in the procedure in which the operation is validated. They are not part of the identifier-validation precedence above.

An implementation MUST NOT proceed past a failure at an earlier stage, and MUST NOT report a later-stage condition as though the earlier stages had succeeded.

### 4.4 Input-format precedence within stage 1

Within stage 1, formatting is validated before length:

- A disallowed character, prefix, whitespace, or separator is `S64-E011 MALFORMED_INPUT`.
- A correctly formatted input of incorrect length is `S64-E001 INVALID_LENGTH`.

If an input has both defects, the formatting error is reported first. For example, `xyz` is malformed input; it is not reported as an invalid-length-only condition.

### 4.5 Allocation-stage precedence

**Power-cut and hardware-failure rule:** A detected power cut or hardware failure affecting allocation state or integrity takes absolute precedence over all ordinary allocation codes and produces the operational outcome `FAIL_HARD`. The implementation MUST stop issuing identifiers, MUST NOT perform a last-ID lookup, MUST NOT infer an allocation position, and MUST NOT automatically resume or retry. `FAIL_HARD` is not an S64 code.

For ordinary allocation checks, the following precedence applies, subject to the requirement that any authoritative query needed to establish a condition must complete successfully:

1. `S64-E016 RETIRED_COORDINATE_REISSUE` — the requested coordinate is retired.
2. `S64-E018 LOCAL_REUSE_VIOLATION` — the requested coordinate has already been allocated and is not retired.
3. `S64-E023 COORDINATE_OUT_OF_RANGE` — a requested Engine or Local value is outside the permitted range.
4. `S64-E019 ALLOCATOR_AUTHORITY_LOST` — the allocator's authority has ended.
5. `S64-E020 CONCURRENT_ALLOCATOR` — conflicting authoritative allocators exist or could both commit.
6. `S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` — uniqueness, non-reuse, exclusive authority, target reservation, or immutable Engine binding cannot be established safely.
7. `S64-E022 ENGINE_EXHAUSTED` — the Local namespace is exhausted, and the lowest eligible Engine ID numerically greater than the exhausted Engine has been found and safely reserved for rollover.
8. `S64-E029 ENGINE_ID_SPACE_EXHAUSTED` — an authoritative search establishes that no eligible Engine ID numerically greater than the exhausted Engine remains.

`S64-E022` MUST NOT be reported unless a valid forward rollover target has been found and safely reserved. `S64-E029` MUST NOT be reported unless the authoritative search establishes that no eligible forward target remains. This condition can occur before the maximum numeric Engine ID.

If the authoritative search cannot complete, or target reservation or allocation safety cannot be established, the implementation MUST report the applicable authority or safety failure instead of `S64-E022` or `S64-E029`. The implementation MUST NOT wrap around to a lower Engine ID.

## 5. Registry

### 5.1 Input

| Code | Name | Trigger |
|---|---|---|
| S64-E001 | INVALID_LENGTH | A correctly formatted input is not exactly 16 hexadecimal characters. |
| S64-E011 | MALFORMED_INPUT | Input contains non-hex characters, prefixes, whitespace, separators, or other disallowed formatting. Reported before S64-E001 when both apply. |

### 5.2 Profile

| Code | Name | Trigger |
|---|---|---|
| S64-E002 | UNSUPPORTED_PROFILE | Version/Revision does not identify a supported profile. |

### 5.3 Field

| Code | Name | Trigger |
|---|---|---|
| S64-E003 | RESERVED_BITS_NONZERO | Bits 54–57 are nonzero in a v1.42 identifier. |
| S64-E004 | CLASS_ZERO | Encoded Class (bits 50–53) is 0000. |
| S64-E005 | CLASS_RESERVED | Encoded Class (bits 50–53) is in 1001–1111. |

Note: `S64-E010 ROLE_INVALID` is in Lifecycle (§5.10), because its trigger is a prohibited operation, not a field value.

### 5.4 Authoritative

| Code | Name | Trigger |
|---|---|---|
| S64-E006 | CLASS_RECORD_MISSING | The Engine + Local coordinate exists in the allocation registry, but the authoritative Class-property record is absent. |
| S64-E007 | CLASS_MISMATCH | The encoded Class disagrees with the authoritative Class-property record. |
| S64-E008 | ALLOCATION_NOT_FOUND | The Engine + Local coordinate is not present in the allocation registry. |
| S64-E009 | ALLOCATION_CONFLICT | Two or more canonical allocation records exist for the same Engine + Local coordinate, regardless of their lifecycle State. Duplicates MUST be rejected before any record is selected for Class comparison or routing. |
| S64-E012 | VALIDATION_UNAVAILABLE | The authoritative data required to complete validation cannot be reached, or a required authoritative query cannot complete. |

For `S64-E009`, the lifecycle State of the duplicate records does not change the error code. Duplicate canonical allocation records are invalid whether their States match or differ. Retirement updates the existing canonical allocation record; it MUST NOT create a second canonical record. Append-only audit events are stored separately and MUST NOT be treated as canonical allocation records. A history-chain successor MUST use a different coordinate.

`S64-E012` takes precedence over `S64-E006`, `S64-E007`, `S64-E008`, and `S64-E009` whenever the required authoritative query cannot complete and the relevant missing, mismatch, or duplicate condition therefore cannot be reliably established.

### 5.5 Routing

| Code | Name | Trigger |
|---|---|---|
| S64-E013 | VIRTUAL_ENGINE_NOT_FOUND | Class + Engine does not resolve to a row in the virtual-engine table. |
| S64-E014 | PHYSICAL_ENGINE_UNREACHABLE | The physical engine address resolved for the virtual engine is unreachable. |

### 5.6 Admin

| Code | Name | Trigger |
|---|---|---|
| S64-E015 | ENGINE_CLASS_BINDING_VIOLATION | An operation would violate the binding of an Engine to a single Class. This includes an administrative shift that would move an Engine to a different Class, a reallocation into an Engine of a different Class, and a migration into an Engine of a different Class. |

### 5.7 Allocation

| Code | Name | Trigger |
|---|---|---|
| S64-E016 | RETIRED_COORDINATE_REISSUE | An attempt to allocate an identifier at an Engine + Local coordinate that has been retired. Takes precedence over S64-E018. |
| S64-E018 | LOCAL_REUSE_VIOLATION | An attempt to allocate a Local ID within an Engine that has already been successfully allocated within that Engine, where the coordinate is not retired. |
| S64-E019 | ALLOCATOR_AUTHORITY_LOST | An allocator attempts to commit a new allocation after its authority has ended. |
| S64-E020 | CONCURRENT_ALLOCATOR | More than one authoritative active allocator would be able to commit conflicting allocations within the same Engine namespace. |
| S64-E021 | ALLOCATION_SAFETY_UNESTABLISHED | The implementation cannot establish safe uniqueness, non-reuse, exclusive authority, target reservation, or immutable Engine-Class binding, and allocation therefore fails. |
| S64-E022 | ENGINE_EXHAUSTED | The Local namespace is exhausted, and the lowest eligible Engine ID numerically greater than the exhausted Engine has been found and safely reserved for rollover within the same Class. No wraparound is permitted. |
| S64-E023 | COORDINATE_OUT_OF_RANGE | Engine or Local value is outside the permitted range. |
| S64-E029 | ENGINE_ID_SPACE_EXHAUSTED | An authoritative search establishes that no eligible Engine ID numerically greater than the exhausted Engine remains. This may occur before 2²¹ − 1. Allocation MUST fail; no wraparound is permitted. If the search or reservation safety is unavailable, report the applicable authority or safety failure instead. |

For `S64-E022` and `S64-E029`, eligibility MUST be established using authoritative state. An eligible target must be in range, must not be bound to another Class, and must be capable of supporting a safe allocation. An unbound Engine ID MAY be selected only if its binding to the requesting Class is established atomically before allocation and is immutable thereafter. An Engine ID bound to another Class MUST be skipped and MUST NOT be reclassified or reassigned. An Engine ID bound to the same Class whose Local namespace is exhausted MUST be skipped.

The target Engine ID and allocation coordinate MUST be safely reserved or claimed before the allocation is committed. Concurrent allocators MUST NOT be able to claim the same unbound Engine for different Classes or commit duplicate coordinates.

If no eligible higher Engine ID remains, the allocator MUST fail with `S64-E029`. It MUST NOT wrap around to a lower Engine ID, reuse a consumed coordinate, reclassify an Engine, or bypass allocation-safety requirements. Expansion of the Engine ID space requires a new profile or a separately defined Class assignment; existing identifiers MUST NOT be renumbered.

### 5.8 Retirement

| Code | Name | Trigger |
|---|---|---|
| S64-E017 | RETIRED_RECORD_MISSING | A retired identifier's record is absent, has not been retained as required, or a required coordinate-consumption tombstone is absent. |
| S64-E024 | RETIREMENT_REQUIRED | A specific operation step that explicitly requires prior retirement is attempted while the identifier's record is still active. |
| S64-E025 | RETIRED_IDENTIFIER_OPERATION | An operation that is not permitted on a retired identifier is attempted on one whose record is retired. |

`S64-E024` MUST NOT be reported merely because a successor is being allocated before source retirement. If the migration procedure specifies successor allocation followed by an atomic activation/retirement transition, allocating the successor first is not itself a retirement-required violation. `S64-E024` applies only when the particular step being attempted explicitly requires the source to have already been retired.

### 5.9 Conformance

| Code | Name | Trigger |
|---|---|---|
| S64-E026 | PROFILE_BOUNDARY_VIOLATION | An operation would apply one profile's rules to an identifier belonging to another profile, or would convert an identifier across profiles by rewriting, truncating, or masking bits. |
| S64-E027 | FIELD_EXTRACTION_INVALID | Field extraction produces a value inconsistent with the bit positions defined for the identified profile, indicating an implementation error. |
| S64-E028 | SERIALIZATION_NONCANONICAL | Binary serialization or deserialization does not preserve all 64 bits in canonical unsigned 64-bit big-endian form where canonical interoperability is required. |

### 5.10 Lifecycle

| Code | Name | Trigger |
|---|---|---|
| S64-E010 | ROLE_INVALID | A request to change the Role value of an existing allocated identifier, or any operation that would express a Role change without retirement and reallocation. Either Role bit value is valid during ordinary field validation; this code is triggered by the operation, not by the field value. |

## 6. Code-to-specification cross-reference

Informative. This table maps codes to the sections of `SPECIFICATION.md` where they are normatively cited, and marks which codes are additions not cited by the specification.

| Code | Cited in SPECIFICATION.md | Status |
|---|---|---|
| S64-E001 | §16.1 step 1 | Cited |
| S64-E002 | §16.1 step 2 | Cited |
| S64-E003 | §14, §16.1 step 3 | Cited |
| S64-E004 | §2.2, §16.1 step 3 | Cited |
| S64-E005 | §2.2, §16.1 step 3 | Cited |
| S64-E006 | §5.3, §16.1 step 4 | Cited |
| S64-E007 | §2.2, §5.1, §5.3, §8, §16.1 step 4 | Cited |
| S64-E008 | §5.3, §16.1 step 4 | Cited |
| S64-E009 | §5.3, §16.1 step 4 | Cited; applies to duplicates regardless of lifecycle State |
| S64-E010 | §4.1, §16.1 step 3 | Cited; lifecycle code |
| S64-E011 | §16.1 step 1 | Cited |
| S64-E012 | §16.1 step 4 | Cited |
| S64-E013 | §8, §16.1 step 5 | Cited |
| S64-E014 | §8, §16.1 step 5 | Cited |
| S64-E015 | §4.1, §5.4, §6.3, §10.5, §16.2 | Cited; trigger includes cross-Class shifts, reallocations, and migrations |
| S64-E016 | §10.2, §18, §19 | Cited |
| S64-E017 | §10.3, §18, §19 | Cited; includes required coordinate-consumption tombstones |
| S64-E018 | §7, §18, §19 | Cited |
| S64-E019 | §7, §18, §19 | Registry-only |
| S64-E020 | §7, §18 | Registry-only |
| S64-E021 | §7, §18 | Cited; safety failure code, subject to FAIL_HARD |
| S64-E022 | §6.4 | Cited |
| S64-E023 | §6.1, §6.2 | Registry-only |
| S64-E024 | §10.5 | Registry-only |
| S64-E025 | §10, §17 | Registry-only |
| S64-E026 | §13 | Registry-only |
| S64-E027 | §16 | Registry-only |
| S64-E028 | §15 | Registry-only |
| S64-E029 | §6.5 | Cited |

## 7. Notes on specific codes

### 7.1 S64-E010 ROLE_INVALID

Role is immutable for the allocated identifier. A change of designation is expressed by retirement and reallocation, not by rewriting the Role bit. `S64-E010` triggers on an attempt to change Role in place, or on any operation that would express a Role change without retirement and reallocation (see `SPECIFICATION.md` §4.1).

`S64-E010` is not a field-validation error. Both Role values are valid in v1.42. The code is triggered by the prohibited operation, not by the presence of Role 0 or Role 1 in an identifier.

### 7.2 S64-E016 RETIRED_COORDINATE_REISSUE

A retired Engine + Local coordinate is permanently consumed and MUST NOT be reissued under any profile of the SMART 64-Bit ID family. The code applies whether the attempted reissue would yield an identifier identical to the retired one or a different 64-bit value at the same coordinate.

`S64-E016` takes precedence over `S64-E018` when an allocation is attempted at a retired coordinate (see §4.5).

### 7.3 S64-E017 RETIRED_RECORD_MISSING

This code implements the retention rule in `SPECIFICATION.md` §10.3 and the per-profile retention rule in §10.4. It applies when a retired record cannot be produced where the retaining profile requires it, or when a required coordinate-consumption tombstone is absent. It does not apply to the treatment of another profile's retired records, which is not an obligation of v1.42.

### 7.4 S64-E016 and S64-E018 precedence

When an allocation is attempted at a coordinate that has been retired, `S64-E016` applies, not `S64-E018`. The coordinate-permanence rule governs retired coordinates; the Local non-reuse rule applies to coordinates that have been allocated and are not retired. This precedence is stated normatively in §4.5.

### 7.5 S64-E018–S64-E023 (allocation)

These codes make explicit the allocation invariants stated normatively in `SPECIFICATION.md` §7 and §6. `S64-E019` and `S64-E020` are registry-only in the sense that the specification states the invariants but does not cite these codes. `S64-E021` is the diagnostic code when allocation safety cannot be established and no more specific condition applies, except where `FAIL_HARD` is required. An implementation MAY use these codes to report the corresponding condition and SHOULD do so where the condition is diagnosable.

`S64-E022 ENGINE_EXHAUSTED` is distinct from `S64-E008 ALLOCATION_NOT_FOUND`. `S64-E022` concerns the allocator's exhausted Local namespace and a safely reserved forward rollover target. `S64-E008` concerns the authoritative registry relative to a specific coordinate.

`S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` matches the invariant in `SPECIFICATION.md` §7: if an implementation cannot establish safe uniqueness and non-reuse, allocation MUST fail.

### 7.6 S64-E024 RETIREMENT_REQUIRED and S64-E025 RETIRED_IDENTIFIER_OPERATION

`S64-E024` applies only when a specific operation step requires the source identifier to have already been retired and the source remains active. It MUST NOT be applied merely because a successor is being allocated before retirement: `SPECIFICATION.md` §10.5 intentionally allocates the successor first and then performs an atomic activation/retirement transition.

`S64-E025` applies when an operation not permitted on a retired identifier is attempted on one whose record is retired.

### 7.7 S64-E026 PROFILE_BOUNDARY_VIOLATION

This code covers the cases in `SPECIFICATION.md` §13.4 where an implementation would accept, reinterpret, convert, rewrite, truncate, or mask an identifier belonging to another profile. It is distinct from `S64-E002 UNSUPPORTED_PROFILE`, which applies when the profile itself is not supported; `S64-E026` applies when the operation would cross a profile boundary.

### 7.8 S64-E027 FIELD_EXTRACTION_INVALID and S64-E028 SERIALIZATION_NONCANONICAL

These are conformance-category codes, used to report implementation defects rather than input defects. `FIELD_EXTRACTION_INVALID` applies when extraction is inconsistent with the bit positions defined for the identified profile. `SERIALIZATION_NONCANONICAL` applies when binary serialization or deserialization does not preserve all 64 bits in canonical form where canonical interoperability is required.

### 7.9 S64-E029 ENGINE_ID_SPACE_EXHAUSTED

This code applies only after an authoritative search establishes that no eligible Engine ID numerically greater than the exhausted Engine remains. It may occur before Engine ID 2²¹ − 1 when all remaining higher IDs are bound to another Class, have exhausted Local namespaces, or are otherwise ineligible.

`S64-E029` is terminal for the current allocation attempt and MUST NOT wrap around to lower Engine IDs. It is distinct from `S64-E022 ENGINE_EXHAUSTED`, which applies only when a safe forward target has been found and reserved. If authoritative state or reservation safety cannot be established, report the applicable authority or safety failure instead. Expansion of the Engine ID space requires a new profile or a separately defined Class assignment; existing identifiers are not renumbered.

### 7.10 S64-E009 ALLOCATION_CONFLICT

Exactly one canonical allocation record MUST exist for each Engine + Local coordinate ever allocated. More than one canonical allocation record for the same coordinate is `S64-E009 ALLOCATION_CONFLICT`, regardless of whether the duplicate records have the same or different lifecycle States.

Retirement updates the existing canonical allocation record. Append-only audit events are stored separately and MUST NOT be treated as additional canonical allocation records. History-chain links connect distinct coordinates. Duplicate canonical records MUST be rejected before any record is selected for Class comparison or routing. Class agreement MUST NOT be used to choose between conflicting records.

## 8. Summary

The registry defines 29 error codes across 10 categories: 2 input, 1 profile, 3 field, 5 authoritative, 2 routing, 1 admin, 8 allocation, 3 retirement, 3 conformance, and 1 lifecycle.

The codes cited normatively by `SPECIFICATION.md` are E001–E018, E021, E022, and E029. The codes registry-only at present are E019, E020, E023, E024, E025, E026, E027, and E028.

This file is an unpublished release candidate. Its definitions MUST be finalized before publication. After publication, removal of a code or redefinition of an existing code's meaning requires a new Revision.

## 9. SQL State mapping

### 9.1 Purpose

The S64-Exxx codes are the vendor-code layer for this profile. They are paired with a SQL State for RDBMS log compatibility, following a dual-code pattern such as those used by Apache ShardingSphere and Oracle.

The SQL State column is a reporting mapping. Most S64-Exxx conditions are raised before any SQL statement executes — during allocation, validation at the edge, or routing. The SQL State states what an implementation SHOULD report if it surfaces the condition through a SQL interface, so that RDBMS logs and client tooling can classify the error. For conditions that originate in the database, such as authoritative-stage and lifecycle codes, the SQL State may be native.

Where no SQL State class fits, HY000 (general error) is used.

### 9.2 Mapping table

| S64 Vendor Code | SQL State | Trigger Environment | SQL State Basis |
|---|---|---|---|
| S64-E001 INVALID_LENGTH | 22000 | Input format: wrong length | PostgreSQL Class 22 (data exception) |
| S64-E011 MALFORMED_INPUT | 22000 | Input format: non-hex or disallowed formatting | PostgreSQL Class 22 |
| S64-E002 UNSUPPORTED_PROFILE | 0A000 | Profile selection: Version/Revision not supported | PostgreSQL 0A000; Oracle 0A000 |
| S64-E003 RESERVED_BITS_NONZERO | 22000 | Field validation: Reserved bits nonzero | PostgreSQL Class 22 |
| S64-E004 CLASS_ZERO | 22000 | Field validation: encoded Class 0000 | PostgreSQL Class 22 |
| S64-E005 CLASS_RESERVED | 22000 | Field validation: encoded Class 1001–1111 | PostgreSQL Class 22 |
| S64-E006 CLASS_RECORD_MISSING | HY000 | Authoritative lookup: Class record absent | General error for missing authoritative metadata |
| S64-E007 CLASS_MISMATCH | HY000 | Authoritative lookup: encoded Class differs from record | General error for authoritative metadata mismatch |
| S64-E008 ALLOCATION_NOT_FOUND | HY000 | Authoritative lookup: coordinate absent | General error for missing allocation record |
| S64-E009 ALLOCATION_CONFLICT | 23000 | Authoritative lookup: duplicate canonical records for one coordinate, regardless of lifecycle State | PostgreSQL Class 23 (integrity constraint violation) |
| S64-E010 ROLE_INVALID | 44000 | Lifecycle: attempt to change Role in place | Oracle 44000; rule-violation reporting |
| S64-E012 VALIDATION_UNAVAILABLE | 08000 | Authoritative lookup: required data or query unavailable | PostgreSQL Class 08; Oracle 08000 |
| S64-E013 VIRTUAL_ENGINE_NOT_FOUND | 42S02 | Routing: Class + Engine not in virtual-engine table | Missing table/object reporting |
| S64-E014 PHYSICAL_ENGINE_UNREACHABLE | 08000 | Routing: physical engine unreachable | PostgreSQL Class 08; connection failure |
| S64-E015 ENGINE_CLASS_BINDING_VIOLATION | 44000 | Administrative: shift/reallocation/migration to different Class | Rule-violation reporting |
| S64-E016 RETIRED_COORDINATE_REISSUE | 23000 | Allocation: retired coordinate reissue | PostgreSQL Class 23 |
| S64-E017 RETIRED_RECORD_MISSING | HY000 | Retirement: retired record or tombstone absent | General error for missing required record |
| S64-E018 LOCAL_REUSE_VIOLATION | 23000 | Allocation: Local reuse for a non-retired coordinate | PostgreSQL Class 23 |
| S64-E019 ALLOCATOR_AUTHORITY_LOST | HY000 | Allocation: stale allocator commit | General error for allocator-state violation |
| S64-E020 CONCURRENT_ALLOCATOR | HY000 | Allocation: concurrent authoritative allocator | General error for concurrent allocation authority |
| S64-E021 ALLOCATION_SAFETY_UNESTABLISHED | HY000 | Allocation: safety cannot be established | General error for an unestablished invariant |
| S64-E022 ENGINE_EXHAUSTED | 2200H | Allocation: Local namespace exhausted and safe forward rollover target reserved | PostgreSQL 2200H (sequence generator limit exceeded) |
| S64-E023 COORDINATE_OUT_OF_RANGE | 22023 | Allocation: Engine or Local outside range | Invalid parameter value |
| S64-E024 RETIREMENT_REQUIRED | 44000 | Retirement: operation explicitly requires prior retirement | Rule-violation reporting |
| S64-E025 RETIRED_IDENTIFIER_OPERATION | 44000 | Retirement: operation not permitted on retired identifier | Rule-violation reporting |
| S64-E026 PROFILE_BOUNDARY_VIOLATION | 0A000 | Conformance: cross-profile operation | PostgreSQL 0A000; Oracle 0A000 |
| S64-E027 FIELD_EXTRACTION_INVALID | HY000 | Conformance: extraction inconsistent with bit positions | General error for implementation defect |
| S64-E028 SERIALIZATION_NONCANONICAL | HY000 | Conformance: non-canonical serialization | General error for implementation defect |
| S64-E029 ENGINE_ID_SPACE_EXHAUSTED | 2200H | Allocation: no eligible higher Engine ID remains | PostgreSQL 2200H (sequence generator limit exceeded) |

### 9.3 Notes on the table

**SQL State column.** The SQL State column is a reporting mapping, not a replacement for the S64 vendor code. Implementations SHOULD verify mappings against the SQL interface and database products they actually support.

**Reporting mapping.** For pre-SQL conditions — input validation, allocation, and routing — the SQL State is a reporting mapping, not necessarily a native database code. For in-database conditions, it may be native. An implementation that exposes SMART errors through a SQL interface SHOULD report the S64-Exxx code and SQL State together.

**Fallback.** If the implementation's SQL State layer cannot represent a condition, it SHOULD use HY000 (general error).

**Severity.** SQL Server reports a severity dimension alongside its native error number. This profile does not define a severity dimension. An implementation that reports severity SHOULD define it in its own terms.

**Native vendor numbers.** An implementation MAY also expose a native error number alongside the S64-Exxx code, following a multi-code reporting pattern. The profile does not define native numbers; it defines only the S64-Exxx layer and its SQL State mapping.

### 9.4 Summary of the dual-code pattern

The profile uses a dual-code pattern:

- **Vendor Code:** S64-Exxx, defined by this registry.
- **SQL State:** standard five-character class code, mapped per §9.2.

An implementation that reports only the SQL State loses the diagnostic precision of the vendor code. An implementation that reports only the vendor code loses interoperability with RDBMS logging and tooling. Where supported, both SHOULD be reported together.
