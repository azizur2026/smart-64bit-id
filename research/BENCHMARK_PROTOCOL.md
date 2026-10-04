# SMART 64-Bit ID — Benchmark Protocol

**Research Protocol v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document defines the recommended methodology for benchmarking SMART 64-Bit ID implementations.

The purpose is to make future performance claims reproducible, comparable, and appropriately bounded.

A benchmark result is valid only within the experimental conditions under which it was obtained.

Benchmark results must not be presented as universal guarantees unless independently established across sufficiently broad environments.

---

## 2. Core Principle

A benchmark must measure the behavior it claims to measure.

For example:

* a database benchmark is not automatically a routing benchmark;
* a routing benchmark is not automatically an FPE benchmark;
* a single-engine benchmark is not automatically a multi-engine benchmark;
* a storage measurement is not automatically a throughput measurement.

The benchmark report should explicitly identify its measurement boundary.

---

## 3. Required Environment Information

Every published benchmark should identify, where applicable:

### Hardware

* CPU model;
* CPU architecture;
* available memory;
* storage device;
* storage interface;
* number of CPU cores;
* relevant CPU frequency behavior.

### Operating System

* operating system;
* distribution;
* kernel version;
* architecture.

### Database

* database vendor;
* database version;
* storage engine;
* configuration;
* buffer-pool configuration;
* transaction settings;
* relevant durability settings.

### Application

* programming language;
* compiler;
* compiler version;
* runtime version;
* build configuration;
* relevant optimization settings.

### Workload

* dataset size;
* record size;
* identifier strategy;
* number of operations;
* operation distribution;
* concurrency;
* transaction size;
* batch size;
* warm-up behavior.

---

## 4. Comparison Fairness

When comparing SMART ID with another identifier strategy, the comparison should use equivalent conditions.

The following should remain equivalent where the experiment permits:

* hardware;
* operating system;
* database;
* schema;
* non-primary indexes;
* dataset;
* workload;
* transaction settings;
* durability settings;
* cache configuration;
* concurrency;
* test duration;
* measurement method.

Only the identifier strategy and intentionally studied dependent variables should differ.

---

## 5. Baseline Identifier

A benchmark should clearly define the comparison identifier.

For the v1.4 empirical work, the comparison was a traditional auto-increment identifier.

The exact schema and generation mechanism should be documented in the benchmark report.

A future benchmark may compare other strategies, but each comparison must explicitly identify the baseline.

---

## 6. Dataset Size

The dataset size must be reported explicitly.

At minimum, report:

* initial row count;
* rows inserted;
* final row count;
* total identifier count;
* Engine count where applicable.

For example:

```text id="2e6w4r"
Initial rows: 0
Inserted rows: 1,000,000
Final rows: 1,000,000
Engines: 1
```

For larger experiments, the same information should be provided.

---

## 7. Schema Control

The compared systems should use equivalent table schemas.

The following should remain equivalent unless deliberately tested:

* column definitions;
* column ordering;
* secondary indexes;
* constraints;
* storage engine;
* table options;
* character sets;
* collations.

The primary-key definition may necessarily differ because the identifier strategy is the variable under investigation.

---

## 8. Identifier Configuration

The SMART ID benchmark should document:

* Engine allocation;
* Local ID allocation;
* Region;
* State;
* Version;
* starting Local ID;
* allocation batch size;
* persistence mechanism;
* concurrency mechanism.

If randomized Local ID initialization is used, the starting value and resulting namespace consumption should be reported.

---

## 9. Single-Engine Baseline

The single-engine benchmark should establish a reproducible baseline before testing multi-engine behavior.

Recommended baseline:

* one authoritative Engine;
* one writer;
* one allocation stream;
* one database connection where appropriate;
* fixed Engine value;
* persistent Local ID allocation;
* controlled workload.

The existing v1.4 single-engine benchmark used:

```text id="3c0r4n"
N = 1,000,000

Engine = 0
Region = 0
State = 1
Version = 0
Local ID = row index
```

---

## 10. Single-Engine Load Test

The load test should measure insertion behavior under equivalent conditions.

Report:

* total rows;
* total elapsed time;
* rows per second;
* transaction count;
* batch size;
* commit behavior;
* CPU utilization where available;
* storage utilization where available.

A single elapsed time should not be treated as statistically definitive.

Repeated runs are preferred.

---

## 11. Point Lookup Test

Point lookups should use a defined set of identifiers.

Report:

* number of lookups;
* identifier selection method;
* random or sequential access;
* cache state;
* total elapsed time;
* average latency;
* median latency;
* relevant percentiles where available.

The same lookup set should be used for both identifier strategies.

---

## 12. Range Scan Test

Range tests should define:

* number of scans;
* rows per scan;
* range width;
* selection method;
* ordering;
* cache conditions;
* total elapsed time.

For the existing v1.4 experiment:

```text id="s6g8jx"
1,000 scans
×
1,000 rows per scan
```

The exact test should be preserved when attempting to reproduce the original result.

---

## 13. Index Size Measurement

Index-size measurements should identify:

* clustered index;
* secondary indexes;
* total table size;
* database size;
* measurement method;
* measurement time.

The benchmark should distinguish logical index size from physical filesystem usage where possible.

---

## 14. Physical I/O Measurement

If physical I/O is reported, document:

* measurement source;
* measurement interval;
* read count;
* write count;
* cache state;
* buffer-pool configuration.

A physical-read count should not automatically be interpreted as a latency explanation.

The relationship must be demonstrated by the measurements.

---

## 15. Cache Conditions

Database cache state should be documented.

At minimum identify:

* buffer-pool size;
* whether the database was restarted;
* whether the operating-system cache was warm;
* whether the test was repeated;
* whether data was preloaded.

Cold-cache and warm-cache results should not be silently mixed.

---

## 16. Buffer-Pool Matrix

Where practical, benchmarks should test multiple buffer-pool configurations.

The v1.4 single-engine experiment used:

```text id="4r6v4f"
512 MB
64 MB
16 MB
```

Testing multiple configurations helps identify whether an observed result depends strongly on memory availability.

---

## 17. Durability Configuration

Database durability settings must be documented.

The v1.4 benchmark used:

```text id="u9f0p5"
innodb_flush_log_at_trx_commit = 2
innodb_doublewrite = OFF
```

These settings affect benchmark behavior and must not be omitted from published results.

A future benchmark should state whether the settings are intended to model production behavior.

---

## 18. Repetition

Performance benchmarks should use repeated runs where practical.

A suitable protocol may include:

1. environment preparation;
2. warm-up;
3. measurement run;
4. reset;
5. repeat;
6. aggregate results.

The exact number of repetitions should depend on workload duration and measurement variability.

---

## 19. Statistical Reporting

Published benchmark results should preferably report:

* mean;
* median;
* minimum;
* maximum;
* standard deviation;
* percentile latency where relevant.

For short benchmark runs, variability can be significant.

A single measurement should therefore be labeled as a single measurement.

---

## 20. Outlier Handling

Outliers should not be silently removed.

If measurements are excluded, the benchmark report should state:

* the exclusion rule;
* how many measurements were excluded;
* why they were excluded.

Prefer reporting the raw data or sufficient summary information to reproduce the statistical treatment.

---

## 21. Benchmark Warm-Up

Where runtimes, caches, or databases require warm-up, the benchmark should distinguish:

**warm-up phase**

from

**measurement phase**.

Warm-up operations should not be accidentally counted as measured workload unless that is explicitly the purpose of the benchmark.

---

## 22. CPU Microbenchmarks

If raw routing extraction is benchmarked, the benchmark should separately report:

* CPU model;
* architecture;
* compiler;
* language;
* optimization level;
* runtime;
* benchmark harness;
* iteration count;
* input representation;
* timing method.

The benchmark must also prevent compiler optimization from eliminating the measured operation.

---

## 23. No Universal CPU-Cycle Claim

A benchmark may report measured cycles on a particular processor.

It must not convert that result into a universal statement such as:

> SMART ID routing always takes N cycles.

CPU execution depends on hardware and implementation.

The correct scope is the exact benchmark environment.

---

## 24. Parsing vs Extraction

