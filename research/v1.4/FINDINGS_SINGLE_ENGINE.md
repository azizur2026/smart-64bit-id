# SMART 64-Bit ID — Single-Engine Empirical Findings

**Research Note v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document records the valid single-engine empirical findings used to support the technical discussion in SMART 64-Bit ID v1.4.

The measurements compare a SMART ID primary-key representation against a traditional auto-increment identifier under the same experimental environment.

The results are empirical observations and are not universal performance guarantees.

---

## 2. Experimental Environment

The benchmark was performed using:

* MariaDB 10.4.32
* InnoDB
* Linux
* ASUS ZenBook UX363JA
* local NVMe SSD
* one database instance
* one active benchmark workload
* no competing workload

Dataset size:

**N = 1,000,000 rows**

SMART ID configuration:

* Engine = 0
* Region = 0
* State = 1
* Version = 0
* Local ID = row index

The experiment was intentionally limited to a single Engine.

---

## 3. Database Configuration

The tested buffer-pool configurations were:

* 512 MB
* 64 MB
* 16 MB

The benchmark used:

```text
innodb_flush_log_at_trx_commit = 2
innodb_doublewrite = OFF
```

The selected buffer-pool size was changed between test runs.

The experiment was conducted on a local system without competing workload.

---

## 4. Load Test

The first measurement compared bulk insertion/load behavior.

### Results

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |     16.68 s |  15.96 s |        -4% |
| 64 MB       |     18.52 s |  20.40 s |       +10% |
| 16 MB       |     13.70 s |  14.86 s |        +8% |

### Interpretation

The results do not demonstrate a consistent performance advantage.

SMART ID was approximately 4% faster in the 512 MB configuration and slower in the 64 MB and 16 MB configurations.

The appropriate conclusion is **measured parity/noise within this experiment**, rather than a universal performance advantage.

---

## 5. Point Lookup Test

The point-lookup workload used 10,000 lookups.

### Results

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |     2.951 s |  2.990 s |      +1.3% |
| 64 MB       |     3.201 s |  3.107 s |      -2.9% |
| 16 MB       |     3.148 s |  3.194 s |      +1.5% |

### Interpretation

The measured difference remained within approximately ±3%.

This supports a conclusion of approximate parity in the tested environment.

The result should not be generalized to different database engines, hardware, workloads, or concurrency models.

---

## 6. Range Scan Test

The range-scan workload performed:

**1,000 scans × 1,000 rows**

### Results

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |    15.584 s | 15.515 s |      -0.4% |
| 64 MB       |    15.624 s | 15.658 s |      +0.2% |
| 16 MB       |    15.679 s | 15.970 s |      +1.9% |

### Interpretation

The measured differences were within approximately ±2%.

This is consistent with measured parity for this workload and environment.

---

## 7. Clustered Index Size

One of the strongest observed differences was clustered-index size.

### Results

| Buffer Pool | Traditional | SMART ID | Difference |
| ----------- | ----------: | -------: | ---------: |
| 512 MB      |    69.84 MB | 42.55 MB |       -39% |
| 64 MB       |    69.84 MB | 33.10 MB |       -53% |
| 16 MB       |    69.84 MB | 46.74 MB |       -33% |

Across the three tested configurations, the SMART ID clustered index was approximately **33–53% smaller**.

### Interpretation

This result is specific to the tested MariaDB/InnoDB workload and configurations.

It must not be interpreted as a universal storage reduction guarantee.

The observed result is associated with the particular key distribution and InnoDB clustered-index behavior produced by the experiment.

---

## 8. Why the Clustered Index Was Smaller

The tested SMART ID values clustered in a way that produced nearly constant high-order key bytes in the relevant portion of the identifier space.

The resulting key distribution affected the physical organization of the InnoDB clustered index.

This can produce denser leaf-page utilization under the tested schema and workload.

This observation is implementation- and workload-dependent.

It does not imply that every database or storage engine will obtain the same benefit.

---

## 9. Physical Reads

Physical-read measurements were also collected.

At the 512 MB and 64 MB buffer-pool configurations, physical reads were approximately zero.

At the 16 MB configuration, approximately:

**78,630 physical reads**

were observed.

The additional physical reads did not produce a corresponding measurable latency shift large enough to establish a separate performance conclusion in this benchmark.

This is an observation of the tested workload, not a general statement about physical I/O behavior.

---

## 10. Overall Result

The valid single-engine experiment supports the following bounded conclusions:

