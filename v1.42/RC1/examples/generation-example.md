# SMART 64-Bit ID v1.42 — Generation Example

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Worked example of v1.42 identifier generation

## 1. Purpose

This file works through the generation of a v1.42 identifier from its component field values.

The example is informative: it demonstrates one valid generation path and the resulting 64-bit value. It does not introduce requirements. The normative requirements are stated in SPECIFICATION.md. Where this file and the specification differ, the specification governs.

## 2. Inputs to the example

Suppose an adopting system is allocating a new identifier with the following chosen field values:

| Field | Value | Source |
|---|---|---|
| Version | 0 | Fixed for the v1.42 profile. |
| Revision | 0010 | Fixed for the v1.42 profile. |
| Role | 1 (self-representing) | Determined externally to this specification. The profile encodes the designation; it does not define the criteria for it. Role is consumed by the application domain layer and is not read by the routing or allocation layers. |
| Reserved | 0000 | Required by the profile. |
| Class | 0001 (Human) | Determined by the Engine–Class binding of the target Engine. |
| Engine | 42 | The Engine to which the allocation is routed. |
| Local | 7 | The next Local ID from the Engine's authoritative allocator. |

Two of these inputs are determined by the Engine, not chosen freely. The Engine is 42; the Class is therefore 0001, because each Engine is bound to exactly one Class (SPECIFICATION.md §6.3) and Engine 42 is bound to Class 0001. If the Engine were bound to a different Class, the Class field would be that Class, not 0001. The Class value cannot be chosen independently of the Engine.

The Local value is assumed to be the next allocation from Engine 42's authoritative allocator. The example does not test allocation safety; it assumes the allocator has produced Local 7 as a fresh, never-before-allocated Local ID for Engine 42.

## 3. Field assembly

The identifier is assembled by placing each field value at its defined bit positions. The layout is:

```text
 63      62 61 60 59      58      57 56 55 54      53 52 51 50      49 ........ 29      28 ........ 0
┌─────────┬──────────────┬────────┬────────────────┬────────────────┬─────────────────────┬───────────────────┐
│ Version │   Revision   │  Role  │    Reserved    │     Class      │       Engine        │       Local       │
│  1 bit  │    4 bits    │ 1 bit  │     4 bits     │     4 bits     │      21 bits        │      29 bits      │
└─────────┴──────────────┴────────┴────────────────┴────────────────┴─────────────────────┴───────────────────┘
```

Substituting the input values:

```text
 63      62 61 60 59      58      57 56 55 54      53 52 51 50      49 ........ 29      28 ........ 0
┌─────────┬──────────────┬────────┬────────────────┬────────────────┬─────────────────────┬───────────────────────────────┐
│    0    │     0010     │   1    │      0000      │      0001      │ 000000000000000101010 │ 00000000000000000000000000111 │
└─────────┴──────────────┴────────┴────────────────┴────────────────┴─────────────────────┴───────────────────────────────┘
```

Reading the 64-bit value in nibbles from the most-significant bit to the least-significant bit:

| Nibble (bits) | Bits | Value | Source |
|---|---|---|---|
| 15 (63–60) | 0001 | 1 | Version 0 (bit 63) + top 3 bits of Revision 001 (bits 62,61,60) |
| 14 (59–56) | 0100 | 4 | bottom bit of Revision 0 (bit 59) + Role 1 (bit 58) + top 2 bits of Reserved 00 (bits 57,56) |
| 13 (55–52) | 0000 | 0 | bottom 2 bits of Reserved 00 (bits 55,54) + top 2 bits of Class 00 (bits 53,52) |
| 12 (51–48) | 0100 | 4 | bottom 2 bits of Class 01 (bits 51,50) + top 2 bits of Engine 00 (bits 49,48) |
| 11 (47–44) | 0000 | 0 | Engine |
| 10 (43–40) | 0000 | 0 | Engine |
| 9 (39–36) | 0000 | 0 | Engine |
| 8 (35–32) | 0101 | 5 | Engine (bit 34 = 1, bit 32 = 1) |
| 7 (31–28) | 0100 | 4 | Engine bottom 3 bits 010 (bits 31,30,29) + Local top bit 0 (bit 28) |
| 6 (27–24) | 0000 | 0 | Local |
| 5 (23–20) | 0000 | 0 | Local |
| 4 (19–16) | 0000 | 0 | Local |
| 3 (15–12) | 0000 | 0 | Local |
| 2 (11–8) | 0000 | 0 | Local |
| 1 (7–4) | 0000 | 0 | Local |
| 0 (3–0) | 0111 | 7 | Local 7 |

Concatenating the nibbles:

```text
1 4 0 4 0 0 0 5 4 0 0 0 0 0 0 7
```

The generated identifier is:

```text
0x1404000540000007
```

In decimal:

```text
1,442,277,803,213,979,655
```

## 4. Verification by field extraction

To verify the generated value, extract each field using the extraction rules in SPECIFICATION.md §16.

For ID = `0x1404000540000007`:

```text
Local    = ID & 0x1FFFFFFF           = 7
Engine   = (ID >> 29) & 0x1FFFFF     = 42
Class    = (ID >> 50) & 0x0F         = 0001  (Human)
Reserved = (ID >> 54) & 0x0F         = 0000
Role     = (ID >> 58) & 0x01         = 1     (self-representing)
Revision = (ID >> 59) & 0x0F         = 0010
Version  = (ID >> 63) & 0x01         = 0
```

Every extracted field matches the input value in §2. The generated identifier is consistent with its inputs.

