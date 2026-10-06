# Benchmark Results

Date: 2026-10-06

All results below are from the Global ID / Engine / Local benchmark work.

## A0-1 — Basic Engine + Local extraction

Program: `array0_test.c`

Configuration:

- 10,000,000 generated IDs
- actual 29-bit Local + 21-bit Engine layout
- runtime-generated data
- `-O3 -march=native -Wall -Wextra`

Result:

| Metric | Result |
|---|---:|
| IDs | 10,000,000 |
| Elapsed | 16,251,302 ns |
| Time per ID | 1.6251 ns |
| Final sink | 2695553032130652 |

This is a whole-loop measurement containing the ID load, extraction operations, accumulation, and loop control. It is not an isolated instruction-latency measurement.

## A0 cache sweep v2

Program: `array0_cache_v2.c`

Scalar compilation; CPU pinned to CPU 2.

The encoded record contains one 64-bit value. The conventional record contains an opaque 64-bit ID plus a separate 64-bit Engine/Local value.

### Baseline repeated run

| Records | Working set | Encoded ns/record | Conventional ns/record | Encoded/Conventional |
|---:|---:|---:|---:|---:|
| 512 | 4 KB | 1.3902 | 1.4323 | 0.9706 |
| 4,096 | 32 KB | 1.3486 | 1.3955 | 0.9663 |
| 8,192 | 64 KB | 1.3832 | 1.7602 | 0.7858 |
| 65,536 | 512 KB | 1.3235 | 1.3736 | 0.9635 |
| 262,144 | 2 MB | 1.4478 | 1.8313 | 0.7906 |
| 786,432 | 6 MB | 1.4554 | 1.8499 | 0.7868 |
| 2,097,152 | 16 MB | 1.4995 | 1.8943 | 0.7916 |
| 8,388,608 | 64 MB | 1.5040 | 1.9009 | 0.7912 |

For the larger working sets, the encoded representation was approximately 21% lower in measured time per record.

This result does not prove that the difference is caused specifically by fewer cache misses. The conventional record is twice the size and requires two 64-bit loads, so lower memory traffic and fewer loads are plausible contributors.

### Perf-instrumented run

| Records | Encoded | Conventional | Encoded/Conventional |
|---:|---:|---:|---:|
| 512 | 1.3958 | 1.4128 | 0.9880 |
| 4,096 | 1.3264 | 1.3686 | 0.9692 |
| 8,192 | 1.4311 | 1.3623 | 1.0505 |
| 65,536 | 1.3508 | 1.3999 | 0.9650 |
| 262,144 | 1.5901 | 2.1375 | 0.7439 |
| 786,432 | 1.5589 | 1.9395 | 0.8038 |
| 2,097,152 | 1.4721 | 1.8619 | 0.7906 |
| 8,388,608 | 1.6379 | 2.0487 | 0.7995 |

Whole-program `perf` counters for this run:

| Counter | Value |
|---|---:|
| Cycles | 1,13,42,46,939 |
| Instructions | 2,92,44,35,079 |
| Instructions/cycle | 2.58 |
| Cache references | 4,61,24,514 |
| Cache misses | 2,59,74,708 |
| Cache-miss rate | 56.314% |
| Elapsed | 0.571728324 s |
| User time | 0.453770 s |
| System time | 0.116454 s |

These counters cover the whole program and are not path-specific.

## A0-6 — Controlled additional independent load

Program: `array0_control_v6.c`

The encoded path loads one 64-bit value and extracts Engine/Local.

The control path loads the request ID plus a second independent 64-bit value and extracts Engine/Local from the second value.

This test is deliberately not an external lookup simulation. It isolates the cost of an additional independent load.

### Five repeated runs

| Run | Encoded ns/record | Two-load control ns/record | Encoded improvement |
|---:|---:|---:|---:|
| 1 | 1.702974 | 2.128699 | 20.00% |
| 2 | 1.630352 | 2.061075 | 20.90% |
| 3 | 1.762043 | 2.125665 | 17.11% |
| 4 | 1.790823 | 2.039762 | 12.20% |
| 5 | 1.611753 | 2.048981 | 21.34% |

### Perf-instrumented run

| Metric | Encoded | Two-load control |
|---|---:|---:|
| ns/record | 1.677506 | 2.196436 |

Encoded/control ratio: 0.763740

Measured improvement: 23.63%

Whole-program `perf` counters:

| Counter | Value |
|---|---:|
| Cycles | 202,896,318,181 |
| Instructions | 631,754,040,081 |
| Instructions/cycle | 3.11 |
| Cache references | 158,514,479 |
| Cache misses | 39,644,015 |
| Cache-miss rate | 25.010% |
| Elapsed | 1.022863349 s |
| User time | 1.017063 s |
| System time | 0.004004 s |

Again, these counters are whole-program measurements.

## A3 — Engine selection

Program: `a3_engine_select.c`

Configuration:

- 262,144 records
- 1,000 repetitions
- 8 Engine IDs
- CPU pinned to CPU 2
- correctness checked

### Results

| Run | Proposed ns/request | Conventional ns/request | Improvement |
|---:|---:|---:|---:|
| 1 | 0.524140 | 1.507563 | 65.23% |
| 2 | 0.522770 | 1.407340 | 62.85% |
| 3 | 0.524861 | 1.434069 | 63.40% |
| 4 | 0.522132 | 1.485866 | 64.86% |
| 5 | 0.521170 | 1.445089 | 63.94% |

Approximate mean:

- Proposed: 0.523 ns/request
- Conventional: 1.457 ns/request
- Improvement: approximately 64.1%

All runs: correctness PASS.

Interpretation: direct Engine extraction/selection from the encoded ID eliminated the tested external Engine-resolution step.

## A4 — Local/subject selection

Program: `a4_local_select.c`

Configuration:

- 262,144 records
- 1,000 repetitions
- 8 Engine namespaces
- CPU pinned to CPU 2
- correctness checked

### Results

| Run | Proposed ns/request | Conventional ns/request | Improvement |
|---:|---:|---:|---:|
| 1 | 0.528873 | 1.316303 | 59.82% |
| 2 | 0.531108 | 1.354274 | 60.78% |
| 3 | 0.528655 | 1.295617 | 59.20% |
| 4 | 0.528636 | 1.314643 | 59.79% |
| 5 | 0.526609 | 1.443074 | 63.51% |

Approximate mean:

- Proposed: 0.529 ns/request
- Conventional: 1.345 ns/request
- Improvement: approximately 60.6%

All runs: correctness PASS.

Interpretation: direct Local extraction/subject selection from the encoded ID eliminated the tested external Local-resolution step.

## Overall conclusion

The strongest result is component-level:

> Embedding Engine ID and Local ID directly in the Global ID can eliminate a separate identity-resolution operation.

In these controlled microbenchmarks:

- Engine selection: approximately 64% lower measured time
- Local/subject selection: approximately 61% lower measured time
- Basic Engine/Local extraction: approximately 1.63 ns/ID
- Controlled extra-load cost: approximately 12–24% in repeated runs

The results do not establish a universal end-to-end performance improvement. They establish that the representation changes the computational path by making Engine and Local information directly available from the ID value.