Routing benchmarks should distinguish:

```text id="j8o1j5"
Text / API input
      │
      ▼
Parsing
      │
      ▼
64-bit representation
      │
      ▼
Engine extraction
      │
      ▼
Routing
```

Parsing and field extraction are separate measurements.

If both are included, the benchmark should state that explicitly.

---

## 25. Routing vs Database Lookup

A routing benchmark should not silently include database lookup unless database lookup is part of the intended measurement.

At minimum distinguish:

1. field extraction;
2. routing decision;
3. destination lookup;
4. network transfer;
5. database lookup.

This allows performance bottlenecks to be identified accurately.

---

## 26. FPE Benchmark Boundary

If FPE is used for public identifiers, it must be benchmarked separately.

The benchmark should identify:

* algorithm;
* implementation;
* library;
* key configuration;
* input size;
* encryption time;
* decryption time;
* throughput;
* error handling.

FPE performance must not be combined with raw SMART ID bit-extraction performance without explicitly stating the combined workload.

---

## 27. Security Benchmark Boundary

Security mechanisms should be identified separately from identifier-routing measurements.

Do not attribute:

* authentication latency;
* authorization latency;
* TLS overhead;
* cryptographic overhead;
* key-management overhead;

to SMART ID field extraction.

These are separate system components.

---

## 28. Single-Engine vs Multi-Engine

A benchmark must explicitly state whether it is:

* single-engine;
* multi-engine;
* distributed;
* concurrent;
* sequential; or
* simulated.

A simulated Engine field does not automatically constitute a multi-engine workload.

---

## 29. Requirements for Genuine Multi-Engine Testing

A valid multi-engine benchmark should use independent Engine authorities.

For a 16-engine test, a suitable baseline is:

```text id="8x4r21"
Engine 0  ← Writer 0
Engine 1  ← Writer 1
Engine 2  ← Writer 2
...
Engine 15 ← Writer 15
```

Each writer should have independent:

* allocation state;
* connection or equivalent execution context;
* transaction stream;
* commit stream;
* Engine ownership.

---

## 30. Engine Ownership

The benchmark must model the SMART ID ownership invariant:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

A test that allows two independent allocators to generate for the same Engine is testing an invalid deployment state.

If ownership is ambiguous, generation should fail.

---

## 31. Fencing

Where the implementation uses fencing, the benchmark should test:

* owner acquisition;
* owner renewal;
* owner expiration;
* stale-owner behavior;
* owner replacement;
* stale writer rejection.

The benchmark should record whether a stale allocator can generate identifiers after losing ownership.

The expected correct behavior is failure rather than duplicate generation.

---

## 32. Concurrent Writers

A multi-engine benchmark should use genuinely concurrent writers.

For 16 Engines:

```text
16 Engines
16 authoritative writers
16 independent allocation streams
```

A single writer cycling through 16 Engine values does not reproduce this condition.

---

## 33. Local ID Allocation

Each Engine should maintain its own Local ID allocation state.

The benchmark should verify:

* monotonicity within each Engine;
* persistence across restart;
* absence of reuse;
* correct batch allocation;
* correct concurrent behavior.

The benchmark should also record any gaps.

Gaps are acceptable when caused by allocation or failure.

---

## 34. Crash Testing

A reliability benchmark should intentionally interrupt allocation processes.

Possible interruption points include:

* before allocation;
* during batch reservation;
* after reservation;
* before commit;
* during commit;
* after commit;
* during ownership transition.

The benchmark should verify that allocated identifiers are not reused.

---

## 35. Failure Semantics

If the implementation cannot establish safe Engine ownership, the correct result is generation failure.

The benchmark should record:

* failure detection time;
* recovery time;
* whether duplicate generation occurred;
* whether allocated IDs were reused;
* whether gaps occurred.

The benchmark must treat duplicate identity as a correctness failure even if throughput appears high.

---

## 36. Local ID Exhaustion Testing

A full 29-bit namespace contains:

**536,870,912 identifiers per Engine.**

A practical exhaustion test may use a reduced test namespace in a reference implementation, provided the reduced namespace preserves the same exhaustion semantics.

