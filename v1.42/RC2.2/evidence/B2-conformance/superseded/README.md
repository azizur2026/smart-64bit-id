# Superseded captures

These logs document earlier RC2 drafts and are **not** release evidence.

- `mysql_final.log`, `pg_final.log`, `pg_suite.log` — 13-case suite, captured before
  case C14 (epoch-mismatch regression) was added.
- `mysql_C01_C05.log`, `pg_C01_C05.log` — partial runs of cases C01–C05 only.

The authoritative conformance evidence for this release is `../mysql_suite.log` and
`../postgresql_suite.log`, each `PASS=14 FAIL=0`, captured against the released
schema files and covering cases C01–C14.
