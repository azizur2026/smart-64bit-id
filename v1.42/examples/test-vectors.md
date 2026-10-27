# SMART 64-Bit ID v1.42 — Test Vectors

**Status:** Release Candidate 1 — Python checks complete; cross-document findings remain
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Normative test vectors for v1.42 validation, routing, allocation, and retirement

## 1. Purpose and status

This file provides test vectors for SMART 64-Bit ID v1.42.

The vectors are normative in the following sense: a conforming v1.42 implementation that evaluates a vector and does not reach the stated outcome, or does not report the stated code where a code is stated, is non-conforming for that case. The vectors illustrate the requirements of SPECIFICATION.md. Where this file and the specification differ, the specification governs.

Codes referenced in this file are defined in `../errors/ERROR-CODES.md`. The vectors state the code a conforming implementation is expected to report; if a code is later renumbered or renamed, the vector's expected outcome is to be read as the condition, not the literal code.

Authoritative-state vectors state the assumed authoritative state explicitly. A vector that depends on authoritative state does not define that state; it tests the implementation's behavior given that state.

Canonical identifier values in this file are 16 hexadecimal characters, uppercase, with no prefix or whitespace, consistent with SPECIFICATION.md §16.1 step 1. Section 4.1 deliberately includes malformed inputs to test rejection of prefixes, whitespace, separators, non-hexadecimal characters, and incorrect lengths.

Python checks verified the hexadecimal-to-decimal conversions in §§3, 5, 7, and 10 and checked the stated field values in the canonical, field-validity, mutual-invalidity, designation-change, and serialization vectors against the `build()` and `extract()` operations in §11.

## 2. Notation

- "Stage" is the precedence stage from SPECIFICATION.md §16.1: (1) input format, (2) profile, (3) field, (4) authoritative, (5) routing.
- Administrative operations (E015) are validated by the separate procedure in SPECIFICATION.md §16.2; they are not a stage of identifier validation.
- Allocation, retirement, lifecycle, and conformance vectors carry their own stage label, as stated in `../errors/ERROR-CODES.md` §4.
- "Assumed authoritative state" is stated per vector where the vector reaches stage 4 or later.
- Where a vector admits more than one conforming code, the admissible set is stated and the reason given.

## 3. Canonical valid vectors, one per Class value

Each vector is a valid v1.42 identifier under the assumed authoritative state stated below the table. Class is the encoded Class. Engine is 42 for all vectors. Local is the Class value, for visual distinctness only; Local is not determined by Class.

| Vector | Hex | Decimal | Class | Engine | Local | Role |
|---|---|---|---|---|---|---|
| V-CLASS-0001 | `1404000540000001` | 1,442,277,803,213,979,649 | 0001 Human | 42 | 1 | 1 |
| V-CLASS-0010 | `1408000540000002` | 1,443,403,703,120,822,274 | 0010 Other Living Being | 42 | 2 | 1 |
| V-CLASS-0011 | `140C000540000003` | 1,444,529,603,027,664,899 | 0011 IoT / Device | 42 | 3 | 1 |
| V-CLASS-0100 | `1410000540000004` | 1,445,655,502,934,507,524 | 0100 AI | 42 | 4 | 1 |
| V-CLASS-0101 | `1414000540000005` | 1,446,781,402,841,350,149 | 0101 Organization | 42 | 5 | 1 |
| V-CLASS-0110 | `1418000540000006` | 1,447,907,302,748,192,774 | 0110 Artifact / Object | 42 | 6 | 1 |
| V-CLASS-0111 | `141C000540000007` | 1,449,033,202,655,035,399 | 0111 Android / Humanoid Artificial Entity | 42 | 7 | 1 |
| V-CLASS-1000 | `1420000540000008` | 1,450,159,102,561,878,024 | 1000 Natural / Celestial Object | 42 | 8 | 1 |

Assumed authoritative state per vector: Class-property record present and agreeing with the encoded Class; Engine + Local coordinate allocated; no duplicate allocation; virtual-engine row for (Class, Engine) present; physical engine reachable. Expected outcome: Valid.

## 4. Input-format and profile vectors

### 4.1 Input format (stage 1)

