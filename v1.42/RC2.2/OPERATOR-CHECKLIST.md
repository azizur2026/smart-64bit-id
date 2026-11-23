# SMART 64-Bit ID v1.42 RC2.2 — Operator Deployment Checklist

**Purpose:** items an adopting organisation must complete in its own environment. Nothing here is
ticked by the project; each box belongs to the deployer, and each should be backed by its own record.

## 1. Database

- [ ] Database created. MySQL: the database must be named `qdh_schema`, because the grant block is
      database-qualified and MySQL provides no portable alternative.
- [ ] Schema loaded in one pass; load log retained.
- [ ] Roles created and the four-way separation preserved: controller, allocator, QDH policy engine,
      auditor.
- [ ] No principal holds direct INSERT on `identity_records`, `durable_allocation_log` or
      `coordinate_tombstones`.
- [ ] `tests/sql/run.sh` executed against the deployed build; 14/14 recorded.

## 2. Control table

- [ ] Control table replicated to a store independent of any single node.
- [ ] For every v1.41 engine, the control-table row treated as the sole Class record and protected
      accordingly.
- [ ] Physical nodes registered, with network and hardware addresses treated as locators only.

## 3. Trust and keys

- [ ] Trust roots provisioned, with a documented allowlist of measurement digests.
- [ ] A revocation path exists that does not depend on the orchestrator's write privilege.
- [ ] Lease-signing keys under the operator's key lifecycle policy.
- [ ] Certificate validity windows and revocation freshness thresholds set.

## 4. Audit

- [ ] `tests/golden/audit_hash_vectors.json` reproduced on the deployed build.
- [ ] External anchoring configured, or the non-repudiation claim reduced to tamper-evidence in the
      release notes.
- [ ] Anchor retention and restore-verification procedure documented.

## 5. QDH operations

- [ ] Incident taxonomy extended, if required, and registered.
- [ ] `qdh_audit_gap` monitored as a standing alert.
- [ ] Sanitisation policy defined per NIST SP 800-88 vocabulary, with the operator's validation
      criteria.

## 6. Claims

- [ ] No conformance, certification or performance claim published beyond what the deployer has
      itself evidenced.

**Operator:** ____________________  **Date:** ____________________
