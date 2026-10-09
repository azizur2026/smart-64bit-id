# SMART 64-Bit ID v1.41 — Normative Rules Summary

This is a navigational summary, not a replacement for [SPECIFICATION.md](SPECIFICATION.md). Where details are needed for conformance, consult the normative specification.

## Encoding and profile selection

1. A v1.41 identifier is an unsigned 64-bit value with the bit positions specified in the normative document.
2. Bits 54–57 (Reserved) must be zero when generating a v1.41 identifier; a v1.41 decoder must reject nonzero Reserved bits as invalid v1.41.
3. Class `0000` must not appear in an allocated SMART identifier.
4. Local `0` is valid; it is not a null or unassigned sentinel.
5. Version/Revision must be interpreted before profile-dependent fields. Unknown profiles must not be guessed. A v1.x implementation must not interpret Version `1` as a v1.x identifier.
6. A legacy-only v1.4 boundary must explicitly reject an incompatible v1.41 identifier and must not rewrite, truncate, mask, downgrade, or pass it downstream as valid v1.4.

## Identity semantics

7. The 54-bit Identity Core is Class + Engine + Local and must remain stable for an allocated identity.
8. Role must remain stable for a given allocated identity. Creating, migrating, or changing a representation must preserve Role.
9. Class must remain stable for an allocated identity. Reclassification must not mutate the existing identifier.
10. The allocation uniqueness coordinate is Engine + Local; Class does not partition this namespace.

## Allocation safety

11. A Local ID successfully allocated in an Engine must never be successfully allocated again within that Engine.
12. No two successful allocations in the same Engine may return the same Local value.
13. At most one authoritative active allocator may successfully allocate in an Engine namespace at a time; a stale allocator must not commit after its authority ends.
14. If an implementation cannot establish safe uniqueness and non-reuse, allocation must fail.
15. When the Local namespace is exhausted, allocation must fail rather than reuse a previously allocated value.

## Routing and migration

16. Current normative routing uses Engine to select the namespace and Local for lookup within it.
17. Changing Engine creates a new SMART identity; the receiving Engine must allocate a new Local using its authoritative allocation mechanism.
18. Migration must not copy or manually assign the source Local outside the receiving allocator.
19. The old identity remains unchanged. Any old-to-new relationship is external lifecycle/relationship data.

## Serialization and conformance

20. Canonical binary serialization is unsigned 64-bit big-endian/network byte order.
21. Field extraction must use the defined bit positions and unsigned/logical-shift semantics.
22. An implementation that cannot satisfy applicable safety, uniqueness, non-reuse, validation, or interoperability requirements must not claim v1.41 conformance.

The normative specification remains the controlling source for exact requirements, scope, and interpretation.
