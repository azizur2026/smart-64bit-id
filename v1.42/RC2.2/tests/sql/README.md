# Executable conformance suite

Run `bash tests/sql/run.sh mysql` (database `qdh_schema`) or `bash tests/sql/run.sh pg`
(database `qdh_t`). Each case recreates the database, applies the schema, seeds
a fixture and compares the result. Exit status 0 means all cases passed; an unknown
engine prints usage and exits 2.

Fourteen cases (C01-C14) are implemented and executed on both dialects. The case
list and results are in `REVIEW-RESPONSE.md`; the case labels in `run.sh` are normative.
C14 reproduces the stale-epoch case: the engine is advanced to epoch 2 with a real
epoch-1 closing event, and `qdh_audit_gap` must report 1 until the epoch-2 quarantine
event exists, then 0.

`gen_event.py <engine> <mode>` emits audit-event SQL for: `good`, `bad-hash`,
`quarantine-epoch1`, `quarantine-epoch2`, `reclaim-epoch1`,
`quarantine-epoch2-after-reclaim`, and the default `bad-chain`.

Capture scripts, not invoked by `run.sh`:

- `check_public_schema.sh [db]` - Finding A privilege proof.
- `f3_audit_gap.sh [db]` - F3 capture; `qdh_audit_gap` = 1 then 0, as `s64_auditor_role`.
- `allocator_path.sh mysql|pg` - restricted-role allocation succeeds, then the same role is denied a direct INSERT. Asserts the smart ID, the four counts, the tombstone coordinate and status, and the denial; exits non-zero on any mismatch.