| Vector | Input | Expected code |
|---|---|---|
| V-IN-01 | `0x1404000540000001` | S64-E011 MALFORMED_INPUT |
| V-IN-02 | ` 1404000540000001` | S64-E011 MALFORMED_INPUT |
| V-IN-03 | `140400054000000G` | S64-E011 MALFORMED_INPUT |
| V-IN-04 | `1404 0005 4000 0001` | S64-E011 MALFORMED_INPUT |
| V-IN-05 | `14-04-00-05-40-00-00-01` | S64-E011 MALFORMED_INPUT |
| V-IN-06 | `14040005@0000001` | S64-E011 MALFORMED_INPUT |
| V-IN-06b | `xyz` | S64-E011 MALFORMED_INPUT |
| V-IN-07 | `140400054000000` | S64-E001 INVALID_LENGTH |
| V-IN-08 | `14040005400000001` | S64-E001 INVALID_LENGTH |
| V-IN-09 | (empty) | S64-E001 INVALID_LENGTH |

V-IN-06b is both non-hex and wrong length. Under the precedence in SPECIFICATION.md §16.1 step 1, formatting is validated before length; the expected code is E011, not E001.

### 4.2 Profile identification (stage 2)

| Vector | Hex | Version | Revision | Expected code |
|---|---|---|---|---|
| V-PRO-01 | `9404000540000001` | 1 | 0010 | S64-E002 UNSUPPORTED_PROFILE |
| V-PRO-02 | `0404000540000001` | 0 | 0000 | S64-E002 UNSUPPORTED_PROFILE |
| V-PRO-03 | `0C00000540000001` | 0 | 0001 | S64-E002 UNSUPPORTED_PROFILE |
| V-PRO-04 | `1C04000540000001` | 0 | 0011 | S64-E002 UNSUPPORTED_PROFILE |
| V-PRO-05 | `3C04000540000001` | 0 | 0111 | S64-E002 UNSUPPORTED_PROFILE |

Note on V-PRO-02: `0404000540000001` has Revision 0000 (v1.4) but Class 0001 and Reserved 0000. Under v1.42 rules it is rejected at stage 2 as unsupported profile. Under v1.4 rules, it is evaluated against v1.4's Region field (bits 50–57), which is outside this file's scope. The vector's purpose is to show that v1.42 rejects it at stage 2, before any field at bits 50–53 is interpreted.

Note on V-PRO-03: `0C00000540000001` has Revision 0001 (v1.41). Under v1.42 rules, rejected at stage 2. Its v1.41 reading is a separate evaluation; see §7.

## 5. Field-validity vectors (stage 3)

All vectors in this section have Version 0, Revision 0010, and are rejected at stage 3.

| Vector | Hex | Decimal | Condition | Expected code |
|---|---|---|---|---|
| V-FLD-01 | `1444000540000001` | 1,460,292,201,723,461,633 | Reserved = 0001 | S64-E003 RESERVED_BITS_NONZERO |
| V-FLD-02 | `17C4000540000001` | 1,712,493,780,856,209,409 | Reserved = 1111 | S64-E003 RESERVED_BITS_NONZERO |
| V-FLD-03 | `1400000540000001` | 1,441,151,903,307,137,025 | Class = 0000 | S64-E004 CLASS_ZERO |
| V-FLD-04 | `1424000540000001` | 1,451,285,002,468,720,641 | Class = 1001 | S64-E005 CLASS_RESERVED |
| V-FLD-05 | `143C000540000001` | 1,458,040,401,909,776,385 | Class = 1111 | S64-E005 CLASS_RESERVED |
| V-FLD-06 | `1464000540000001` | 1,469,299,400,978,202,625 | Class = 1001, bit 54 set | S64-E003 RESERVED_BITS_NONZERO |

Note on V-FLD-06: Class 1001 is reserved and bit 54 is Reserved and set. At stage 3, E003 precedes E005. The expected code is E003, not E005. This vector demonstrates that bit 54 is Reserved in v1.42, not part of Class.

The precedence of E003 over E004 over E005 at stage 3 is normative per SPECIFICATION.md §16.1 step 3.

Role is a single bit. Both values are valid in v1.42. No field-level Role failure exists in v1.42. A Role change is expressed by retirement and reallocation (see §8), not by a field error. E010 is a lifecycle error, not a field error.

## 6. Authoritative-stage and routing-stage vectors

Unless a vector explicitly tests rejection at an earlier stage, it assumes the field-valid identifier `1404000540000001` and states the assumed authoritative or routing state.

### 6.1 Authoritative (stage 4)