The test should verify:

1. identifiers are allocated until exhaustion;
2. no identifier is reused;
3. the next allocation fails;
4. the implementation does not wrap around;
5. operational recovery is handled outside the SMART ID format.

---

## 37. Randomized Starting Point

If randomized non-zero Local ID initialization is tested, record:

* randomization method;
* starting value;
* available namespace before allocation;
* resulting capacity.

The test should demonstrate that randomization does not increase total namespace capacity.

---

## 38. Batch Allocation Testing

Batch allocation tests should record:

* batch size;
* reservation time;
* commit time;
* abandoned reservations;
* gaps;
* restart behavior.

The benchmark should distinguish allocation order from commit order.

---

## 39. Replication

Where database replication is tested, document:

* replication technology;
* topology;
* synchronous/asynchronous mode;
* replication lag;
* failover behavior;
* identifier allocation behavior.

Replication should not be assumed to preserve the same performance characteristics as a standalone database.

---

## 40. Storage Benchmarking

Storage benchmarks should measure separately:

* clustered index;
* secondary indexes;
* table size;
* total database size;
* filesystem usage.

The same measurement method should be used for both comparison systems.

---

## 41. Storage Interpretation

If SMART ID produces a smaller index in a test, report the exact:

* database;
* storage engine;
* schema;
* workload;
* dataset;
* identifier distribution.

Do not generalize one storage result to all database systems.

---

## 42. Network Testing

Distributed benchmarks should document:

* network topology;
* latency;
* bandwidth;
* protocol;
* connection pooling;
* packet loss where relevant;
* service discovery.

Network conditions can dominate the total latency of a distributed request.

---

## 43. Scaling Tests

Scaling tests should increase workload and concurrency systematically.

Possible dimensions include:

* number of Engines;
* number of writers;
* dataset size;
* request rate;
* transaction size;
* database size.

Results should be reported per Engine and in aggregate.

---

## 44. Saturation Testing

A scaling experiment should identify when the system approaches saturation.

Relevant indicators include:

* CPU utilization;
* memory utilization;
* I/O utilization;
* lock waits;
* transaction latency;
* queue depth;
* network utilization.

A throughput increase at one point does not guarantee linear scaling at higher load.

---

## 45. Benchmark Isolation

Benchmark systems should avoid unrelated workload where possible.

If other workload exists, document:

* workload source;
* approximate resource consumption;
* timing;
* whether it affected both comparison systems equally.

The v1.4 single-engine benchmark used no competing workload.

---

## 46. Benchmark Order

Comparison order should be considered because cache and system state can change.

Where practical, alternate or randomize test order.

For example:

```text id="3hy7a9"
Run A
Run B
Run B
Run A
```

This can reduce the effect of one strategy consistently being tested first or second.

---

## 47. Database Reset

Between independent test cases, the benchmark should define how the database state is reset.

Possible methods include:

* recreate database;
* recreate table;
* restore snapshot;
* truncate;
* reload dataset.

The chosen method should be documented.

---

## 48. Data Generation

Benchmark data generation must be deterministic where practical.

Record:

* random seed;
* generation algorithm;
* value distribution;
* identifier allocation strategy.

Deterministic data makes repeated experiments easier to compare.

---

## 49. Measurement Tooling

The benchmark should identify measurement tools.

Examples include:

* database timing;
* application timers;
* operating-system counters;
* database status counters;
* filesystem measurements;
* CPU performance counters.

The same measurement method should be used for both comparison systems.

---

## 50. Benchmark Artifacts

A reproducible benchmark release should ideally contain:

```text id="8q7v1a"
benchmark protocol
schema
data-generation procedure
configuration
workload definition
measurement scripts
raw results
summary results
environment information
```

If scripts are not published, the report should explain what was executed.

---

## 51. Raw Results

Raw benchmark results should be retained where practical.

This may include:

* timestamps;
* elapsed times;
* row counts;
* operation counts;
* resource measurements;
* index sizes;
* physical reads.

Publishing raw results improves independent verification.

---

## 52. Rounding

Published values should retain enough precision to support verification.

