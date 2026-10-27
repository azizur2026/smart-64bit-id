# SMART 64-Bit ID v1.42 — Routing Example

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Worked routing example for v1.42

Non-normative example.

## 1. Purpose

This file works through routing of a v1.42 identifier. It is informative. It demonstrates one valid routing path and its failure points. It does not introduce requirements. Where this file and the specification differ, the specification governs.

## 2. The identifier

Given the illustrative identifier `0x1404000540000007` = 1,442,277,803,213,979,655 from the generation example:

- Decode and validate Version/Revision before interpreting profile-dependent fields.

- Confirm Version 0, Revision 0010 selects v1.42.

- Extract Reserved (bits 54–57); reject if nonzero (S64-E003 RESERVED_BITS_NONZERO).

- Extract Class (bits 50–53). Confirm the encoded Class is in 0001–1000; reject 0000 (S64-E004 CLASS_ZERO) and 1001–1111 (S64-E005 CLASS_RESERVED).

- Confirm the encoded Class agrees with the authoritative Class-property record. Disagreement is S64-E007 CLASS_MISMATCH and is a hard stop. This check precedes virtual-engine lookup.

- Extract Engine = 42 and Class = 0001. Concatenate to the virtual-engine ID: Class (4 bits) + Engine (21 bits) = 25 bits.

- Look up the virtual-engine row for (0001, 42). Absence is S64-E013 VIRTUAL_ENGINE_NOT_FOUND.

- Resolve the physical engine address (IP/MAC) from the row. Unreachable is S64-E014 PHYSICAL_ENGINE_UNREACHABLE.

- Extract Local = 7 and perform the namespace-local lookup on the resolved Engine.

- When the identity and its Class are needed, obtain them from the authoritative record associated with Engine 42 and Local 7. Reject an invalid Class according to the specification.

- Apply application-level authentication and authorization separately; the identifier is not proof of permission.

```text
0x1404000540000007
         |
         +-- profile: Version 0 / Revision 0010 → v1.42
         +-- Reserved: 0000
         +-- Class: 0001 (Human) ────┐
         +-- Engine: 42 ─────────────┤
         |                           ▼
         |                    virtual-engine ID
         |                    Class(4) + Engine(21) = 25 bits
         |                           │
         |                           ▼
         |                    virtual-engine table row
         |                           │
         |                           ▼
         |                    physical engine address (IP/MAC)
         |                           │
         +-- Local: 7 ───────────────┘
                                     │
                                     ▼
                         lookup inside Engine 42
                                     │
                                     ▼
                         effective Class: authoritative record
```

## 3. Failure points and precedence

Each failure point corresponds to a code in `../errors/ERROR-CODES.md`. The precedence follows SPECIFICATION.md §16.1; routing failures occur after authoritative checks.

| Stage | Condition | Code | Hard stop |
|---|---|---|---|
| Profile | Version/Revision not v1.42 | S64-E002 UNSUPPORTED_PROFILE | Yes |
| Field | Reserved nonzero | S64-E003 RESERVED_BITS_NONZERO | Yes |
| Field | Encoded Class 0000 | S64-E004 CLASS_ZERO | Yes |
| Field | Encoded Class 1001–1111 | S64-E005 CLASS_RESERVED | Yes |
| Authoritative | Class record absent | S64-E006 CLASS_RECORD_MISSING | Yes |
| Authoritative | Encoded Class ≠ authoritative record | S64-E007 CLASS_MISMATCH | Yes |
| Authoritative | Coordinate absent from allocation registry | S64-E008 ALLOCATION_NOT_FOUND | Yes |
| Authoritative | Duplicate allocation records in same State | S64-E009 ALLOCATION_CONFLICT | Yes |
| Authoritative | Authoritative data unreachable | S64-E012 VALIDATION_UNAVAILABLE | Yes |
| Routing | (Class, Engine) row absent | S64-E013 VIRTUAL_ENGINE_NOT_FOUND | Yes |
| Routing | Physical address unreachable | S64-E014 PHYSICAL_ENGINE_UNREACHABLE | Yes |

