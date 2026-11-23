# SMART 64-Bit ID v1.42 — Release Checklist

**Profile:** Version 0, Revision 0010  
**Release status:** Release Candidate 1 — cross-check in progress  
**Normative authority:** `SPECIFICATION.md`  
**Purpose:** Final documentation, conformance, and release-readiness checks

## 1. Specification and document consistency

- [ ] `SPECIFICATION.md` is treated as the normative source for v1.42 behavior.
- [ ] `errors/ERROR-CODES.md` defines the error codes cited by the specification without changing their normative triggers or precedence.
- [ ] `examples/test-vectors.md` agrees with the specification and error-code registry on expected results.
- [ ] `RULES.md`, `README.md`, and supporting documents are consistent with the normative specification.
- [ ] No checklist, example, or supporting document silently introduces a new normative requirement.
- [ ] Any unresolved contradiction between normative documents is documented and resolved before release.
- [ ] The release status is not described as final while the cross-check remains incomplete.

## 2. Identifier format and profile boundaries

- [ ] The identifier is exactly 64 bits.
- [ ] The field widths and bit positions match `SPECIFICATION.md`.
- [ ] Version and Revision identify the profile before profile-dependent fields are interpreted.
- [ ] v1.42 uses Version `0` and Revision `0010`.
- [ ] Reserved bits 54–57 must be zero.
- [ ] Encoded Class `0000` is rejected.
- [ ] Encoded Class values `1001`–`1111` are rejected as reserved.
- [ ] Both Role values are valid; Role is immutable for an allocated identifier.
- [ ] Canonical binary serialization preserves all 64 bits and uses the specified byte order.
- [ ] v1.4, v1.41, and v1.42 remain distinct profiles; no implementation silently rewrites, truncates, masks, or reinterprets one profile as another.

## 3. Class binding, allocation identity, and routing

- [ ] The allocation uniqueness coordinate is Engine ID + Local ID; Class does not partition that coordinate.
- [ ] Each Engine is bound to exactly one Class.
- [ ] An existing Engine is never reclassified or reassigned to another Class.
- [ ] The encoded Class agrees with the authoritative Class-property record.
- [ ] The authoritative Class-property record is associated unambiguously with the Engine + Local coordinate.
- [ ] Routing uses Class + Engine through the virtual-engine mapping defined by the specification.
- [ ] Administrative changes do not move an Engine to a different Class.
- [ ] An allocation or migration into an Engine bound to a different Class is rejected.

## 4. Allocation uniqueness and non-reuse

- [ ] A Local ID that has been successfully allocated within an Engine is never successfully allocated again within that Engine.
- [ ] A retired Engine + Local coordinate remains permanently consumed.
- [ ] Required coordinate-consumption tombstones and retired records are retained according to the specification.
- [ ] Allocation fails closed if safe uniqueness or non-reuse cannot be established.
- [ ] Concurrent allocators cannot successfully allocate duplicate coordinates or create conflicting allocation authority.
- [ ] A stale allocator cannot commit a new allocation after its authority has ended.
- [ ] Reservation and commit behavior prevents two allocators from claiming the same unbound Engine for different Classes.
- [ ] An unbound Engine is bound to the intended Class atomically before allocation, and that binding remains immutable.
- [ ] Existing identifiers are not renumbered to resolve an allocation conflict or exhaustion condition.

## 5. E009 and identifier history

- [ ] `S64-E009 ALLOCATION_CONFLICT` is defined consistently with the normative specification.
- [ ] Test vectors verify that duplicate canonical records are classified as E009 regardless of lifecycle State.
- [ ] Duplicate canonical allocation records at the same Engine + Local coordinate MUST be rejected as S64-E009 ALLOCATION_CONFLICT regardless of lifecycle State, including active/retired or other mixed-State pairs. History-chain successors MUST use different coordinates.
- [ ] Duplicate records are rejected before selecting a record for Class comparison or routing, where the specification requires this.
- [ ] The identifier history chain records the replaced identifier or an explicit first-allocation marker.
- [ ] At most one identifier in a history chain is resolvable by ordinary lookups at any time.
- [ ] Test vectors distinguish duplicate canonical records (E009 regardless of State) from valid history-chain successors that use different coordinates.
- [ ] E030 is not defined as an error code in v1.42. Duplicate canonical allocation records MUST use S64-E009 regardless of lifecycle State.

## 6. Engine exhaustion and rollover

- [ ] Local namespace exhaustion triggers the specified rollover process; a consumed Local ID is never reused.
- [ ] Rollover searches for the lowest eligible Engine ID numerically greater than the exhausted Engine ID, within the permitted Engine ID range.
- [ ] Engine IDs are never wrapped around to lower values.
- [ ] Engines bound to another Class are skipped and never reclassified or reassigned.
- [ ] Engines already bound to the same Class but with no remaining allocatable Local IDs are skipped.
- [ ] An unbound Engine is eligible only if its Class binding can be established safely and atomically before allocation.
- [ ] The target Engine is safely reserved or claimed before allocation commits.
- [ ] Concurrent allocators cannot claim the same target Engine incompatibly or allocate duplicate coordinates.
- [ ] `S64-E022 ENGINE_EXHAUSTED` is used only when Local exhaustion requires rollover and a valid forward target has been found and safely reserved, as required by the governing specification and error registry.
- [ ] `S64-E029 ENGINE_ID_SPACE_EXHAUSTED` is used when no eligible higher Engine ID remains under the governing specification and the authoritative state establishes that condition.
- [ ] E029 is not reported merely because the current Engine is exhausted if a valid forward target remains available.
- [ ] If authoritative state is unavailable or reservation safety cannot be established, the allocator fails closed rather than asserting that no eligible target exists.
- [ ] Expansion of the Engine ID space is not performed within the existing profile; it requires a separately defined profile or Class assignment as specified.
- [ ] Existing identifiers remain valid and are not renumbered during rollover or expansion planning.

