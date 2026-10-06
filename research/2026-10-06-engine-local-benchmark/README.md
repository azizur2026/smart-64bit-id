# Engine + Local ID Benchmark — 2026-10-06

This directory records the 2026-10-06 controlled microbenchmark work on the published Global ID representation.

## Scope

The experiments isolate the cost of using Engine ID and Local ID embedded directly in the Global ID.

Included:

- `array0_test.c` — basic Engine/Local extraction
- `array0_cache_v2.c` — working-set/cache sweep
- `array0_control_v6.c` — controlled comparison with an additional independent load
- `a3_engine_select.c` — Engine selection
- `a4_local_select.c` — Local/subject selection

The experiments are CPU/memory microbenchmarks focused on Global ID representation and Engine/Local selection.

## Global ID layout used

The programs use the published layout:

- bits 0–28: Local ID
- bits 29–49: Engine ID
- bits 50–57: Region
- bit 58: State
- bits 59–62: Reserved
- bit 63: Version

The A3/A4 tests use State=1 and Version=1 for active test IDs.

## Main findings

1. Engine selection from the encoded ID was approximately 64% faster than the tested external-mapping control.
2. Local/subject selection from the encoded ID was approximately 61% faster than the tested external-mapping control.
3. Basic extraction of Engine and Local from one 64-bit ID measured about 1.63 ns/ID in the standalone test.
4. In the cache/working-set test, the encoded representation consistently required less measured time than the conventional 16-byte record containing an opaque ID plus an external Engine/Local value.
5. The controlled extra-load test showed that an additional independent 64-bit load alone produced roughly 12–24% extra measured time in repeated runs.

These results support the narrower claim that embedding Engine and Local information directly in the ID can eliminate a separate identity-resolution step. They do not establish that the complete application path will always be faster.

## Reproducibility

The source files are the exact benchmark programs used for the reported runs. Compiler commands and execution conditions are recorded in `ENVIRONMENT.md`.

The benchmark results are recorded in `RESULTS.md`.
