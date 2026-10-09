# SMART 64-Bit ID v1.41 — Limitations and Non-Guarantees

This note clarifies boundaries of the format. It does not amend [SPECIFICATION.md](SPECIFICATION.md).

## 1. No time-ordering guarantee

The v1.41 layout contains no timestamp field. Numeric order therefore does not represent generation-time order. The format does not promise time-sortability or encode creation time. Applications needing temporal metadata must maintain it separately.

## 2. Uniqueness depends on correct namespace governance

The uniqueness coordinate is Engine + Local. The bit layout alone cannot prevent two independent authorities from assigning the same Engine/Local pair. Implementations need authoritative Engine assignment and crash-safe, non-reusing Local allocation. v1.41 states allocator safety outcomes but does not mandate a particular consensus, database, lease, fencing, or recovery mechanism.

Global Engine-number registration, permanent Engine-number non-reuse after retirement, and a permanent Engine-to-Class binding policy are deferred governance topics, not additional rules silently introduced by this package.

## 3. Class is not a universal ontology

Class is a four-bit code defined by SMART. It does not prove an entity's legal status, ownership, biological nature, authority, or external classification. Class does not partition the Engine + Local allocation namespace.

## 4. Routing scope

The current normative routing selector is Engine; Local is looked up within the Engine namespace. v1.41 does not require `Class + Engine` as a composite routing key. That possible future higher-level shard key is deferred.

## 5. Role is not a relationship graph

Role is an immutable per-identity designation. It does not encode ownership, a parent/child graph, legal agency, or the identity of an associated device/person. Those relationships require external records.

## 6. No authentication, secrecy, or authorization

A SMART ID is not a credential and does not authenticate its presenter. The format does not provide encryption, signatures, access control, or proof of ownership.

## 7. No universal performance claim

The identifier layout alone does not guarantee faster queries, smaller indexes in every database, lower CPU cost, or superior throughput compared with UUIDs, Snowflake-like IDs, or other schemes. Results depend on schema, workload, database engine, indexing, hardware, caching, concurrency, and allocation design. The archived benchmark material in `research/v1.4/` is version-scoped and must not be presented as proof of v1.41 performance.

## 8. Infrastructure remains implementation-specific

SMART does not define a complete distributed database, Engine registry, allocator deployment, migration protocol, retry policy, or resolution service for retired/unavailable Engines. Implementations must design those systems while preserving the normative identifier requirements.