The Class mismatch (S64-E007) is a hard stop and MUST be detected before virtual-engine lookup. It is not deferred to the physical-engine stage.

The administrative path — an admin shift of a physical engine — is not a stage of identifier validation. It is validated by the separate administrative procedure in SPECIFICATION.md §16.2. S64-E015 applies to that procedure, not to the reading of an identifier.

## 4. Why Class precedes virtual-engine lookup

Each Engine is bound to exactly one Class (SPECIFICATION.md §6.3). Multiple Engines may share the same Class. Given the Engine, the Class is determined. A virtual-engine row is keyed on the pair (Class, Engine). If the encoded Class disagrees with the authoritative record, the pair built from the encoded Class is not a valid routing key, even if a row exists for the pair. Routing on a mismatched pair would reach a physical engine serving the wrong Class.

The Class verification therefore gates the virtual-engine lookup. It does not follow it.

## 5. Multiple identifiers sharing a Class and Engine

Identifiers with the same Class and Engine share a virtual-engine ID and resolve through the same physical engine. They differ only in Local.

```text
0x1404000540000001   Class 0001, Engine 42, Local 1  ─┐
0x1404000540000002   Class 0001, Engine 42, Local 2  ─┼──▶ same virtual-engine row
0x1404000540000003   Class 0001, Engine 42, Local 3  ─┘    (0001, 42) → same physical engine
```

Local is the lookup identifier within the resolved Engine namespace. Local alone is not globally unique; the routing key is Class + Engine, and the namespace-local lookup uses Local.

## 6. Administrative rearrangement

Physical placement is operational and may be rearranged for load balancing (SPECIFICATION.md §8). The Class binding is fixed (§6.3).

```text
Before:  virtual-engine row (0001, 42) ──▶ physical engine A
After:   virtual-engine row (0001, 42) ──▶ physical engine B

Class in identifiers:    unchanged
Engine in identifiers:   unchanged
Class binding:           unchanged
Identifier validity:     unchanged
```

A System Admin MUST verify the virtual-engine Class property before shifting a physical engine. A shift that would move the Engine to a different Class is S64-E015 ENGINE_CLASS_BINDING_VIOLATION. This is an administrative-operation check (SPECIFICATION.md §16.2), not part of identifier validation.

Administrative rearrangement changes the mapping from virtual-engine row to physical engine address. It does not change any field in any allocated identifier.

## 7. Contrast with v1.41

v1.42 routes on Class + Engine. v1.41 routes on Engine alone.

```text
v1.41:  Engine ──▶ Engine namespace ──▶ Local lookup
        (Class-marker is 0000; effective Class obtained from authoritative record)

v1.42:  Class + Engine ──▶ virtual-engine ID ──▶ physical engine ──▶ Local lookup
        (Class is encoded; agreement with authoritative record verified before lookup)
```

An implementation MUST NOT apply the v1.41 Engine-alone routing rule to a v1.42 identifier (SPECIFICATION.md §8). The profile is identified from Version and Revision before the routing key is constructed.

## 8. Availability and successor Engines

If the resolved physical engine is unavailable, the identifier remains an identifier, and its record remains subject to the retention requirements of SPECIFICATION.md §10.3. SMART does not encode a successor Engine, and an association between an old identity and a new identity cannot be inferred from numerical proximity, Engine contiguity, or Local adjacency.

Resolution behavior for unavailable Engines is not defined by the identifier format. It belongs to the surrounding system.

## 9. Summary

Routing key is Class + Engine (25-bit virtual-engine ID). Fail-first on Class mismatch. The virtual-engine row maps to a physical engine address; the physical engine is rearranged administratively without altering the identifier or the Class binding. Local is the lookup identifier within the resolved Engine. v1.42 routes on Class + Engine; v1.41 routes on Engine alone.
