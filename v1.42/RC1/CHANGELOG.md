# SMART 64-Bit ID v1.42 — Changelog

## v1.42 — Release Candidate 1 — cross-check in progress

### Profile introduction

- Introduces v1.42 as a separate profile (Version 0, Revision 0010). Does not supersede, obsolete, or replace v1.4 or v1.41. The three profiles coexist.

- Replaces the v1.41 zero Class-marker with an encoded Class in bits 50–53. Assigned values 0001–1000; 0000 invalid; 1001–1111 reserved.

- Requires the encoded Class to agree with the authoritative Class-property record. Disagreement is a hard stop (S64-E007 CLASS_MISMATCH).

- Establishes that each Engine is bound to exactly one Class. Multiple Engines may share a Class; an Engine must not be bound to more than one Class. Reclassification of an existing Engine is not permitted; a Class change requires a new Engine.

- Introduces the virtual-engine ID as the 25-bit concatenation of Class and Engine. Routing uses Class + Engine → virtual engine → physical engine address, replacing v1.41's Engine-alone routing.

- States mutual invalidity between v1.41 and v1.42 explicitly, in both directions. Under normal validation, rejection occurs at profile identification; field-level incompatibilities are informative, not decisive.

- States Role as immutable for the allocated identifier but not for the entity. Role is consumed by the application domain layer, not by routing or allocation.

- States retirement as a record-level transition. State (active/retired) is not encoded in the 64-bit identifier in v1.41 or v1.42.

- Establishes that a retired Engine + Local coordinate is permanently consumed and is not reissued under any profile of the SMART 64-Bit ID family. There is no release point.

- Establishes a permanent coordinate-consumption tombstone, independent of the retention policy for the full retired record.

- Establishes that a retired identifier's record is retained indefinitely, for as long as the profile under which it was allocated remains in force. Retention obligations for other profiles' records arise from those profiles, not from v1.42.

- Establishes engine exhaustion and rollover: when an Engine's Local namespace is exhausted, the controller advances to the next Engine ID within the same Class, with the Class fixed across rollover. Existing identifiers remain valid and routable; they are not migrated.

- Establishes terminal Engine-ID exhaustion: when no further Engine ID is available within the Class, allocation fails (S64-E029 ENGINE_ID_SPACE_EXHAUSTED).

- Defers a 5-bit Class expansion that would reallocate bit 54 from Reserved to Class. Bit 54 remains Reserved in v1.42.

- Introduces the error-code registry as ERROR-CODES.md. The specification cites codes by name; the registry is authoritative for their definitions.

- Retains Engine + Local as the uniqueness coordinate. Class does not partition the allocation namespace.

### Audit corrections applied

The following corrections arose from the adversarial audit of the v1.42 release candidate. Each was reviewed and resolved before this revision.

- Allocation precedes retirement. The migration sequence now allocates the new identifier (inactive), creates its Class-record, links the history chain, and only then activates the new identifier and retires the source. If any step before activation fails, the source identifier remains active. This replaces the earlier sequence in which retirement preceded replacement allocation and could leave an entity with no identifier if allocation failed.

- Identifier history chain. Each identifier record now records the identifier it replaced, if any. At most one identifier in a chain is resolvable by ordinary lookups at any time. A chain in which a pending successor exists and no identifier is resolvable is non-conforming.

- Coordinate-consumption tombstone. A minimal permanent record of every consumed coordinate is now required, independent of the full retired record's retention. This closes the gap where the permanence rule could outlive the record needed to enforce it.

- "One-to-one" corrected. The Engine–Class relationship is now stated as "each Engine is bound to exactly one Class; multiple Engines may share a Class." The previous wording, "one-to-one," was mathematically incorrect: it implied a bijection, which rollover contradicts.

- Input-format precedence. Within stage 1, formatting is validated before length. A malformed input that is also the wrong length reports S64-E011, not S64-E001.

- S64-E010 moved to Lifecycle category. ROLE_INVALID is an operation-level error, not a field-validation error. Both Role values are valid in v1.42; the code applies to an attempt to change Role in place.

- Administrative validation separated. Administrative operations (E015) are validated by a separate procedure (SPECIFICATION.md §16.2), not as a stage of identifier validation (§16.1).

- S64-E015 trigger broadened. The registry trigger now covers administrative shifts, reallocations, and migrations that would associate an identifier with an Engine of a different Class.

- Duplicate-record precedence. Duplicate allocation records in the same State are a conflict (E009). Records in different workflow states are a normal history chain, not a conflict. Duplicates are rejected before any record is selected for Class comparison.

- S64-E021 renamed. ALLOCAL_SAFETY_UNESTABLISHED corrected to ALLOCATION_SAFETY_UNESTABLISHED.

- S64-E016 takes precedence over S64-E018. For an allocation attempt at a retired coordinate, the retired-coordinate rule governs. The test vector resolves to E016 only.

- Mutual-invalidity explanation corrected. §13.1 now distinguishes the decisive profile-selection rejection from the informative field-level explanation.

- Identifier-lifecycle alignment. The retirement model is now stated as consistent with GS1's permanent GTIN non-reuse rule and NIST SP 800-53 IA-4's non-reuse requirement. See BIBLIOGRAPHY.md.

- Decoder retention. An implementation that stores identifiers from more than one profile must retain the decoder for each profile it stores.

- B-Tree MSB trade-off acknowledged. LIMITATIONS.md §7 now states that spatial prefix routing scatters concurrent multi-class inserts at the index layer, as an inherent trade-off.

## v1.41 — Stable

- Declares the SMART 64-Bit ID v1.41 specification stable.

- Defines the normative 64-bit layout, validation rules, and version handling.

- Establishes Engine + Local as the authoritative uniqueness coordinate.

- Clarifies Class, Role, and Engine-based routing semantics.

- Keeps deferred governance and future-version topics separate from v1.41 requirements.

All notable changes to SMART 64-Bit ID are documented in this file.

The project uses technical specification versions to identify meaningful changes to the SMART ID model. Git commits provide the detailed history of individual repository changes.

## v1.4 — 2026-10-04

- Public release of the SMART 64-Bit ID technical specification.

- 64-bit identity layout with a 50-bit identity core.

- 29-bit Local ID field.

- 21-bit Engine field.

- 8-bit Region metadata field.

- 1-bit lifecycle State field.

- 4 Reserved bits.

- 1 Version bit.

- Fixed-position Engine and Local ID routing model.

- Engine ownership and authoritative allocator requirements.

- Local ID persistence, non-reuse, exhaustion, and crash-recovery rules.

- Lifecycle retirement semantics.

- Public-ID and format-preserving-encryption boundary guidance.

- Standards-agnostic cryptographic requirements.

- Single-engine empirical benchmark findings.

- Explicit documentation of the invalid multi-engine benchmark.

- Documentation of benchmark limitations and implementation boundaries.

- Dual-licensing documentation for AGPLv3 and commercial use.

- Contributor License Agreement framework.

This release establishes the v1.4 technical baseline.

Documentation corrections and non-technical clarifications may be made through normal Git commits without changing the technical specification version.

Changes to the SMART ID structure, identity semantics, allocation rules, routing semantics, lifecycle semantics, failure behavior, or other core technical requirements should receive a new technical specification version.
