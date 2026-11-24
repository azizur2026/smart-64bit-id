# SMART 64-Bit ID

**A structured 64-bit identity system designed for deterministic allocation, compact representation, and scalable routing.**

SMART 64-Bit ID is a versioned identity specification focused on defining a structured identifier, its allocation model, encoding, and technical behavior. This repository contains normative specifications, architecture documentation, implementation test evidence, benchmarks, and research materials.

---

## Current Specifications

Specifications are listed newest first. Release candidates are not stable releases.

| Version | Status | Documentation |
|---|---|---|
| **v1.42 RC2.2** | Latest Release Candidate | [Specification](v1.42/RC2.2/SPECIFICATION.md) · [Release Directory](v1.42/RC2.2/) |
| **v1.42 RC1** | Previous Release Candidate | [Specification](v1.42/RC1/SPECIFICATION.md) · [Release Directory](v1.42/RC1/) |
| **v1.41** | Stable | [Specification](v1.41/SPECIFICATION.md) · [Release Directory](v1.41/) |

### Version Selection

- **v1.42 RC2.2** — Review the latest proposed specification, including the Class + Engine organization and QDH-related updates.
- **v1.42 RC1** — Review the earlier release candidate based on the Engine + Local ID identity model.
- **v1.41** — Refer to the stable specification.

The structural changes introduced in RC2.2 should not be retroactively attributed to RC1 or v1.41.

---

## v1.42 RC2.2 — Latest Release Candidate

### Normative & Technical Documentation

- [Normative Specification](v1.42/RC2.2/SPECIFICATION.md)
- [Error Codes](v1.42/RC2.2/errors/ERROR-CODES.md)
- [Architecture](v1.42/RC2.2/ARCHITECTURE.md)
- [Bit Layout](v1.42/RC2.2/diagrams/bit-layout.md)

### QDH Documentation

- [QDH Specification](v1.42/RC2.2/QDH-SPECIFICATION.md)
- [QDH Error Codes](v1.42/RC2.2/QDH-ERROR-CODES.md)
- [QDH Logging & Lifecycle](v1.42/RC2.2/QDH-LOGGING-AND-LIFECYCLE.md)

### Database Schemas

- [MySQL QDH Schema](v1.42/RC2.2/qdh_schema_mysql.sql)
- [PostgreSQL QDH Schema](v1.42/RC2.2/qdh_schema_postgresql.sql)

### Release

- [v1.42 RC2.2 Release](https://github.com/azizur2026/smart-64bit-id/releases/tag/v1.42-rc2.2)
- [RC2.2 Directory](v1.42/RC2.2/)

> RC2.2 is a release candidate, not a declaration of stable status or production readiness.

---

## v1.42 RC1

The RC1 documentation preserves the earlier Engine + Local ID model.

- [Specification](v1.42/RC1/SPECIFICATION.md)
- [Release README](v1.42/RC1/README.md)
- [Architecture](v1.42/RC1/ARCHITECTURE.md)
- [Error Codes](v1.42/RC1/errors/ERROR-CODES.md)
- [Bit Layout](v1.42/RC1/diagrams/bit-layout.md)
- [Changelog](v1.42/RC1/CHANGELOG.md)

[GitHub Release — v1.42 RC1](https://github.com/azizur2026/smart-64bit-id/releases/tag/v1.42-rc1)

---

## v1.41 — Stable Specification

- [Normative Specification](v1.41/SPECIFICATION.md)
- [v1.41 Directory](v1.41/)

---

## Implementation Verification

Implementation test evidence is maintained separately from the normative specification. Passing a test package does not establish universal correctness or production readiness.

### S64BT v0.r04

The S64BT v0.r04 package documents implementation testing, verification results, execution procedures, limitations, and evidence.

- [Test Package README](v1.42/RC1/implementation-tests/s64bt-v0r04/README.md)
- [Verification Note](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/VERIFICATION-NOTE.md)
- [Test Procedure](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/TEST-PROCEDURE.md)
- [Limitations](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/LIMITATIONS.md)
- [Evidence Index](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/EVIDENCE-INDEX.md)

**Recorded package result: 8/8 gates passed.**

The documented test environment includes MariaDB 10.4.32 with InnoDB. Results apply to the recorded test scope and environment.

[Release — S64BT v0.r04](https://github.com/azizur2026/smart-64bit-id/releases/tag/s64bt-v0.r04)

### CT-07 — Concurrency & Allocation Test

The recorded CT-07 run exercised concurrent allocation using 1,000 workers.

| Metric | Recorded Result |
|---|---:|
| Workers | 1,000 |
| Allocations attempted | 100,000 |
| Successful allocations | 100,000 |
| Failed allocations | 0 |
| Retries | 0 |
| Duplicate-key errors | 0 |
| Connection failures | 0 |
| Distinct S64 IDs produced | 100,000 |
| Incorrectly encoded rows | 0 |
| Local ID range | 1–100,000 |
| Next Local ID | 100,001 |
| Elapsed time | ~914 seconds |
| Observed allocation rate | ~109 allocations/second |

These are recorded test results, not universal throughput guarantees.

**Evidence:** [CT-07 Results — Verification Note, Section 2](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/VERIFICATION-NOTE.md#2-results-from-the-recorded-run)

Supporting documentation:

- [Verification Note](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/VERIFICATION-NOTE.md)
- [Test Procedure](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/TEST-PROCEDURE.md)
- [Limitations](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/LIMITATIONS.md)
- [Evidence Index](v1.42/RC1/implementation-tests/s64bt-v0r04/docs/EVIDENCE-INDEX.md)

---

## Benchmark & Research

### v1.41 Routing Microbenchmark

A native C routing microbenchmark evaluates routing strategies under controlled shard-count configurations.

The benchmark examines:

- SMART Engine routing
- Direct ID modulo routing
- Full-ID hash lookup
- Multiple shard-count configurations
- Repeated runs and a separate retest
- Validation, environment, limitations, and reproducibility evidence

[Read the v1.41 Routing Benchmark Report](research/2026-10-21-v141-routing-benchmark-01/V1.41_ROUTING_BENCHMARK_V6_REPORT.md)

This is a routing microbenchmark, not a database benchmark or an end-to-end application benchmark. Its results should not be interpreted as universal performance claims.

[Research Directory](research/)

---

## Architecture & Design References

For version-specific architecture and encoding details, consult the corresponding version documentation.

- [v1.42 RC2.2 Architecture](v1.42/RC2.2/ARCHITECTURE.md)
- [v1.42 RC2.2 Bit Layout](v1.42/RC2.2/diagrams/bit-layout.md)
- [v1.42 RC1 Architecture](v1.42/RC1/ARCHITECTURE.md)
- [v1.42 RC1 Bit Layout](v1.42/RC1/diagrams/bit-layout.md)

Always use the documentation corresponding to the specification version under review.

---

## Maturity & Limitations

SMART 64-Bit ID is a versioned specification supported by documented implementation testing and research.

The scope of the available evidence is limited to the configurations, procedures, and conditions described in the respective reports.

- Specification status does not automatically imply implementation certification.
- Passing test gates does not establish production readiness.
- Microbenchmark results do not guarantee real-world application performance.
- Release candidates may change before a stable release.
- Research and experimental components should be evaluated independently of normative specifications.

---

## Repository Resources

- [Specifications](v1.42/)
- [Stable Specification — v1.41](v1.41/)
- [Research & Benchmarks](research/)
- [GitHub Releases](https://github.com/azizur2026/smart-64bit-id/releases)

---

## License

See [LICENSE](LICENSE) for licensing terms.
