# SMART 64-Bit ID v1.41 — Technical Package

**Profile:** Version `0`, Revision `0001`  
**Normative source:** [SPECIFICATION.md](SPECIFICATION.md)

This folder is the self-contained supporting package for the v1.41 profile. The normative specification governs if a summary, diagram, example, or explanatory document differs from it.

## Start here

1. [Normative specification](SPECIFICATION.md)
2. [Architecture](ARCHITECTURE.md)
3. [Normative rules summary](RULES.md)
4. [Serialization and security boundary](STANDARDS.md)
5. [Limitations and non-guarantees](LIMITATIONS.md)
6. [Industry alignment](INDUSTRY_ALIGNMENT.md)
7. [Technical overview](papers/SMART_64BIT_ID_TECHNICAL_OVERVIEW_v1.41.md)

## Diagrams

- [Bit layout](diagrams/bit-layout.md)
- [Identity core and control area](diagrams/identity-vs-governance.md)
- [Routing flow](diagrams/routing-flow.md)

## Examples

- [Generation and test vector](examples/generation-example.md)
- [Routing example](examples/routing-example.md)
- [Integration patterns](examples/integration-patterns.md)

## Core facts

- The 54-bit Identity Core is `Class + Engine + Local`.
- The allocation uniqueness coordinate is `Engine + Local`; Class does not partition the allocation namespace.
- The current normative routing selector is Engine, followed by Local lookup.
- Role is structurally in the upper 10 bits but is semantically immutable for an allocated identity.
- Reserved bits 54–57 must be zero in v1.41; Class `0000` is invalid for an allocated identifier.
- Canonical binary serialization is unsigned 64-bit big-endian/network byte order.
- v1.4 is a separate legacy profile. Do not reinterpret its Region field as v1.41 Class and Reserved fields.

The future use of `Class + Engine` as a larger routing/sharding key, a permanent Engine-to-Class binding rule, and global Engine-number governance are not added by this package; they remain deferred topics outside the frozen v1.41 normative text.

## Project and legal documents

- [Version 1.41 changelog](CHANGELOG.md)
- [License](LICENSE)
- [Copyright notice](COPYRIGHT)
- [Commercial license terms](COMMERCIAL-LICENSE.md)
- [Contributing guide](CONTRIBUTING.md)
- [Contributor License Agreement](CLA.md)
- [AI contribution policy](AI_CONTRIBUTIONS.md)

These documents accompany the v1.41 technical package. The normative requirements for the identifier format remain defined by [SPECIFICATION.md](SPECIFICATION.md).