1. SMART ID showed approximate load-performance parity with the comparison identifier.
2. Point-lookup latency was within approximately ±3% in the tested configurations.
3. Range-scan latency was within approximately ±2% in the tested configurations.
4. The clustered index was approximately 33–53% smaller in the tested configurations.
5. The storage-size difference was substantially more visible than the latency differences.
6. The results do not establish universal performance or storage guarantees.

---

## 11. What the Experiment Does Not Prove

The experiment does not prove that SMART ID:

* is universally faster;
* is universally slower;
* always reduces database storage;
* always improves cache behavior;
* always improves I/O;
* always improves write throughput;
* always improves read throughput;
* performs identically under concurrency;
* performs identically across database engines;
* performs identically across hardware platforms; or
* provides any cryptographic performance advantage.

These claims require separate experiments.

---

## 12. Routing Measurement Boundary

The database benchmark should not be interpreted as a benchmark of every part of the SMART ID routing architecture.

The benchmark primarily measures database behavior associated with the selected identifier representation.

SMART ID's routing model includes fixed-position extraction of:

* Engine; and
* Local ID.

The cost of this extraction is distinct from database lookup, network latency, transaction processing, and storage latency.

---

## 13. CPU Cycle Qualification

The project does not assign a universal CPU-cycle count to SMART ID bit extraction.

Actual performance depends on:

* processor architecture;
* compiler;
* generated machine code;
* optimization;
* runtime;
* implementation language;
* surrounding code; and
* microarchitectural behavior.

Therefore, benchmark results should be used instead of universal cycle-count claims.

---

## 14. FPE Boundary

This experiment did not benchmark format-preserving encryption.

FPE is an optional public-ID/application-layer mechanism.

The benchmark therefore does not measure:

* FPE encryption;
* FPE decryption;
* cryptographic key management;
* cryptographic verification;
* public-ID transformation overhead; or
* security-system overhead.

SMART ID bit extraction performance and FPE performance are separate concerns.

---

## 15. Reproducibility Information

The principal reproducibility parameters are:

```text
Dataset:
    1,000,000 rows

Database:
    MariaDB 10.4.32

Storage Engine:
    InnoDB

Operating System:
    Linux

Hardware:
    ASUS ZenBook UX363JA

Storage:
    Local NVMe SSD

Buffer Pools:
    512 MB
    64 MB
    16 MB

innodb_flush_log_at_trx_commit:
    2

innodb_doublewrite:
    OFF

Engine:
    0

Region:
    0

State:
    1

Version:
    0

Local ID:
    Row index
```

---

## 16. Interpretation Standard

The project uses the following interpretation standard:

**Measured result:** directly observed under the stated experimental conditions.

**Parity:** observed difference small enough within the tested configurations that the experiment does not establish a meaningful general advantage.

**Workload-specific storage result:** an observed storage difference that should not be generalized beyond the tested implementation and workload.

**Universal guarantee:** a claim that applies across implementations and environments. The present experiment does not establish such guarantees.

---

## 17. Relationship to v1.4 Specification

The empirical results do not define the SMART ID format.

The v1.4 specification defines:

* the 64-bit layout;
* identity semantics;
* Engine allocation;
* Local ID allocation;
* routing semantics;
* lifecycle semantics;
* persistence requirements;
* failure behavior; and
* versioning.

The benchmark provides supporting empirical evidence for implementation characteristics only.

---

## 18. Future Validation

Further research should include:

* multiple concurrent Engines;
* independent allocator processes;
* multiple database connections;
* larger datasets;
* multiple database engines;
* alternative storage engines;
* higher concurrency;
* distributed deployment;
* replication;
* failure recovery;
* allocator fencing; and
* public-ID/FPE overhead.

These experiments should preserve equivalent workloads and document the complete environment.

---

## 19. Conclusion

The valid v1.4 single-engine experiment does not show a universal latency advantage for SMART ID.

Instead, it shows approximate performance parity with the comparison identifier across the tested load, point-lookup, and range-scan workloads.

The most notable measured difference was clustered-index size, where SMART ID was approximately 33–53% smaller across the tested MariaDB/InnoDB configurations.

That storage result is workload-specific and should be independently validated before being relied upon in production architecture decisions.

The appropriate technical conclusion is therefore:

**SMART ID v1.4 demonstrates measured single-engine parity in the tested environment, with a substantial clustered-index size reduction observed under the same experimental conditions.**
