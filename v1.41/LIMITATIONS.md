# SMART 64-Bit ID — Limitations and Scope

**Technical Note v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document defines the known limitations, experimental boundaries, and non-guarantees of SMART 64-Bit ID v1.4.

The purpose is to ensure that technical claims made by the project remain proportional to the available evidence.

SMART ID v1.4 defines an identifier structure and associated allocation, routing, lifecycle, and failure semantics.

It does not guarantee a particular database performance result, storage reduction, deployment topology, cryptographic property, or operational architecture.

---

## 2. Benchmark Scope

The principal empirical benchmark reported by SMART ID v1.4 is a single-engine experiment.

The valid benchmark used:

* 1,000,000 rows;
* MariaDB 10.4.32;
* InnoDB;
* Linux;
* ASUS ZenBook UX363JA;
* local NVMe SSD storage;
* a single database instance;
* no competing workload;
* Engine = 0;
* Region = 0;
* State = 1;
* Version = 0;
* Local ID assigned from the row index.

The benchmark therefore represents a specific experimental environment.

It should not be interpreted as a universal characterization of SMART ID performance.

---

## 3. Performance Results Are Measurements, Not Guarantees

The measured results demonstrate behavior in the tested environment.

They do not establish that SMART ID will always be:

* faster than auto-increment;
* slower than auto-increment;
* smaller in every storage engine;
* smaller on every filesystem;
* faster under every workload; or
* equivalent under every deployment configuration.

Performance depends on implementation, hardware, database engine, workload, concurrency, configuration, indexing strategy, storage subsystem, cache state, and other environmental factors.

---

## 4. Single-Engine Load Results

The single-engine load benchmark produced approximately:

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |     16.68 s |  15.96 s |        -4% |
| 64 MB       |     18.52 s |  20.40 s |       +10% |
| 16 MB       |     13.70 s |  14.86 s |        +8% |

These results should be interpreted as approximate parity within the tested environment rather than as evidence of a universal performance advantage.

The variation between configurations demonstrates why a single benchmark configuration should not be used to make a general performance guarantee.

---

## 5. Point Lookup Results

For 10,000 point lookups, the measured differences were approximately:

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |     2.951 s |  2.990 s |      +1.3% |
| 64 MB       |     3.201 s |  3.107 s |      -2.9% |
| 16 MB       |     3.148 s |  3.194 s |      +1.5% |

The observed differences were within approximately ±3% in the tested configurations.

This supports a finding of measured parity in this experiment.

It does not establish that the same relationship will hold under different hardware, databases, query patterns, concurrency levels, or workloads.

---

## 6. Range Scan Results

For 1,000 range scans of 1,000 rows each, the measured differences were approximately:

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |    15.584 s | 15.515 s |      -0.4% |
| 64 MB       |    15.624 s | 15.658 s |      +0.2% |
| 16 MB       |    15.679 s | 15.970 s |      +1.9% |

The measured differences were within approximately ±2% in the tested configurations.

This should be reported as measured parity in the experiment, not as a universal guarantee.

---

## 7. Clustered Index Size

The tested clustered-index measurements showed SMART ID using approximately 33–53% less space than the traditional identifier in the three tested buffer-pool configurations.

The measured values were approximately:

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |    69.84 MB | 42.55 MB |       -39% |
| 64 MB       |    69.84 MB | 33.10 MB |       -53% |
| 16 MB       |    69.84 MB | 46.74 MB |       -33% |

The 33–53% figure applies only to these tested configurations and workload.

It must not be presented as a universal storage reduction guarantee.

The observed result is associated with the particular InnoDB clustered-index behavior and key distribution in this experiment.

Other database engines, storage engines, schemas, indexes, workloads, or key distributions may produce different results.

---

## 8. Physical Reads

The measured physical-read behavior did not produce a corresponding measurable latency shift in the tested benchmark.

At the larger buffer-pool configurations, physical reads were approximately zero.

At the 16 MB configuration, approximately 78,630 physical reads were observed.

This result should not be interpreted as proof that physical reads are irrelevant to database performance generally.

It is only an observation from the tested workload and environment.

---

## 9. Invalid Multi-Engine Experiment

An earlier experiment attempted to represent 16 engines using:

```text
row_index % 16
```

The experiment used:

* one writer process;
* one database connection;
* one insert loop; and
* simulated Engine values.

This experiment is **INVALID as evidence for a 16-engine distributed workload**.

It did not represent 16 independent engines with independent writers, ownership, counters, connections, or commit streams.

The results from this experiment must not be used to claim that SMART ID performs better or worse in a genuine multi-engine deployment.

The invalid experiment is retained only for research transparency.

See:

`research/FINDINGS_MULTI_ENGINE_INVALID.md`

---

## 10. Correct Multi-Engine Benchmark Methodology

A meaningful multi-engine experiment should model actual independent engines.

For example, a future 16-engine test should use:

