# SMART 64-Bit ID v1.42 — Integration Patterns

**Status:** Release Candidate 1 — cross-check in progress

Non-normative patterns. These examples do not replace the normative specification.

## 1. Storage

An implementation may store records in Engine-local namespaces and use Local as a local key, while retaining the complete 64-bit SMART value as an external/current representation. It may instead store the complete identifier as a database key. SMART does not mandate a schema or database technology.

Whatever representation is selected, it must preserve the Engine + Local uniqueness coordinate and the v1.42 identity semantics. A Class change or Role change must not be implemented by rewriting an already allocated identity. In v1.42 the encoded Class must agree with the authoritative Class-property record; a stored record that carries one without the other is incomplete for validation.

Each identifier record should also carry the link to the identifier it replaced, if any — the history chain (SPECIFICATION.md §10.6) — and the record's State. A coordinate-consumption tombstone should be retained separately, per §10.3.

## 2. Allocation service

A typical allocation API delegates to an authoritative allocator for the selected Engine. The Engine determines the Class (each Engine is bound to exactly one Class), so the Class is not chosen independently at allocation time.

```text
request identity
    │
    ▼
select authorized Engine namespace
    │
    ▼
Engine → Class binding determines encoded Class
    │
    ▼
authoritative Local allocator
    │
    ├── safe allocation established ──► assemble/validate SMART ID
    │                                   verify Class agreement
    │                                   record State = inactive
    │
    └── safety uncertain/exhausted ───► fail; do not reuse Local
```

A database sequence, transactional allocator, leased range, or another mechanism may be used only if it actually provides the required uniqueness, no-reuse, and stale-owner fencing guarantees under the implementation's failure model.

A retired Engine + Local coordinate is permanently consumed. The allocator must not reissue it, and the allocation path must treat retired coordinates as unavailable regardless of whether the resulting 64-bit value would differ. A coordinate allocated but not yet activated is also treated as consumed.

## 3. Designation change and migration

A change of designation is expressed by retiring the old identifier and allocating a new one. Allocation precedes retirement. The sequence is:

- Allocate the new identifier (record created, State = inactive, not resolvable).

- Create its authoritative Class-property record.

- Link it to the source identifier in the history chain.

- Activate the new identifier and retire the source identifier, such that at most one identifier in the chain is resolvable at any time. The allocator may use an implementation-specific workflow status (such as "on hold") to hold the new record non-resolvable until the transition completes.

- Retain both records and the tombstone for the retired coordinate.

If any step before activation fails, the source identifier remains active. The allocated but uncommitted coordinate is treated as consumed.

The Class must remain unchanged across the pair; a reallocation into an Engine of a different Class is a violation. Migration to another Engine for any reason follows the same sequence. Do not copy the old Local merely to preserve its numeric value. The history chain is the normative record of the relationship; additional external lifecycle data may be maintained.

## 4. Legacy boundary

A legacy-only v1.4 endpoint must validate according to v1.4 and explicitly reject an incompatible v1.41 or v1.42 identifier. It must not mask or rewrite the bits to make the value appear to be v1.4. A mixed deployment needs an explicit profile-aware boundary or routing decision before profile-dependent decoding.

A v1.42 boundary must likewise reject a v1.41 identifier, and must not treat a failed v1.41 validation as evidence that the identifier is v1.42. Profile is identified from Version and Revision before profile-dependent fields are interpreted. An implementation that stores identifiers from more than one profile must retain the decoder for each profile it stores.

## 5. Relationships and roles

Role is a per-identifier designation, not a relationship graph. If a human identity is associated with a phone identity, represent the two identities separately and maintain their association in application data. Do not encode the phone as part of the human identifier or infer ownership from Role alone.

Role is fixed for the allocated identifier but not for the entity. If the designation changes, retire the identifier and allocate a new one; do not rewrite the Role bit. The criteria for the designation change are external to the profile. Role is consumed by the application domain layer, not by the routing or allocation layers.

## 6. Routing integration

Routing uses Class + Engine. An implementation integrating with a resolver constructs the virtual-engine ID from the extracted Class and Engine, looks up the virtual-engine row, and resolves the physical engine address from it. A Class mismatch between the encoded Class and the authoritative record must be detected before the virtual-engine lookup; it is not a routing-stage condition to be discovered at the physical engine.

Physical engine placement may be rearranged administratively. The Class binding is fixed; a shift that would move an Engine to a different Class is a violation. Administrative operations are validated by the procedure in SPECIFICATION.md §16.2, distinct from identifier validation.

## 7. Security boundary

Treat the identifier as data, not a credential. Authenticate callers and authorize operations independently. If the application needs secrecy, integrity protection, or cryptographic proof, design those controls outside the identifier format. In v1.42 the Class field directly exposes the entity category; applications with confidentiality requirements should account for that.
