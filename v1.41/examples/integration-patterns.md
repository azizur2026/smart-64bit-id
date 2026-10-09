# SMART 64-Bit ID v1.41 — Integration Patterns

**Non-normative patterns.** These examples do not replace the normative specification.

## 1. Storage

An implementation may store records in Engine-local namespaces and use Local as a local key, while retaining the complete 64-bit SMART value as an external/current representation. It may instead store the complete identifier as a database key. SMART does not mandate a schema or database technology.

Whatever representation is selected, it must preserve the Engine + Local uniqueness coordinate and the v1.41 identity semantics. A Class change or Role change must not be implemented by rewriting an already allocated identity.

## 2. Allocation service

A typical allocation API delegates to an authoritative allocator for the selected Engine:

```text
request identity
    │
    ▼
select authorized Engine namespace
    │
    ▼
authoritative Local allocator
    │
    ├── safe allocation established ──► assemble/validate SMART ID
    │
    └── safety uncertain/exhausted ───► fail; do not reuse Local
```

A database sequence, transactional allocator, leased range, or another mechanism may be used only if it actually provides the required uniqueness, no-reuse, and stale-owner fencing guarantees under the implementation's failure model.

## 3. Engine migration

Migration to another Engine allocates a new Local at the receiving Engine and therefore creates a new SMART identity. Do not copy the old Local merely to preserve its numeric value. Keep an external migration/history record if the application needs to associate the source and destination identities.

## 4. Legacy boundary

A legacy-only v1.4 endpoint must validate according to v1.4 and explicitly reject an incompatible v1.41 identifier. It must not mask or rewrite the bits to make the value appear to be v1.4. A mixed deployment needs an explicit profile-aware boundary or routing decision before profile-dependent decoding.

## 5. Relationships and roles

Role is a per-identity designation, not a relationship graph. If a human identity is associated with a phone identity, represent the two identities separately and maintain their association in application data. Do not encode the phone as part of the human identifier or infer ownership from Role alone.

## 6. Security boundary

Treat the identifier as data, not a credential. Authenticate callers and authorize operations independently. If the application needs secrecy, integrity protection, or cryptographic proof, design those controls outside the identifier format.
