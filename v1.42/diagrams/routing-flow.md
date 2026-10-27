# SMART 64-Bit ID v1.42 — Routing Flow

**Status:** Release Candidate 1 — cross-check in progress
**Specification family:** SMART 64-Bit ID
**Profile:** Version 0, Revision 0010
**Companion document:** SPECIFICATION.md
**Document purpose:** Diagrammatic reference for v1.42 routing semantics

## 1. Purpose

This file presents the v1.42 routing flow in diagrammatic form. It is a reference aid for the normative content of SPECIFICATION.md §8 and §6.3. Where this file and the specification differ, the specification governs.

The routing flow is reproduced here for convenience. It does not introduce requirements. The normative requirements for routing are stated in §8, and the Engine–Class binding that routing depends on is stated in §6.3.

## 2. Routing key

v1.42 routes on Class + Engine.

```text
     Class (4)     │       Engine (21)
───────────────────┼────────────────────────
      └────────── 25 bits total ───────────┘
                  virtual-engine ID
```

The virtual-engine ID is the concatenation of Class and Engine. It is not a hash and is not a surrogate. Each virtual-engine ID is a row in a virtual-engine table, mapping to a physical engine address (IP or MAC) (§8).

This differs from v1.41 routing, which uses Engine alone. Implementations MUST NOT apply the v1.41 Engine-alone routing rule to a v1.42 identifier (§8).

## 3. End-to-end resolution flow

Identifier validation proceeds through stages 1–5 of SPECIFICATION.md §16.1. Administrative operations are validated separately by the procedure in §16.2 and are not a stage of identifier validation.

```text
┌──────────────────────────┐
│   SMART ID (64 bits)     │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Identify profile from    │
│ Version + Revision       │──── unsupported ──▶ S64-E002 UNSUPPORTED_PROFILE
└────────────┬─────────────┘
             │ v1.42
             ▼
┌──────────────────────────┐
│ Extract Class + Engine   │
│ (bits 50–53 + 29–49)     │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Verify encoded Class vs  │──── mismatch ───▶ S64-E007 CLASS_MISMATCH
│ authoritative record     │                    (hard stop)
└────────────┬─────────────┘
             │ agree
             ▼
┌──────────────────────────┐
│ Look up virtual engine   │──── absent ─────▶ S64-E013 VIRTUAL_ENGINE_NOT_FOUND
│ (Class + Engine row)     │
└────────────┬─────────────┘
             │ found
             ▼
┌──────────────────────────┐
│ Resolve physical engine  │──── unreachable ─▶ S64-E014 PHYSICAL_ENGINE_UNREACHABLE
│ address (IP / MAC)       │
└────────────┬─────────────┘
             │ reachable
             ▼
┌──────────────────────────┐
│ Extract Local            │
│ (bits 0–28)              │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Look up Local ID         │
│ within Engine namespace  │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Resolve identity and     │
│ authoritative Class      │
│ property record          │
└──────────────────────────┘
```

Administrative operations — an admin shift of a physical engine, a reallocation, or a migration — are validated by a separate procedure: check the Engine-to-Class binding; if the operation would associate an identifier with an Engine of a different Class, reject with S64-E015 ENGINE_CLASS_BINDING_VIOLATION; otherwise commit. This procedure is not executed as part of an ordinary read.

## 4. Failure points and their codes

Each failure point in the flow above corresponds to a code in `../errors/ERROR-CODES.md`. The precedence below reflects SPECIFICATION.md §16.1; routing failures occur after authoritative checks, and the Class mismatch check occurs before virtual-engine lookup.

| Stage | Condition | Code | Hard stop? |
|---|---|---|---|
| Profile identification | Version/Revision not supported | S64-E002 UNSUPPORTED_PROFILE | Yes |
| Class verification | Encoded Class ≠ authoritative record | S64-E007 CLASS_MISMATCH | Yes |
| Virtual-engine lookup | Class + Engine not in table | S64-E013 VIRTUAL_ENGINE_NOT_FOUND | Yes |
| Physical resolution | Physical address unreachable | S64-E014 PHYSICAL_ENGINE_UNREACHABLE | Yes |

The Class mismatch is a hard stop and MUST be detected before physical engine resolution (§8). It is not deferred to the physical-engine stage.

## 5. Why Class precedes physical resolution

Each Engine is bound to exactly one Class (§6.3). Multiple Engines may share the same Class. Given the Engine, the Class is determined. A physical engine that has been moved, or whose virtual-engine row has been updated, may no longer correspond to the Class encoded in the identifier. The virtual-engine lookup is therefore the correct gate before physical resolution: if the (Class, Engine) pair is not present, the identifier does not belong to any currently reachable physical engine for that Class.

The Class verification step precedes the virtual-engine lookup because the encoded Class must agree with the authoritative record before the pair can be treated as a routing key. A pair built on a mismatched Class would route incorrectly even if the virtual-engine row existed for the wrong Class.

## 6. Administrative rearrangement

Physical placement is operational and may be rearranged by a System Admin for load balancing (§8). The Class value is mandatory and unchanged across rearrangements; the Class binding is fixed (§6.3).

A System Admin MUST verify the virtual engine's Class property before shifting any physical engine. A shift that would move an Engine to a different Class is S64-E015 ENGINE_CLASS_BINDING_VIOLATION (§6.3, §16.2).

Administrative rearrangement changes the mapping from virtual-engine row to physical engine address. It does not change the Class field in any allocated identifier, and it does not change the Engine field. Identifiers remain valid and routable across rearrangement, subject to the virtual-engine table being updated consistently.

```text
Administrative shift:

   virtual-engine row ──▶ physical engine A     (before)
   virtual-engine row ──▶ physical engine B     (after)

   Class in identifiers:    unchanged
   Engine in identifiers:   unchanged
   Class binding:           unchanged
   Identifier validity:     unchanged
```

## 7. What routing does not do

Routing does not change any field of the identifier. It does not rewrite Class, Engine, Local, Role, Revision, Version, or Reserved bits (§15, §17). It resolves an already-valid identifier to a physical engine.

Routing does not infer the Class from a cached copy without verification (§8). It uses the encoded Class and verifies it against the authoritative record before resolution.

Routing does not resolve retired identifiers through the active path. A retired identifier's record is retained (§10.3), but resolution behavior for retired identifiers is distinct from active-path routing and is not defined by the identifier format (§11).

## 8. Summary

v1.42 routing flow:

```text
SMART ID
   │
   ▼
profile identification (Version + Revision)
   │
   ▼
Class + Engine extraction
   │
   ▼
Class verification (encoded vs authoritative record)
   │
   ▼
virtual-engine lookup (Class + Engine → row)
   │
   ▼
physical engine address resolution (row → IP / MAC)
   │
   ▼
Local extraction and lookup
   │
   ▼
identity and authoritative Class resolution
```

Routing key is Class + Engine (25-bit virtual-engine ID). Fail-first on Class mismatch. Class binding is fixed; physical placement may be rearranged administratively without altering the binding.
