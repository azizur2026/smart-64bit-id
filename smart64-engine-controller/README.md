# SMART64 SQLite Engine Controller

A SQLite-based 64-bit identifier allocation engine and controller, with allocation journaling, recovery checks, and concurrency tests.

## Contents

- `index.php` — controller entry point
- `src/` — current SQLite implementation
- `tests/` — validation, journaling, integrity, and recovery tests
- `evidence/` — selected test and allocation evidence
- `reports/` — retained byte-evidence ledger
- `RESULTS.md` — recorded test outcomes
- `TEST-SCOPE.md` — tested scenarios and limitations
- `EVIDENCE-INDEX.md` — evidence guide

## Validation status

The recorded test runs passed their documented checks. The 10,000-allocation evidence records a run with zero reported failures and timeouts. These are results for the documented test environment, not a guarantee of production readiness.

Stale-backup restoration and distributed fencing remain limitations requiring further validation.

## Scope

This release contains the SQLite controller project only. Local runtime databases, generated worker logs, historical source snapshots, and redundant historical reports are not part of the curated release.

## Before deployment

Review configuration, file permissions, database placement, backup and restore behavior, and operational recovery procedures before using this controller in production.