| Vector | Assumed state | Expected code |
|---|---|---|
| V-AUTH-01 | Class record present and agreeing; coordinate allocated; no duplicate; reachable | Valid |
| V-AUTH-02 | Class record absent | S64-E006 CLASS_RECORD_MISSING |
| V-AUTH-03 | Class record present with Class 0010, encoded Class 0001 | S64-E007 CLASS_MISMATCH |
| V-AUTH-04 | Coordinate absent from allocation registry | S64-E008 ALLOCATION_NOT_FOUND |
| V-AUTH-05 | Two canonical allocation records exist for the same Engine + Local coordinate, one active and one retired | S64-E009 ALLOCATION_CONFLICT |
| V-AUTH-05b | Two canonical allocation records exist for the same Engine + Local coordinate, both active | S64-E009 ALLOCATION_CONFLICT |
| V-AUTH-06 | Authoritative data unreachable | S64-E012 VALIDATION_UNAVAILABLE |
| V-AUTH-07 | Coordinate absent and Class record also absent | S64-E008 ALLOCATION_NOT_FOUND |
| V-AUTH-08 | Class record absent, but encoded Class also 0000 | S64-E004 CLASS_ZERO |

Note on V-AUTH-07: E008 precedes E006 at stage 4. The coordinate must exist before its record can be looked up. The expected code is E008.

Note on V-AUTH-08: a field-valid identifier cannot have encoded Class 0000; the vector illustrates that a value with Class 0000 would be rejected at stage 3, before stage 4 is reached. It is included for completeness only and is not a stage-4 vector.

Notes on V-AUTH-05 and V-AUTH-05b: more than one canonical allocation record for a coordinate is S64-E009 ALLOCATION_CONFLICT regardless of lifecycle State, as specified in SPECIFICATION.md §16.1 step 4. Retirement updates the existing canonical record; it does not create a second canonical allocation record. A successor in a history chain MUST use a different Engine + Local coordinate; audit events, if retained, are separate from the canonical allocation registry. The ERROR-CODES.md registry and SPECIFICATION.md consistently define S64-E009 ALLOCATION_CONFLICT for duplicate canonical allocation records regardless of lifecycle State. E030 is not defined in v1.42.

### 6.2 Routing (stage 5)

| Vector | Assumed routing state | Expected code |
|---|---|---|
| V-RT-01 | (Class 0001, Engine 42) row present; physical reachable | Valid |
| V-RT-02 | (Class 0001, Engine 42) row absent | S64-E013 VIRTUAL_ENGINE_NOT_FOUND |
| V-RT-03 | Row present; physical address unreachable | S64-E014 PHYSICAL_ENGINE_UNREACHABLE |
| V-RT-04 | Encoded Class 0001, authoritative Class 0010, (Class 0010, Engine 42) row present | S64-E007 CLASS_MISMATCH |

Note on V-RT-04: the Class mismatch is detected at stage 4, before stage 5. The expected code is E007, not E013. The presence of the 0010 row is irrelevant because the encoded Class is 0001 and fails agreement before routing is attempted.

## 7. Mutual-invalidity vectors

These vectors test the profile-coexistence rules in SPECIFICATION.md §13.

| Vector | Hex | Evaluated as | Expected |
|---|---|---|---|
| V-MI-01 | `0C00000540000007` | v1.41 | Valid v1.41; effective Class from authoritative record |
| V-MI-02 | `0C00000540000007` | v1.42 | S64-E002 UNSUPPORTED_PROFILE |
| V-MI-03 | `1404000540000001` | v1.41 | Invalid v1.41; Revision 0010 unsupported |
| V-MI-04 | `1404000540000001` | v1.42 | Valid (assuming authoritative state; same as V-CLASS-0001) |
| V-MI-05 | `0C04000540000007` | v1.41 | Invalid v1.41; Class-marker bits 0001 nonzero |
| V-MI-06 | `0C04000540000007` | v1.42 | S64-E002 UNSUPPORTED_PROFILE |

Note on V-MI-01: `0C00000540000007` = 864,691,151,003,713,543 is the corrected v1.41 vector. Its fields under v1.41 rules are Version 0, Revision 0001, Role 1, Reserved 0000, Class-marker 0000, Engine 42, Local 7. It is valid v1.41 with effective Class obtained from the authoritative record.