## 5. Validation of the generated identifier

Evaluating `0x1404000540000007` as a v1.42 identifier, following the precedence in SPECIFICATION.md §16.1:

| Stage | Check | Result |
|---|---|---|
| 1. Input format | 16 hex characters, no prefix, no whitespace, no separators | Pass |
| 2. Profile identification | Version 0, Revision 0010 | Pass (v1.42) |
| 3. Field validity | Reserved 0000; Class 0001 (assigned, nonzero, not reserved); Role is a single bit | Pass |
| 4. Authoritative checks | Requires authoritative state: Class-property record present and agreeing; coordinate (42, 7) allocated; no duplicate; data reachable | Pass, given the assumed authoritative state |
| 5. Routing resolution | Requires routing state: virtual-engine row for (0001, 42) present; physical engine reachable | Pass, given the assumed routing state |

The identifier is valid v1.42, given the authoritative and routing state assumed in §2. The generation example demonstrates field assembly and field consistency; it does not itself establish that the authoritative record exists or that the coordinate is unique. Those are properties of the allocation operation, not of the bit assembly.

## 6. Cross-profile contrast: the corrected v1.41 vector

The v1.42 generated value is `0x1404000540000007`.

The corrected v1.41 vector from `../../v1.41/examples/generation-example.md` is `0x0C00000540000007`, derived from the same Engine 42, Local 7, and Role 1, with Revision 0001 in v1.41.

The two values are different 64-bit values, because the Revision field differs: 0010 in v1.42, 0001 in v1.41. They are not the same identifier and are not valid under both profiles.

Under normal validation, each is rejected under the other profile at profile identification, because its Version/Revision does not select the target profile. This is the decisive rejection. The Class-field observations below are informative: they show what would fail if the identifier were force-interpreted under the other profile's field rules, but force-interpretation is not the validation path.

```text
   v1.41 vector:  0x0C00000540000007
   ─────────────────────────────────
   Version  = 0
   Revision = 0001        → v1.41
   Role     = 1
   Reserved = 0000
   Class    = 0000        (marker)
   Engine   = 42
   Local    = 7
   Effective Class obtained from authoritative record.

   v1.42 value:   0x1404000540000007
   ─────────────────────────────────
   Version  = 0
   Revision = 0010        → v1.42
   Role     = 1
   Reserved = 0000
   Class    = 0001        (encoded)
   Engine   = 42
   Local    = 7
   Encoded Class agrees with authoritative record.
```

Reading the v1.41 vector under v1.42 rules: Revision is 0001, which is not the v1.42 Revision. The v1.42 reading rejects it at stage 2 as S64-E002 UNSUPPORTED_PROFILE, before its Class is evaluated. This is the normative rejection path.

Reading the v1.42 value under v1.41 rules: Revision is 0010, which is not the v1.41 Revision. The v1.41 reading rejects it as an unsupported revision. This is the normative rejection path. The Class-marker observation — 0001, nonzero — is informative: it shows the additional field-level incompatibility if the identifier were force-interpreted under v1.41 rules, but profile selection precedes field interpretation.

Mutual invalidity is therefore intact and needs no boundary-case caveat. The v1.41 vector and the v1.42 value differ in the Revision field, and each is invalid under the other profile at stage 2 (profile identification). The field-level explanation is informative; profile selection is the normative rejection.

## 7. The v1.41 pre-correction stale value

The pre-correction v1.41 value `0x0C04000540000007` = 865817050910556167 must not be reused.

Under v1.41 corrected rules: its Class-marker bits (bits 50–53) are 0001, nonzero, so it is invalid v1.41.

Under v1.42 rules: its Revision is 0001, which is v1.41, so it is rejected at stage 2 as S64-E002 UNSUPPORTED_PROFILE.

It is not a valid identifier under any corrected profile. It is mentioned here only to be ruled out.

## 8. A caution about hand computation

The value in §3 was derived by hand-assembling the nibbles from the bit layout, and the value in §4 was verified by field extraction against the extraction rules. The two derivations agree.

The self-identifying property means the extraction rule is deterministic once the profile is known: bits 63 and 59–62 determine the profile, and the field mask follows. The caution is about hand arithmetic, not about ambiguity of the rule.

The specific error to avoid is a mis-ordering of the Revision bits. Revision occupies bits 59–62 with bit 59 as the least-significant bit of the Revision value. Revision 0010 therefore places a 1 at bit 60 and a 0 at bit 59. Reading the Revision value as if bit 62 were the least-significant bit produces a different top nibble and a different 64-bit value, even though the Revision value is unchanged. The extraction rule in SPECIFICATION.md §16 (`(ID >> 59) & 0x0F`) is the definitive check.

An implementer should not rely on hand assembly for production generation. The extraction rules in SPECIFICATION.md §16 are the normative verification step, and a generated identifier should be verified by extraction before it is committed to the allocation registry.

This caution is informative. It does not add a requirement.

## 9. Summary

Generation of a v1.42 identifier is field assembly at the defined bit positions. The fields are Version 0, Revision 0010, Role, Reserved 0000, Class (determined by the Engine–Class binding), Engine, and Local.

The worked example, with Version 0, Revision 0010, Role 1, Class 0001, Engine 42, Local 7, generates:

```text
0x1404000540000007  =  1,442,277,803,213,979,655
```

This value differs from the corrected v1.41 vector `0x0C00000540000007` in the Revision field (0010 vs 0001), and the two are not the same identifier. Each is valid under its own profile and invalid under the other at stage 2 (profile identification).
