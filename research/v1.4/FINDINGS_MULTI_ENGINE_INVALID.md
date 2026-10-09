# SMART 64-Bit ID — Invalid Multi-Engine Experiment

**Research Note — INVALID EXPERIMENT**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

# IMPORTANT: INVALID AS MULTI-ENGINE EVIDENCE

**This experiment must NOT be used as evidence of SMART ID performance in a genuine 16-engine distributed workload.**

The experiment was retained for research transparency because it was performed during development and produced measurable results.

However, its methodology did not represent 16 independent engines.

Therefore, the numerical results below are historical experimental observations only.

They do not support a conclusion that SMART ID is faster, slower, larger, or smaller than the comparison identifier in a real multi-engine deployment.

---

## 1. Purpose

This document records an earlier experiment that attempted to simulate a multi-engine workload.

The experiment is documented so that the project maintains an honest research record and does not silently discard an invalid result.

The correct interpretation is that the experiment was insufficiently representative of distributed multi-engine operation.

---

## 2. Intended Experiment

The original intention was to investigate behavior with:

**16 simulated Engines**

The experiment attempted to distribute identifiers across Engine values using:

```text id="0fl8im"
Engine = row_index % 16
```

This produced multiple Engine values in the generated data.

However, producing multiple Engine values in the identifier does not by itself create a multi-engine workload.

---

## 3. Actual Experimental Architecture

The actual experiment used:

* one writer process;
* one database connection;
* one insert loop;
* one active execution stream;
* simulated Engine values;
* Local IDs derived from the row index.

The experiment therefore did not contain:

* 16 independent writers;
* 16 independent connections;
* 16 independent Local ID counters;
* 16 independent commit streams;
* 16 independently authoritative Engine allocators;
* realistic Engine ownership;
* allocator fencing;
* concurrent Engine activity.

This distinction is fundamental.

---

## 4. Why the Experiment Is Invalid

A genuine multi-engine deployment requires independent Engine namespaces to operate through independent authoritative allocation domains.

The original experiment instead used one sequential writer that changed the Engine value as rows were generated.

Conceptually:

```text
INVALID EXPERIMENT

One writer
    │
    ├── Engine 0
    ├── Engine 1
    ├── Engine 2
    ├── ...
    └── Engine 15
```

This is not equivalent to:

```text
GENUINE MULTI-ENGINE MODEL

Writer 0  ── Engine 0
Writer 1  ── Engine 1
Writer 2  ── Engine 2
...
Writer 15 ── Engine 15
```

The second model introduces concurrency, independent ownership, independent counters, and independent commit behavior that were absent from the original experiment.

---

## 5. Historical Results

The original experiment reported approximately:

| Measurement                | Traditional | SMART ID |          Difference |
| -------------------------- | ----------: | -------: | ------------------: |
| Insert/load time           |    205.40 s | 278.08 s |                +35% |
| Clustered index            |    652.2 MB | 707.8 MB |               +8.5% |
| Secondary-index build      |     43.59 s |  29.71 s |                -32% |
| Secondary-index final size |      433 MB |   433 MB | approximately equal |

These numbers are retained for historical transparency.

They must not be used as multi-engine performance evidence.

---

## 6. What the Results Cannot Establish

The historical results cannot establish that SMART ID:

* is 35% slower in a 16-engine system;
* produces an 8.5% larger clustered index in a 16-engine system;
* produces a 32% faster secondary-index build in a 16-engine system;
* produces equal secondary-index size in all multi-engine deployments;
* scales poorly across Engines;
* scales well across Engines; or
* has any particular distributed-performance characteristic.

None of those conclusions is justified by the experimental architecture.

---

## 7. Main Methodological Problem

The fundamental problem was the difference between **Engine simulation** and **Engine concurrency**.

Changing an Engine field in one sequential insert stream does not reproduce the behavior of multiple independently operating Engines.

A multi-engine system has additional dimensions:

* concurrent writes;
* allocator ownership;
* independent counters;
* transaction interleaving;
* commit ordering;
* lock contention;
* scheduling;
* network behavior;
* connection management;
* failure domains; and
* coordination mechanisms.

The original experiment did not measure these factors.

---

## 8. Engine Ownership Was Not Tested

The experiment did not test the SMART ID ownership invariant.

The required invariant is:

> **At any time, an Engine ID MUST have at most one authoritative active allocator.**

The historical experiment did not have multiple authorities attempting to own Engines.

Therefore it provided no evidence about:

* ownership conflicts;
* stale allocators;
* fencing;
* leases;
* split-brain prevention;
* allocator recovery; or
* duplicate Engine ownership.

---

## 9. Local ID Allocation Was Not Independently Modeled

A real multi-engine implementation should maintain Local ID allocation independently within each Engine namespace.

The original experiment derived Engine and Local values from a single row-index sequence.

This does not reproduce independent persistent counters.

Therefore it cannot validate:

* Local ID persistence;
* independent Engine counters;
* concurrent allocation;
* crash recovery;
* batch reservation;
* allocator restart behavior; or
* exhaustion handling.

---

## 10. Transaction and Commit Behavior

A real multi-engine workload may produce many overlapping transactions and commit streams.

The original experiment had one writer and one execution stream.