Note on V-MI-02: the same value, evaluated under v1.42 rules, has Revision 0001, which is not v1.42. It is rejected at stage 2 as S64-E002. This is the normative rejection path: profile identification precedes field interpretation. The Class field also reads 0000, which would be S64-E004 if stage 3 were reached; that observation is informative, not the rejection reason.

Note on V-MI-03: `1404000540000001` evaluated as v1.41 has Revision 0010, which is not v1.41. Rejected at stage 2. The Class-marker bits also read 0001, nonzero, which would also be invalid v1.41; that observation is informative.

Note on V-MI-05: `0C04000540000007` = 865,817,050,910,556,167 is the pre-correction stale value. It must not be reused. Its Class-marker bits are 0001 (nonzero), so it is invalid v1.41.

## 8. Designation-change reallocation vectors

These vectors test the retirement-and-reallocation path in SPECIFICATION.md §4.1, §10, and §10.5. They operate on allocation records, not on isolated 64-bit values, because retirement is a record-level transition and is not encoded in the identifier.

Whether and when a designation change occurs is determined externally to this specification. These vectors test the mechanical invariants of the identifier pair given that a designation change has been determined and is to be expressed by retirement and reallocation. They do not assert, and must not be read as asserting, that any particular designation change is correct, lawful, or appropriate.

### 8.1 Designation change, same Engine

| Vector | Scenario | Expected |
|---|---|---|
| V-DESIG-01 | Identifier `1004000540000001` (Engine 42, Local 1, Class 0001, Role 0) is active. A new identifier is allocated in the same Engine (42), Class 0001, Role 1, Local 2: `1404000540000002`. The successor is allocated inactive and linked to the source; activation of the successor and retirement of the source commit atomically (or through an equivalent protocol with the same externally observable invariant). | Valid. Class unchanged. Role changed. At most one identifier in the chain is resolvable at any time. Retired coordinate (42, 1) permanently consumed. Retired record and tombstone retained. |

### 8.2 Designation change, Engine exhausted, rollover to next Engine

| Vector | Scenario | Expected |
|---|---|---|
| V-DESIG-02 | Identifier `1004000540000003` (Engine 42, Local 3, Class 0001, Role 0) is active. Engine 42 is exhausted; Engine 43 is the lowest eligible forward Engine ID, unbound, and safely reservable. It is atomically bound to Class 0001 before Local 0 is allocated, producing `1404000560000000`. | Valid. Class unchanged. Role changed. Retired coordinate (42, 3) permanently consumed. New coordinate (43, 0) allocated through the receiving Engine's authoritative allocator. History chain linked. |

### 8.3 Negative designation-change vectors

| Vector | Scenario | Expected code |
|---|---|---|
| V-DESIG-03 | `1004000540000001` is active. A workflow step explicitly requiring the source to already be retired is attempted before the source-retirement transition commits. | S64-E024 RETIREMENT_REQUIRED |
| V-DESIG-04 | `1004000540000001` is active. An attempt is made to change its Role by rewriting the Role bit. | S64-E010 ROLE_INVALID |
| V-DESIG-05 | `1004000540000001` is retired. An allocation is attempted at (42, 1) for a different identity, same Role and Class, producing `1004000540000001` again. | S64-E016 RETIRED_COORDINATE_REISSUE |
| V-DESIG-06 | `1004000540000001` is retired. An allocation is attempted at (42, 1) with Role 1, producing `1404000540000001`. | S64-E016 RETIRED_COORDINATE_REISSUE |
| V-DESIG-07 | `1004000540000001` is retired. Its retired record cannot be produced. | S64-E017 RETIRED_RECORD_MISSING |
| V-DESIG-08 | `1004000540000001` is retired. An active-path operation is attempted on it. | S64-E025 RETIRED_IDENTIFIER_OPERATION |
| V-DESIG-09 | `1404000540000004` (Engine 42, Local 4, Class 0001, Role 1) is retired. A reallocation is attempted into Engine 45, Class 0010, Local 0: `14080005A0000000`. | S64-E015 ENGINE_CLASS_BINDING_VIOLATION |
| V-DESIG-10 | Fault-inject a power cut or hardware failure before, during, and immediately after the successor/source atomic transition. | FAIL_HARD; no last-ID lookup, no automatic resume, and no allocation. The persisted state must be transactionally pre-transition or post-transition; ordinary lookups must never expose both identifiers as resolvable. |