## 7. Error-code precedence and failure handling

- [ ] Error names, triggers, and precedence agree across the specification, registry, and test vectors.
- [ ] `S64-E012 VALIDATION_UNAVAILABLE` takes precedence where required authoritative validation cannot complete; the implementation does not disguise unavailable authoritative state as a definitive missing-record, mismatch, or conflict result.
- [ ] `S64-E021 ALLOCATION_SAFETY_UNESTABLISHED` is used only according to its documented scope and precedence.
- [ ] E022 and E029 are distinguished by the actual rollover and terminal-exhaustion conditions, not by a guessed Engine ID or an unverified registry state.
- [ ] A power cut or hardware failure affecting allocation state or integrity produces `FAIL_HARD` as the required operational outcome.
- [ ] After `FAIL_HARD`, the system performs no last-ID lookup, automatic resume, automatic retry, or identifier allocation.
- [ ] Ordinary error codes or recovery paths do not override or weaken `FAIL_HARD`.
- [ ] The implementation does not allocate after a failure when allocation integrity or authoritative state is uncertain.
- [ ] Error-code reporting does not imply that an unsafe allocation succeeded.

## 8. Retirement, migration, and history-chain transitions

- [ ] Migration allocates a new Local ID through the receiving Engine’s authoritative allocation mechanism.
- [ ] The receiving Engine belongs to the same Class as the source identifier, unless the operation is explicitly a separately governed Class change.
- [ ] The source Local ID is not copied, requested as the new allocation, or manually assigned outside the authoritative allocator.
- [ ] The new record is created inactive, its authoritative Class-property record is created, and its history link is recorded before the activation/retirement transition completes, in the order specified.
- [ ] The transition ensures that at most one identifier in the history chain is resolvable by ordinary lookups at any time.
- [ ] If an early migration step fails, the source remains active and the newly consumed coordinate is not released or reused.
- [ ] If the final activation/retirement transition fails, the retry behavior follows the specification while preserving the resolvability invariant.
- [ ] `S64-E024 RETIREMENT_REQUIRED` is not triggered merely because successor allocation precedes source retirement; the specification expressly defines allocation-before-retirement.
- [ ] E024 is considered only for an operation or sequence step that specifically requires prior retirement, according to the registry definition.
- [ ] A Role change is expressed by retirement and reallocation, not by rewriting the Role bit in an existing identifier.

## 9. Test-vector verification

- [ ] Every vector has a unique identifier and an unambiguous setup.
- [ ] Expected error codes match the normative stage order and precedence.
- [ ] Field-validation vectors cover Reserved bits, Class `0000`, and reserved Class values.
- [ ] Authoritative-stage vectors cover missing allocation records, missing Class-property records, Class mismatches, duplicate same-State records, and unavailable authoritative data.
- [ ] History-chain vectors distinguish same-State duplicates from active/inactive records.
- [ ] Allocation vectors cover non-reuse, retired-coordinate reissue, allocator-authority loss, concurrent allocators, and unestablished allocation safety.
- [ ] Rollover vectors cover a valid forward target, an ineligible higher Engine, no eligible higher Engine, and unavailable authoritative state.
- [ ] Migration vectors verify that only one identifier in a history chain is ordinarily resolvable at a time.
- [ ] Profile-boundary vectors reject unsupported cross-profile reinterpretation or conversion.
- [ ] Serialization vectors verify preservation of all 64 bits and canonical representation.
- [ ] Any arithmetic, bit extraction, hexadecimal/decimal conversion, or expected-value calculation used in the vectors has been independently checked.
- [ ] Test-vector results have been checked against the final versions of the specification and error registry, not merely against earlier drafts.

## 10. Release packaging and final review

- [ ] All referenced files exist in the release package.
- [ ] Internal links, filenames, section references, and code names are correct.
- [ ] No unresolved placeholder, obsolete error code, or unsupported conformance claim remains.
- [ ] The release notes accurately describe changes and known limitations.
- [ ] The README and release metadata accurately state the release status.
- [ ] The complete file set has been reviewed for consistency after the last correction.
- [ ] Any change to normative behavior has been reviewed for its revision and compatibility implications.
- [ ] No implementation, concurrency, security, deployment, or performance guarantee is claimed without corresponding evidence.
- [ ] Release approval is withheld until all applicable blocking items are checked and unresolved normative contradictions are resolved.

## 11. Final disposition

**Release decision:** ☐ Approved ☐ Not approved ☐ Further review required

**Unresolved blocking issues:**

- None recorded / list unresolved items here.

**Reviewer:** ____________________

**Date:** ____________________

**Notes:**

This checklist supports release review; it does not replace the normative requirements in `SPECIFICATION.md`. Where a checklist item and the normative specification disagree, the discrepancy must be resolved before release rather than silently changing the specification’s meaning.
