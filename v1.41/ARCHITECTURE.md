# SMART 64-Bit ID v1.41 — Architecture

**Status:** Explanatory, non-normative. See [SPECIFICATION.md](SPECIFICATION.md) for conformance requirements.

## 1. Architectural boundary

SMART specifies an identifier layout, profile selection, identity semantics, allocation-safety requirements, routing semantics, and migration constraints. It does not prescribe a particular database, consensus algorithm, replication topology, API, transport, control plane, or cloud platform.

## 2. Field layout

| Bits | Width | Field | Meaning |
|---|---:|---|---|
| 0–28 | 29 | Local | Allocation-local identifier |
| 29–49 | 21 | Engine | Engine/namespace identifier |
| 50–53 | 4 | Class | Entity class code |
| 54–57 | 4 | Reserved | Must be zero in v1.41 |
| 58 | 1 | Role | Self-representing/dependent designation |
| 59–62 | 4 | Revision | Profile selector |
| 63 | 1 | Version | Specification-family selector |

## 3. Identity and representation

The 54-bit Identity Core is:

```text
Class (4) + Engine (21) + Local (29) = 54 bits
```

For an allocated identity, the Identity Core is stable. The upper 10 bits form the representation/control area, but their mutability is not uniform: Role is semantically immutable for a given allocated identity even though it resides in that area. A representation with a conflicting Role is non-conforming.

The identity coordinate used for allocation uniqueness is `Engine + Local`. Class does not create a separate allocation namespace. Therefore, the same Engine/Local pair must not be treated as two independently allocated identities merely because the Class bits differ.

## 4. Class and Role

Class encodes a compact category; it does not establish a universal ontology or decide who has authority to classify an entity. Class `0000` is invalid for allocated v1.41 identifiers. Existing identities must not be rewritten to change Class.

Role distinguishes a self-representing designation (`1`) from a dependent designation (`0`) in the applicable identification relationship. It does not itself establish legal capacity, ownership, authority, autonomy, human status, or organizational status. Associations between identities are external relationship data and cannot be inferred from Role alone.

## 5. Allocation authority

Each Engine requires an authoritative allocation mechanism. A Local value successfully allocated in an Engine must never be successfully allocated again in that Engine, including after restart, restore, failover, ownership transfer, or recovery. A stale allocator must not commit after its authority ends. SMART specifies these outcomes, not the mechanism used to guarantee them.

The Engine and Local fields provide `2^21` and `2^29` possible values respectively. Their combined coordinate space is `2^50` (1,125,899,906,842,624) Engine/Local pairs, subject to actual allocation and governance policy.

## 6. Routing

The normative routing path is:

```text
SMART ID → extract Engine → route to Engine namespace → extract/lookup Local → entity
```

Engine is a logical namespace/routing selector, not necessarily a physical host or geographic region. Class is not the current normative routing selector. A future `Class + Engine` higher-level shard key is a deferred design topic, not a v1.41 requirement.

## 7. Migration and retirement

Changing Engine creates a new SMART identity. The receiving Engine must allocate a new Local through its authoritative allocator; migration cannot copy or manually assign the source Local. The source identity remains unchanged. A system may maintain an external association/history record between old and new identities.

An Engine may become unavailable or be retired; the identifier remains an identifier. SMART does not encode a successor Engine or prescribe resolution behavior for an unavailable namespace.

## 8. Profile and wire boundary

Version and Revision select the profile before profile-dependent fields are interpreted. Version `0`, Revision `0000` denotes v1.4; Version `0`, Revision `0001` denotes v1.41. Unsupported profiles must not be guessed. Canonical binary serialization is unsigned 64-bit big-endian/network byte order.