* 16 concurrent writers;
* one authoritative Engine per writer;
* independent database connections;
* independent Local ID allocation state;
* independent commit streams;
* explicit Engine ownership;
* appropriate concurrency control;
* equivalent workloads across engines; and
* measurement of both aggregate and per-engine behavior.

The benchmark should also distinguish between:

* allocation throughput;
* transaction throughput;
* commit latency;
* routing latency;
* database lookup latency;
* index size;
* storage utilization; and
* contention.

Until such an experiment is performed, SMART ID v1.4 makes no multi-engine performance claim.

---

## 11. CPU Cycle Claims

SMART ID uses fixed-position bit extraction for routing.

The operation is constant with respect to the identifier width.

However, SMART ID does not claim a universal CPU cycle count for bit extraction.

Actual instruction count and CPU-cycle cost depend on:

* compiler;
* language;
* processor architecture;
* generated machine code;
* optimization level;
* runtime;
* branch behavior;
* surrounding code; and
* microarchitectural conditions.

Therefore, claims such as a universal number of CPU cycles for SMART routing should not be made.

---

## 12. Routing Performance

The SMART routing model is structurally simple:

```text
64-bit ID
   │
   ▼
Extract Engine
   │
   ▼
Route to Engine
   │
   ▼
Extract Local ID
   │
   ▼
Primary-key lookup
```

The fixed-position extraction itself is expected to be inexpensive.

However, total request latency is dominated by the complete system path in real deployments.

Network latency, queueing, service processing, database access, cache behavior, and storage latency may all exceed the cost of extracting the Engine and Local ID fields.

SMART ID therefore does not claim a universal end-to-end latency improvement.

---

## 13. Storage Benefits Are Not Universal

The measured clustered-index reduction is an empirical observation.

It should not be generalized to:

* PostgreSQL;
* MySQL variants;
* other relational databases;
* NoSQL databases;
* distributed databases;
* alternative storage engines;
* alternative indexing structures; or
* arbitrary workloads.

Each deployment should measure its own storage behavior.

---

## 14. Database Vendor Independence

SMART ID does not require a particular database vendor.

The v1.4 benchmark used MariaDB and InnoDB because that was the selected experimental environment.

Using MariaDB/InnoDB in the benchmark does not make those technologies a requirement of SMART ID.

The identifier specification is independent of the benchmark database implementation.

---

## 15. Control-Plane Architecture

SMART ID does not mandate a particular control-plane architecture.

The client or deployment owner is responsible for ensuring authoritative Engine allocation and non-conflicting ownership.

Possible implementations may use centralized allocation, leases, fencing, distributed coordination, or other appropriate mechanisms.

The specification does not require one particular architecture.

---

## 16. Engine Ownership

At any time, an Engine ID must have at most one authoritative active allocator.

Stale or concurrent ownership of the same Engine ID must not be permitted to generate identifiers.

The implementation must prevent situations in which two authorities believe they can independently allocate Local IDs within the same Engine namespace.

This requirement is a correctness invariant, not a performance optimization.

---

## 17. Fencing and Failure Recovery

Implementations may use leases, fencing tokens, coordination services, or equivalent mechanisms to prevent stale allocators from continuing to generate identifiers.

SMART ID does not prescribe a particular fencing technology.

If ownership cannot be established unambiguously, identifier generation should fail rather than risk duplicate allocation.

---

## 18. Local ID Exhaustion

Each Engine has a finite 29-bit Local ID namespace:

**536,870,912 identifiers per Engine.**

When the namespace is exhausted, the implementation must not wrap around or reuse previous Local IDs.

Exhaustion is a hard failure condition for that Engine.

The client or control plane is responsible for the operational response, such as provisioning another Engine.

SMART ID does not prescribe how that operational response is implemented.

---

## 19. Randomized Local ID Start

An implementation may choose a randomized non-zero starting Local ID.

However, doing so consumes part of the finite Local ID namespace.

Randomization therefore does not increase the total number of identifiers available within an Engine.

Implementations should account for the consumed namespace when estimating capacity.

---

## 20. Crash Recovery and Gaps

SMART ID prioritizes uniqueness and non-reuse over gapless allocation.

If identifiers are allocated or reserved and a process fails before all reserved identifiers are committed, gaps may occur.

Such gaps are acceptable.

The implementation must not reuse previously allocated identifiers merely to eliminate gaps.

Crash recovery must preserve the invariant that an allocated Local ID is never silently returned to the available pool.

---

## 21. Batch Allocation

Batch allocation may improve operational efficiency.

However, an implementation should clearly distinguish between:

* reservation order;
* allocation order;
* commit order; and
* external observation order.

These orders do not necessarily have to be identical.

SMART ID does not require globally gapless or globally commit-ordered identifiers.

---

## 22. Region Is Not Routing

The Region field is metadata.

It is not part of the identity core and must not be treated as a required routing key.

Region may be remapped for presentation or governance purposes according to deployment requirements.

Historical generation-time meaning may still be preserved where required by the implementation.

---

## 23. State Is Not Routing

State is a lifecycle marker.

It is not a routing field.

