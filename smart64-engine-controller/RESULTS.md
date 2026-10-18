# Recorded Test Results

This document summarizes the test output recorded for this project.
It is not a substitute for inspecting the original logs and ledgers.

## Main batch test
- Main test suite exit code: 0.
- PHP syntax check: passed.
- `tests/run.php`: passed.
- Additional boundary and 1,000-allocation tests: passed.
- SQLite metadata integrity and journal recovery: passed.
- Allocation journal tests: passed.
- Journal reservation mismatch rejection: passed.
- Journal tampering/truncation rejection: passed.
- SQLite backup-restore recovery test: passed; the journal prevented
  Local ID reuse in that tested restore scenario.
- Process-termination rollback and concurrency/recovery tests: passed.
- Reported concurrent allocations: 200.
- Reported duplicate Local IDs: none.
- Reported allocation sequence: complete and consecutive.
- Engine registration persisted and counter matched.
- Batch summary: 12 checks passed, 0 failed, 0 skipped.
- `tests/validation-30.php`: exit code 0; 30 scenarios passed, 0 failed.

## 10,000-allocation stress test
- Reported result: PASS.
- Concurrency setting: 100.
- Allocations recorded: 10,000.
- Valid allocation records: 10,000.
- Failures: 0.
- Timeouts: 0.
- Reported duration: 1,563.04 seconds (about 26 minutes).
- SQLite version reported by the test: 3.38.5.
- Evidence directory: `evidence/stress-10000/`.
- Script SHA-256 reported at run time:
  `cfb0d0503e8aa2e4ec800f8c8d2fab84660eb1a1748db8556bf670f6c8f5378c`
- Evidence manifest SHA-256 reported at run time:
  `1c1fea41ffec56ddbfc711d1b1fe4374047ea1fc23c39e7ace68faabafe5d0e`

## Interpretation
These are recorded results from the supplied test runs. They do not by
themselves prove that the test scripts are free of defects or that every
returned ID corresponds to independently instrumented SQLite internal writes.
The stress-test ledger records allocation-return evidence.

See TEST-SCOPE.md for known limitations.