Rounded percentages should not imply greater precision than the underlying measurements justify.

For example:

```text
2.951 s vs 2.990 s
```

may reasonably be summarized as approximately 1.3%.

The exact raw values should remain available where possible.

---

## 53. Percentage Calculation

Percentage differences should identify the baseline.

For example:

```text id="7m2v8j"
Difference (%) =
    (SMART - Traditional) / Traditional × 100
```

A negative value means SMART ID measured lower than the comparison value.

A positive value means SMART ID measured higher.

---

## 54. Benchmark Naming

Benchmark files should use names that identify:

* workload;
* engine count;
* dataset size;
* database;
* date or version where useful.

For example:

```text
single-engine-1m-mariadb-v1.4
multi-engine-16x-16m-future
```

---

## 55. Validity Classification

Every benchmark should be classified.

Recommended categories:

### VALID

Methodology represents the intended workload and the measurements support the stated claim.

### LIMITED

Methodology is valid for a narrower scope than the broader question.

### INVALID

Methodology does not represent the workload being claimed.

### INCONCLUSIVE

Measurements are insufficient to establish a reliable conclusion.

The existing 16-engine sequential-writer experiment is classified as:

**INVALID**

---

## 56. Claim Discipline

Benchmark conclusions should use language proportional to evidence.

Prefer:

> "In the tested environment..."

> "Measured..."

> "Observed..."

> "Within the tested configurations..."

Avoid:

> "Always..."

> "Guaranteed..."

> "Universally..."

> "Proven faster..."

unless the evidence genuinely supports such a statement.

---

## 57. Benchmark Limitations

Every benchmark report should include limitations.

At minimum consider:

* hardware;
* operating system;
* database;
* storage;
* dataset;
* workload;
* concurrency;
* cache;
* configuration;
* measurement precision;
* statistical sample size;
* missing deployment conditions.

The current v1.4 limitations are documented separately in:

`docs/LIMITATIONS.md`

---

## 58. Existing v1.4 Evidence

The valid single-engine evidence is documented in:

`research/FINDINGS_SINGLE_ENGINE.md`

The invalid multi-engine experiment is documented in:

`research/FINDINGS_MULTI_ENGINE_INVALID.md`

The routing-cycle discussion is documented in:

`research/CYCLE_COMPARISON.md`

These documents should be read together.

---

## 59. Recommended Future 16-Engine Test

A future 16-engine benchmark should use:

```text id="h2f6g1"
16 authoritative Engines
16 concurrent writers
16 independent allocation streams
16 independent Local ID states
16 equivalent database connections where appropriate
```

The test should measure:

* aggregate throughput;
* per-engine throughput;
* latency;
* clustered-index size;
* secondary-index size;
* contention;
* resource utilization;
* failure behavior;
* fencing;
* crash recovery.

---

## 60. Recommended Comparison Matrix

A future benchmark may use:

| Engines | Writers | Dataset | Primary Objective      |
| ------: | ------: | ------: | ---------------------- |
|       1 |       1 |      1M | Baseline               |
|       2 |       2 |      2M | Low concurrency        |
|       4 |       4 |      4M | Moderate concurrency   |
|       8 |       8 |      8M | Higher concurrency     |
|      16 |      16 |    16M+ | Distributed validation |

The exact workload may be adjusted to available resources.

Any adjustment must be documented.

---

## 61. Success Criteria

A benchmark should define success criteria before measurement.

For example:

* uniqueness preserved;
* no Local ID reuse;
* no Engine ownership conflict;
* no unexpected wraparound;
* acceptable throughput;
* acceptable latency;
* reproducible results.

Performance should not be considered successful if identity correctness fails.

---

## 62. Correctness Before Performance

The benchmark hierarchy is:

```text id="y8tqf3"
Identity correctness
       │
       ▼
Failure correctness
       │
       ▼
Reproducibility
       │
       ▼
Performance measurement
```

A system that produces duplicate identifiers cannot be considered successful merely because it has high throughput.

---

## 63. Production-Representativeness

A benchmark should state whether it is:

* laboratory;
* development;
* staging;
* production-derived; or
* production-like.