State should be evaluated as an index-level lifecycle filter rather than as part of the routing path.

A retired identifier remains permanently retired.

If a new identifier is required after transfer or re-identification, the implementation creates a new SMART ID and retires the old one.

---

## 24. Versioning Limitation

Version 0 represents the v1.x generation of the SMART ID format.

Version 1 is reserved for a future v2 format.

Implementations must not interpret Version 1 as an active v2 specification unless such a specification is formally released.

---

## 25. FPE Performance Is a Separate Concern

SMART ID bit extraction and routing performance must not be confused with format-preserving encryption performance.

A benchmark measuring Engine extraction does not measure:

* encryption;
* decryption;
* key management;
* cryptographic library performance;
* public-ID transformation;
* cryptographic verification; or
* application security overhead.

If FPE is used, it should be benchmarked separately.

---

## 26. Cryptographic Certification

SMART ID v1.4 does not constitute a cryptographic certification.

The project does not claim that SMART ID itself is certified under a particular cryptographic standard or certification scheme.

Certification depends on the exact implementation, algorithms, libraries, configuration, deployment, testing, authority, and jurisdiction.

---

## 27. Security Boundary

SMART ID is not an authentication system.

SMART ID is not an authorization system.

SMART ID does not automatically provide confidentiality or integrity.

Implementations remain responsible for:

* authentication;
* authorization;
* access control;
* key management;
* secure transport;
* integrity protection;
* logging;
* monitoring; and
* incident response.

---

## 28. Public Identifier Boundary

A public identifier may use a separate representation layer, including FPE where appropriate.

That representation does not change the underlying SMART ID semantics.

FPE is not authentication, authorization, or a substitute for application security.

---

## 29. Numeric Serialization

A 64-bit SMART ID should be serialized as a string in JSON and similar interfaces when the target runtime cannot safely represent the full 64-bit integer range.

Implementations should not assume that all application runtimes provide exact native numeric representation for arbitrary 64-bit integers.

This is particularly relevant to environments using floating-point number representations for general-purpose numeric values.

---

## 30. Implementation and Deployment Variability

Actual SMART ID behavior depends on the implementation.

Important variables include:

* programming language;
* compiler;
* runtime;
* processor;
* database;
* storage engine;
* filesystem;
* network;
* concurrency model;
* allocator architecture;
* transaction configuration;
* cache configuration; and
* deployment topology.

The specification defines required semantics, but it cannot guarantee identical implementation behavior across all environments.

---

## 31. No Universal Storage Claim

The project must not state that SMART ID always produces smaller indexes or lower storage consumption.

The supported claim is narrower:

> In the tested MariaDB/InnoDB single-engine configurations, SMART ID produced a 33–53% smaller clustered index than the comparison identifier.

This is an empirical result, not a universal property.

---

## 32. No Universal Performance Claim

The project must not state that SMART ID universally outperforms auto-increment or another identifier strategy.

The supported v1.4 conclusion is:

> In the tested single-engine environment, measured load, point-lookup, and range-scan latency showed approximate parity with the comparison identifier.

Different workloads may produce different results.

---

## 33. Reproducibility

Future benchmark reports should document enough information to distinguish:

* hardware;
* operating system;
* database version;
* database configuration;
* schema;
* indexes;
* dataset size;
* workload;
* concurrency;
* cache conditions;
* measurement method; and
* statistical treatment.

Benchmark results without sufficient experimental context should not be presented as directly comparable.

---

## 34. Scope of the v1.4 Evidence

The strongest empirical evidence in v1.4 concerns:

* single-engine generation;
* single-engine database behavior;
* point lookup behavior;
* range scan behavior; and
* clustered-index size in the tested MariaDB/InnoDB environment.

Evidence for other environments remains to be established.

---

## 35. Future Research

Useful future research includes:

* genuine concurrent multi-engine testing;
* larger datasets;
* multiple database engines;
* multiple storage engines;
* distributed deployments;
* high-concurrency allocation;
* allocator failure testing;
* fencing and stale-owner testing;
* long-duration exhaustion testing;
* public-ID/FPE overhead measurement;
* replication behavior;
* backup and recovery behavior; and
* cross-platform implementation testing.

These areas are outside the evidence base of the current v1.4 benchmark.

---

## 36. Summary

SMART ID v1.4 makes deliberately bounded technical claims.

The identifier structure and semantic rules are normative.

The benchmark results are empirical observations from a defined environment.

The measured clustered-index reduction is specific to the tested MariaDB/InnoDB configurations and workload.

The multi-engine experiment documented as invalid is not evidence of distributed performance.

No universal CPU-cycle, storage, or latency claim is made.

FPE performance is separate from SMART ID bit extraction.

Cryptographic certification is not claimed.

Control-plane architecture, database vendor, deployment topology, and security architecture remain implementation choices subject to the requirements defined by the specification.

The central principle is:

**SMART ID defines the identifier semantics and correctness requirements; implementations remain responsible for validating performance, security, and operational behavior in their actual deployment environments.**