Consequently, it did not measure:

* transaction interleaving;
* commit contention;
* concurrent index modification;
* connection-level contention;
* scheduler effects; or
* distributed commit behavior.

---

## 11. Secondary Index Result

The historical secondary-index measurements are also insufficient to establish a general multi-engine property.

The observed values were:

```text id="j4drn4"
Traditional build: 43.59 s
SMART ID build:    29.71 s
Difference:        -32%
```

and:

```text id="b9gq0q"
Traditional final size: 433 MB
SMART ID final size:   433 MB
```

These results may be retained as historical observations.

They must not be promoted to general multi-engine conclusions.

---

## 12. Correct Multi-Engine Benchmark

A valid 16-Engine experiment should use a structure closer to:

```text
Engine 0  ←→ Writer 0  ←→ Connection 0
Engine 1  ←→ Writer 1  ←→ Connection 1
Engine 2  ←→ Writer 2  ←→ Connection 2
...
Engine 15 ←→ Writer 15 ←→ Connection 15
```

Each Engine should have:

* one authoritative allocator;
* its own Local ID allocation state;
* an independent connection where appropriate;
* independent transaction activity;
* independent commit behavior;
* explicit ownership;
* appropriate fencing or equivalent stale-owner protection.

The comparison system should receive an equivalent workload.

---

## 13. Required Measurements for Future Testing

A future multi-engine benchmark should measure at least:

### Throughput

* total inserts per second;
* per-engine inserts per second;
* transaction throughput.

### Latency

* allocation latency;
* insert latency;
* commit latency;
* point-lookup latency;
* range-scan latency.

### Storage

* clustered-index size;
* secondary-index size;
* total database size;
* page utilization where measurable.

### Concurrency

* active writers;
* concurrent transactions;
* lock waits;
* contention;
* connection utilization.

### Reliability

* allocator restart;
* Engine ownership loss;
* stale allocator behavior;
* fencing behavior;
* crash recovery;
* duplicate-generation detection.

---

## 14. Future Test Matrix

A useful future test matrix could include:

| Engines | Writers | Connections | Dataset | Purpose                 |
| ------: | ------: | ----------: | ------: | ----------------------- |
|       1 |       1 |           1 |      1M | Baseline                |
|       2 |       2 |           2 |      2M | Low concurrency         |
|       4 |       4 |           4 |      4M | Moderate concurrency    |
|       8 |       8 |           8 |      8M | Higher concurrency      |
|      16 |      16 |          16 |    16M+ | Multi-engine validation |

The exact dataset size and workload should be selected according to available hardware and the intended research question.

The important property is that each Engine represents an independent authoritative allocation domain.

---

## 15. Fencing Test

A future experiment should also test stale ownership.

For example:

```text
Allocator A owns Engine 7
        │
        ▼
Allocator A becomes unavailable
        │
        ▼
Ownership is reassigned to Allocator B
        │
        ▼
Allocator A attempts to continue
```

The required behavior is that stale ownership cannot continue generating identifiers.

If ownership cannot be established unambiguously, generation should fail.

The specific fencing technology remains an implementation choice.

---

## 16. Crash-Recovery Test

A future benchmark should test allocator interruption during:

* normal allocation;
* batch reservation;
* transaction processing;
* commit;
* restart;
* ownership transition.

The test should verify that previously allocated Local IDs are never reused.

Gaps are acceptable.

Duplicate identity is not.

---

## 17. What Would Constitute Valid Evidence

A future multi-engine result becomes useful evidence only when the experiment reproduces the relevant characteristics of the deployment being studied.

At minimum, the experiment should model:

1. independent Engine ownership;
2. independent Local ID allocation;
3. concurrent writers;
4. independent connections or equivalent concurrency;
5. transaction interleaving;
6. realistic commit behavior;
7. equivalent comparison workload; and
8. documented hardware and database configuration.

The larger the deployment claim, the more important these factors become.

---

## 18. Relationship to the v1.4 Evidence Base

The invalid experiment does not weaken the validity of the separate single-engine experiment.

The two experiments should be treated independently.

The valid single-engine results remain documented in:

`research/FINDINGS_SINGLE_ENGINE.md`

The present document records only the invalid multi-engine experiment and the methodological reason it cannot be used as distributed evidence.

---

## 19. Research Integrity

The project deliberately retains this invalid experiment instead of presenting only favorable results.

This provides a transparent record of:

* what was tested;
* what was measured;
* what methodology was used;
* what was wrong with the methodology; and
* what must be changed for future testing.

Research results should be evaluated according to their methodology, not only according to whether they appear favorable or unfavorable to the project.

---

## 20. Conclusion

The historical experiment produced measurable differences, but its architecture did not represent a genuine 16-engine deployment.

Therefore:

**The experiment is INVALID as evidence of multi-engine distributed performance.**

It should not be used to claim that SMART ID is faster, slower, larger, smaller, or more scalable than another identifier strategy in a real multi-engine system.

A valid future experiment requires independent Engines, independent authoritative allocators, concurrent writers, independent allocation state, realistic transaction behavior, and equivalent workloads.

Until such testing is completed, SMART ID v1.4 makes **no multi-engine performance claim**.
