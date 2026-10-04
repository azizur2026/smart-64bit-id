# Changelog

All notable changes to SMART 64-Bit ID are documented in this
file.

The project uses technical specification versions to identify
meaningful changes to the SMART ID model. Git commits provide the
detailed history of individual repository changes.

## [1.4] — 2026-10-04

### Added

- Public release of the SMART 64-Bit ID technical specification.
- 64-bit identity layout with a 50-bit identity core.
- 29-bit Local ID field.
- 21-bit Engine field.
- 8-bit Region metadata field.
- 1-bit lifecycle State field.
- 4 Reserved bits.
- 1 Version bit.
- Fixed-position Engine and Local ID routing model.
- Engine ownership and authoritative allocator requirements.
- Local ID persistence, non-reuse, exhaustion, and crash-recovery
  rules.
- Lifecycle retirement semantics.
- Public-ID and format-preserving-encryption boundary guidance.
- Standards-agnostic cryptographic requirements.
- Single-engine empirical benchmark findings.
- Explicit documentation of the invalid multi-engine benchmark.
- Documentation of benchmark limitations and implementation
  boundaries.
- Dual-licensing documentation for AGPLv3 and commercial use.
- Contributor License Agreement framework.

### Notes

This release establishes the v1.4 technical baseline.

Documentation corrections and non-technical clarifications may be
made through normal Git commits without changing the technical
specification version.

Changes to the SMART ID structure, identity semantics, allocation
rules, routing semantics, lifecycle semantics, failure behavior, or
other core technical requirements should receive a new technical
specification version.

[1.4]: .