Note on V-DESIG-06: the retired coordinate is (42, 1). The attempted allocation would produce a different 64-bit value (`1404000540000001`, Role 1) from the retired value (`1004000540000001`, Role 0). The coordinate is nevertheless permanently consumed. The expected code is E016. This vector tests that coordinate permanence is independent of whether the resulting 64-bit value would differ.

Note on V-DESIG-09: this vector tests E015 in its reallocation trigger. The registry's E015 trigger (`../errors/ERROR-CODES.md` §5.6) covers administrative shifts, reallocations, and migrations that would associate an identifier with an Engine of a different Class.

## 9. Allocation-stage, administrative-stage, and conformance vectors

### 9.1 Allocation (operation stage)

| Vector | Scenario | Expected code |
|---|---|---|
| V-ALLOC-01 | Allocate at Engine 42, Local 1, after (42, 1) has been successfully allocated and is active. | S64-E018 LOCAL_REUSE_VIOLATION |
| V-ALLOC-02 | Allocate at Engine 42, Local 1, after (42, 1) has been allocated and retired. | S64-E016 RETIRED_COORDINATE_REISSUE |
| V-ALLOC-03 | Stale allocator commits a new allocation after its authority ended. | S64-E019 ALLOCATOR_AUTHORITY_LOST |
| V-ALLOC-04 | Two authoritative allocators both succeed within the same Engine. | S64-E020 CONCURRENT_ALLOCATOR |
| V-ALLOC-05 | Implementation cannot establish safe uniqueness and non-reuse. | S64-E021 ALLOCATION_SAFETY_UNESTABLISHED |
| V-ALLOC-06 | Engine 42 is exhausted; Engine 43 is unbound and safely reservable; no lower Engine ID may be considered. Bind Engine 43 to Class 0001 atomically and allocate there. | S64-E022 ENGINE_EXHAUSTED; rollover target Engine 43 |
| V-ALLOC-06a | Engine 43 is bound to Class 0010, Engine 44 is bound to Class 0001 but exhausted, and Engine 45 is unbound and safely reservable. | S64-E022 ENGINE_EXHAUSTED; choose lowest eligible forward target Engine 45 |
| V-ALLOC-06b | Engine 42 is exhausted and authoritative search proves that every Engine ID greater than 42 is ineligible or bound to another Class. | S64-E029 ENGINE_ID_SPACE_EXHAUSTED |
| V-ALLOC-06c | Engine 42 is exhausted but the authoritative Engine-Class registry cannot be queried, or target reservation safety cannot be established. | S64-E012 VALIDATION_UNAVAILABLE or S64-E021 ALLOCATION_SAFETY_UNESTABLISHED; do not issue an identifier and do not report E029 |
| V-ALLOC-06d | Two allocators attempt to bind unbound Engine 43 to different Classes concurrently. | At most one binding may commit; the loser fails without issuing an identifier (S64-E020 or S64-E021 as applicable) |
| V-ALLOC-06e | A power cut or hardware failure occurs during allocation or rollover. | FAIL_HARD; no last-ID lookup, no automatic resume, no identifier issued |
| V-ALLOC-07 | Allocation attempt with Engine 2097152 (out of range). | S64-E023 COORDINATE_OUT_OF_RANGE |
| V-ALLOC-08 | Allocation attempt with Local 536870912 (out of range). | S64-E023 COORDINATE_OUT_OF_RANGE |

Note on V-ALLOC-02: the retired-coordinate rule (SPECIFICATION.md §10.2) takes precedence over the Local non-reuse rule (§7) for a retired coordinate. The expected code is E016. This precedence is stated normatively in `../errors/ERROR-CODES.md` §4.5.

Notes on V-ALLOC-06 through V-ALLOC-06e: E022 is valid only after the lowest eligible forward Engine has been safely reserved. E029 requires an authoritative proof that no eligible higher Engine remains; it can occur before the maximum numeric Engine ID. An unavailable query or unsafe reservation is not proof of terminal exhaustion. Power/hardware failure invokes FAIL_HARD and prohibits last-ID lookup or automatic restart.

### 9.2 Administrative (operation stage)

| Vector | Scenario | Expected code |
|---|---|---|
| V-ADM-01 | Admin shift of the physical engine behind virtual-engine row (Class 0001, Engine 42) to a physical engine serving Class 0010. | S64-E015 ENGINE_CLASS_BINDING_VIOLATION |
| V-ADM-02 | Admin shift to another physical engine serving Class 0001, for load balancing. | Valid |