The v1.4 single-engine experiment is a controlled laboratory-style benchmark.

It should not be presented as production telemetry.

---

## 64. Hardware Scaling

A result obtained on one laptop or server should not automatically be extrapolated to larger infrastructure.

Different CPUs, memory sizes, storage devices, and network architectures can materially change results.

Hardware-specific measurements should remain hardware-specific.

---

## 65. Database Scaling

Results from MariaDB/InnoDB should not automatically be extrapolated to other database engines.

A separate benchmark is required for each database environment whose performance characteristics are materially relevant.

---

## 66. Workload Scaling

A 1-million-row benchmark does not automatically establish behavior at:

* 10 million rows;
* 100 million rows;
* 1 billion rows; or
* larger scales.

Larger workloads should be measured directly.

---

## 67. Long-Duration Testing

Long-duration tests may expose behavior not visible in short benchmarks.

Future tests may examine:

* allocator stability;
* memory growth;
* transaction accumulation;
* index growth;
* checkpoint behavior;
* recovery;
* key rotation where relevant;
* ownership renewal.

Short tests should not be interpreted as long-term reliability evidence.

---

## 68. Failure Injection

Where reliability is relevant, future benchmarks should intentionally test:

* process termination;
* database restart;
* network interruption;
* allocator loss;
* ownership expiration;
* storage interruption where safe;
* service restart.

Failure injection should be performed in controlled environments.

---

## 69. Data Integrity Checks

After each benchmark, verify:

* row count;
* uniqueness;
* duplicate identifiers;
* missing identifiers where expected;
* Engine distribution;
* Local ID ordering where applicable;
* State values;
* Version values.

A benchmark result should not be accepted without validating the resulting dataset.

---

## 70. Identifier Validation

SMART IDs should be validated according to the v1.4 specification.

Validation should include, where applicable:

* 64-bit structure;
* Engine range;
* Local ID range;
* Version;
* Reserved bits;
* lifecycle state;
* uniqueness.

---

## 71. Security Considerations

Benchmarks involving public identifiers or FPE should not expose real secrets.

Use:

* test keys;
* synthetic data;
* isolated environments.

Do not commit private keys, credentials, production identifiers, or sensitive data to benchmark repositories.

---

## 72. Reporting Negative Results

Negative or unfavorable benchmark results should be retained where methodology is valid.

A technically credible research record should not selectively publish only favorable measurements.

Invalid experiments should also be documented when they materially affected project conclusions, with their invalidity clearly stated.

---

## 73. Reproduction by Independent Researchers

A benchmark is more useful when an independent researcher can reconstruct:

* environment;
* schema;
* data;
* workload;
* configuration;
* measurement process.

The project should prefer reproducibility over unsupported headline numbers.

---

## 74. Benchmark Versioning

Benchmark protocols should be versioned.

If the workload, schema, measurement method, or environment requirements materially change, create a new protocol version.

Historical results should remain associated with the protocol under which they were produced.

---

## 75. Protocol vs Specification

This benchmark protocol does not modify the SMART ID technical specification.

The protocol describes how to evaluate implementations.

Changes to the benchmark protocol do not automatically change the SMART ID identifier format.

---

## 76. Final Protocol Rule

The final rule for SMART ID benchmarking is:

> **Measure the system that is actually being claimed.**

A single-engine result must remain a single-engine result.

A simulated multi-engine workload must not be presented as a genuine distributed benchmark.

A routing microbenchmark must not be presented as database performance.

An FPE benchmark must not be presented as SMART ID bit-extraction performance.

A laboratory result must not be presented as universal production behavior.

---

## 77. Conclusion

SMART ID v1.4 uses empirical evidence conservatively.

The valid single-engine benchmark provides a reproducible baseline.

The invalid multi-engine experiment is retained as a methodological lesson rather than performance evidence.

Future multi-engine research should use independent authoritative Engines, concurrent writers, independent allocation state, realistic transaction behavior, and equivalent comparison workloads.

All future performance claims should identify their environment, methodology, measurement boundary, and limitations.

The governing principle is:

**Correctness first. Reproducibility second. Performance claims third.**
