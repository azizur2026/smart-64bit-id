# Test Scope and Limitations

## Areas reported as tested
- PHP syntax and main test-suite execution.
- Boundary and 1,000-allocation checks.
- Thirty validation scenarios.
- SQLite metadata integrity and journal recovery.
- Allocation-journal reservation consistency.
- Rejection of tested journal tampering and truncation.
- Tested SQLite backup-restore recovery scenario.
- Rollback after process termination.
- Concurrent allocation and Local ID uniqueness/sequence checks.
- A 10,000-allocation stress run with concurrency set to 100.

## Explicit limitations
The recorded batch-test output explicitly identifies these limitations:
- Stale-backup restoration is not tested.
- Distributed fencing is not tested.

Additional interpretation limits:
- A passing test run covers its tested scenarios, not all possible failures.
- Hashes help detect subsequent file changes but do not independently establish
  a trusted timestamp, independent custody, or test-script correctness.
- The 10,000-allocation run's reported byte ledger is evidence of the
  allocator's returned IDs; it is not independent instrumentation of all
  SQLite internal writes.
- Production readiness and distributed-system guarantees are not established
  by these test results alone.

## Release posture
Controlled alpha candidate for further evaluation. Do not describe the
project as fully production-ready based solely on this evidence.