### 9.3 Conformance (implementation-level)

| Vector | Scenario | Expected code |
|---|---|---|
| V-CONF-01 | Operation applies v1.41 rules to a v1.42 identifier and accepts it, or applies v1.42 rules to a v1.41 identifier and accepts it, or converts between profiles by rewriting, truncating, or masking bits. | S64-E026 PROFILE_BOUNDARY_VIOLATION |
| V-CONF-02 | Field extraction produces a value inconsistent with the defined bit positions for v1.42. | S64-E027 FIELD_EXTRACTION_INVALID |
| V-CONF-03 | Binary serialization does not preserve all 64 bits in canonical form where canonical interoperability is required. | S64-E028 SERIALIZATION_NONCANONICAL |

### 9.4 Lifecycle (operation stage)

| Vector | Scenario | Expected code |
|---|---|---|
| V-LIFE-01 | An operation attempts to change the Role value of an existing allocated identifier. | S64-E010 ROLE_INVALID |

## 10. Deferred-expansion and serialization vectors

### 10.1 Deferred expansion

Bit 54 is Reserved in v1.42. The 5-bit Class expansion is not part of v1.42.

| Vector | Hex | Expected code |
|---|---|---|
| V-DEF-01 | `1444000540000001` | S64-E003 RESERVED_BITS_NONZERO |
| V-DEF-02 | `1464000540000001` | S64-E003 RESERVED_BITS_NONZERO |
| V-DEF-03 | `1404000540000001` | Valid (control; bit 54 clear) |

V-DEF-01 and V-DEF-02 also confirm that bit 54 is Reserved in v1.42: under the deferred 5-bit expansion, bit 54 would be part of Class, and these vectors would not trigger E003. In v1.42 they do.

### 10.2 Serialization round-trip

| Vector | Hex | Decimal | Big-endian bytes |
|---|---|---|---|
| V-SER-01 | `1404000540000007` | 1,442,277,803,213,979,655 | `14 04 00 05 40 00 00 07` |
| V-SER-02 | `1404000540000001` | 1,442,277,803,213,979,649 | `14 04 00 05 40 00 00 01` |
| V-SER-03 | `100C000540000003` | 1,156,299,226,875,953,155 | `10 0C 00 05 40 00 00 03` |
| V-SER-04 | `FFFFFFFFFFFFFFFF` | 18,446,744,073,709,551,615 | `FF FF FF FF FF FF FF FF` |
| V-SER-05 | `0000000000000000` | 0 | `00 00 00 00 00 00 00 00` |

V-SER-04 and V-SER-05 are serialization round-trip controls. They are not valid v1.42 identifiers; V-SER-04 has Version 1 and V-SER-05 has Revision 0000 (v1.4). They are included only to exercise 64-bit round-trip fidelity.

## 11. Reference implementation of `build()` and `extract()`

The following expressions are the field assembly and extraction operations used to confirm the numeric values in this file. They are notation, not prescribed implementation.

```text
build(V, Rev, Role, Res, Class, Engine, Local):
    (V << 63) | (Rev << 59) | (Role << 58) | (Res << 54) |
    (Class << 50) | (Engine << 29) | Local

extract(ID):
    Version  = (ID >> 63) & 0x1
    Revision = (ID >> 59) & 0xF
    Role     = (ID >> 58) & 0x1
    Reserved = (ID >> 54) & 0xF
    Class    = (ID >> 50) & 0xF
    Engine   = (ID >> 29) & 0x1FFFFF
    Local    = ID & 0x1FFFFFFF
```

A conforming implementation MUST produce the same extracted field values for each identifier as the values stated in the tables above. The build expression is not normative; the extraction expressions are those of SPECIFICATION.md §16.

## 12. Summary

The vectors are grouped as follows: eight canonical valid vectors (§3), input and profile vectors (§4), field-validity vectors (§5), authoritative and routing vectors (§6), mutual-invalidity vectors (§7), designation-change reallocation vectors (§8), allocation, administrative, conformance, and lifecycle vectors (§9), deferred-expansion and serialization vectors (§10).

Python checks verified all hexadecimal-to-decimal conversions and checked the stated identifier fields against the `build()` and `extract()` operations in §11. These arithmetic and structural checks do not establish implementation conformance and do not resolve normative contradictions between companion documents.

Where a vector admits more than one conforming code, the admissible set is stated and the reason given.
