# SMART 64-Bit ID v1.42 — Changelog

## v1.42 — Release Candidate 2 — Finalized (2026-11-23)

RC1 of this profile remains supported. Identifiers allocated under RC1 remain valid and require no
migration or re-issue; both candidates carry Revision `0010`, so profile selection cannot
distinguish them.

### Core corrections

- **Profile upgrade no longer invalidates existing identities.** Provenance is compared against the
  profile of the generation in which an identity was allocated, not against the engine's current
  `active_profile`. Previously any upgrade would have made every pre-existing identity fail
  validation permanently. An upgrade now opens a new generation, recorded with the
  `PROFILE_UPGRADE` closure reason, and does not rewrite any identity record.

- **New `S64-E030 PROFILE_PROVENANCE_MISMATCH`.** Profile provenance is no longer reported as
  `S64-E015`, which retains its original Class-binding meaning.

- **New `S64-E031 LIFECYCLE_TRANSITION_INVALID`.** An inadmissible lifecycle transition now has its
  own code instead of being folded into a safety failure.

- **History-chain root inheritance is normative.** A first allocation self-roots its chain; a
  successor must inherit its predecessor's root. Without this rule the one-resolvable-identifier
  index enforces nothing, because the grouping key would be arbitrary caller input.

- **Epoch-fence mechanisms narrowed.** A declarative check constraint cannot reference another
  table and no longer counts as an epoch fence; an application-side read followed by an
  unconditional write at a weaker isolation level does not satisfy §10.7.2.

- **Durable allocation evidence is mandatory.** The lease-ceiling and lease-watermark rules in §7.3
  changed from recommendations to requirements, because the reclamation safety argument depends on
  them.

- **New §6.3.2 control-table semantics.** Four separated roles; node and engine as distinct
  entities; network and hardware addresses as locators only, never identity or authentication;
  placement-change rules; and a durability requirement for the control table, which for v1.41
  engines is the sole record of Class.

- **Reservation duty clarified.** §6.4 states that a forward reservation must exist before the final
  Local coordinate is issued, and that rollover is not a failure-recovery path.

### QDH

- Introduces `QDH-SPECIFICATION.md`, `QDH-ERROR-CODES.md` and `QDH-LOGGING-AND-LIFECYCLE.md`:
  quarantine, database-engineering verification, hardware sanitization and attestation, atomic
  epoch commit, and controlled reactivation.

- `FAIL_HARD` remains an operational outcome. Under v1.42 it is recoverable only through the QDH
  lifecycle. Engines permanently retired under pre-v1.42 rules remain ineligible.

- Eight-state lifecycle with universal quarantine entry, evidence binding, and Phase 5 event
  ordering.

- 20 QDH diagnostic codes; `QDH-E018`–`QDH-E020` added, `QDH-E015` remapped to `S64-E030`,
  `QDH-E016` confined to missing evidence.

- 12 mandatory audit event types, including `PROFILE_UPGRADED`; `PROFILE_UPGRADE` added to the
  lineage closure-reason enum.

### Schemas and evidence

- `qdh_schema_mysql.sql` (MySQL 8.0.16+, deployed into a database named `qdh_schema`) and
  `qdh_schema_postgresql.sql` (PostgreSQL 11+). Both build in a single pass against an empty
  database.

- `tests/golden/audit_hash_vectors.json` — five vectors; TC-1 to TC-4 must verify, TC-5 must fail.

- Retirement is executable end to end. Previously a record could be neither retired nor quarantined
  once an unallocated engine shared the node.

### Error registry

- 31 codes, `S64-E001`–`S64-E031`.

- `S64-E024` renamed from `RETIREMENT_REQUIRED` to `RETIRED_RECORD_MUTATION`, and `S64-E025` from
  `RETIRED_IDENTIFIER_OPERATION` to `RETIRED_RECORD_REACTIVATION`, with their triggers.

- Allocation precedence now begins with authority, fencing and epoch, so a stale-epoch commit is
  never masked by a later safety code.

### Profile boundaries

- Revision `0000` (v1.4) is obsolete and unsupported. v1.41 (`0001`) and v1.42 (`0010`) remain the
  active profiles of the Version 0 family.

## v1.42 — Release Candidate 1

Initial release candidate of the profile: encoded Class in bits 50–53, Virtual Engine ID as
Class + Engine, per-Class Engine pools, retirement as a record-level transition, permanent
coordinate consumption with permanent tombstones, Engine exhaustion and rollover, terminal
Engine-ID exhaustion, deferred 5-bit Class expansion, and the error registry as a separate
document.

Superseded by RC2.2 but still supported; see the compatibility note at the top of this entry.

## v1.41 — Stable

- Declares the SMART 64-Bit ID v1.41 specification stable.
- Defines the normative 64-bit layout, validation rules, and version handling.
- Establishes Class + Engine + Local as the uniqueness coordinate for v1.41, where bits 50-53 are a zero marker.
- Clarifies Class, Role, and Engine-based routing semantics.
- Keeps deferred governance and future-version topics separate from v1.41 requirements.

## v1.4 — 2026-10-04 — Obsolete

- Public release of the technical specification: 64-bit layout with a 50-bit identity core,
  29-bit Local, 21-bit Engine, 8-bit Region metadata, 1-bit lifecycle State, 4 Reserved bits,
  1 Version bit.
- Fixed-position Engine and Local routing; Engine ownership and authoritative allocator
  requirements; Local persistence, non-reuse, exhaustion and crash recovery; lifecycle retirement;
  public-ID and format-preserving-encryption boundary guidance.

**Status:** obsolete and unsupported. Version 0, Revision `0000` is rejected with `S64-E002`.
Retained for historical reference only. v1.4 identifiers must not be treated as valid v1.41 or
v1.42 identifiers, and must not be rewritten, masked, or converted into either profile.

All notable changes to SMART 64-Bit ID are documented in this file.

## RC2.2 — 2026-11-23

- C14 rebuilt: a stale epoch-1 quarantine event is now tested against an epoch-2 engine.
- qdh_audit_gap added to the MySQL schema (it was absent) and granted in both dialects.
- QDH-SPECIFICATION.md 4.7 specifies the view, its epoch predicate and its coverage.
- tests/sql/allocator_path.sh added: restricted-allocator allocation with explicit assertions.
- Manifests re-sealed: 39 shipped files, 20 evidence files.
