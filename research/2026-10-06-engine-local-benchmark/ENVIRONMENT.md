# Benchmark Environment

Date: 2026-10-06

## Hardware

CPU:

- Intel Core i5-1035G1 CPU @ 1.00GHz
- 4 physical cores
- 8 logical CPUs
- 1 socket
- 1 NUMA node
- maximum reported CPU frequency: 3.60 GHz
- minimum reported CPU frequency: 400 MHz
- L1 data cache: 192 KiB total
- L1 instruction cache: 128 KiB total
- L2 cache: 2 MiB total
- L3 cache: 6 MiB shared

The CPU frequency is dynamic. The benchmark therefore reports elapsed time per operation rather than converting it into a fixed-cycle claim.

## Compiler

GCC was used.

Scalar benchmark builds used:

```text
-O3 -fno-tree-vectorize -fno-tree-slp-vectorize -march=native -Wall -Wextra
```

The standalone extraction test used:

```text
-O3 -march=native -Wall -Wextra
```

## CPU affinity

The cache and controlled-load tests were run pinned to CPU 2.

The Engine-selection and Local-selection programs also pin their benchmark process to CPU 2 internally.

## Benchmark discipline

The tests use:

- deterministic data where applicable
- warm-up before timed sections where applicable
- repeated timed runs
- volatile sinks / correctness checks to prevent dead-code elimination
- scalar compilation for the representation-comparison tests

## Hardware counters

Linux `perf` was available after lowering `kernel.perf_event_paranoid` to 1.

Important: the recorded `perf` counters are whole-program counters, not counters separately attributed to each timed path. They therefore must not be interpreted as path-specific cache-miss measurements.

## Scope boundary

These experiments are CPU/memory representation and selection microbenchmarks.

They do not evaluate:

- network latency
- distributed-system latency
- application-level throughput under production load
