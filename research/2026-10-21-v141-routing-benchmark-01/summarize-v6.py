import csv
import glob
import statistics
from collections import defaultdict
from pathlib import Path

runs = sorted(glob.glob("v6-run-*.stdout"))
if len(runs) != 10:
    raise SystemExit(f"Expected 10 run files; found {len(runs)}")

fields = {
    "smart": "smart_ns_per_id",
    "id_modulo": "id_modulo_ns_per_id",
    "hash_lookup": "hash_lookup_ns_per_id",
}
per_run = defaultdict(list)
all_checksums = defaultdict(set)

for filename in runs:
    run_id = Path(filename).stem.replace("v6-run-", "")
    status_file = Path(f"v6-run-{run_id}.exit-status")
    stderr_file = Path(f"v6-run-{run_id}.stderr")

    if not status_file.exists() or status_file.read_text().strip() != "0":
        raise SystemExit(f"FAIL: nonzero/missing exit status: {run_id}")
    if not stderr_file.exists() or "ERROR:" in stderr_file.read_text():
        raise SystemExit(f"FAIL: missing stderr or ERROR: {run_id}")

    lines = [
        line for line in Path(filename).read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ]
    rows = list(csv.DictReader(lines))
    if len(rows) != 14:
        raise SystemExit(f"FAIL: {run_id} has {len(rows)} rows, expected 14")

    seen = defaultdict(int)
    for row in rows:
        shards = int(row["shards"])
        seen[shards] += 1

        if row["smart_checksum"] != row["hash_lookup_checksum"]:
            raise SystemExit(f"FAIL: SMART/hash checksum mismatch in {run_id}")
        for col in ("smart_checksum", "id_modulo_checksum",
                    "hash_lookup_checksum"):
            all_checksums[(shards, col)].add(row[col])

        for method, column in fields.items():
            per_run[(shards, method, run_id)].append(float(row[column]))

    if sorted(seen.values()) != [7, 7]:
        raise SystemExit(f"FAIL: expected 7 samples per shard in {run_id}")

for (shards, col), values in all_checksums.items():
    if len(values) != 1:
        raise SystemExit(f"FAIL: inconsistent {col} for shards={shards}")

for shards in (50021, 100003):
    if all_checksums[(shards, "smart_checksum")] != \
       all_checksums[(shards, "hash_lookup_checksum")]:
        raise SystemExit(f"FAIL: checksum mismatch at {shards} shards")

    if all_checksums[(shards, "id_modulo_checksum")] == \
       all_checksums[(shards, "smart_checksum")]:
        print(f"NOTE: ID-modulo checksum matches at {shards}; inspect routing")

summary = []
for shards in (50021, 100003):
    for method in fields:
        run_medians = []
        for filename in runs:
            run_id = Path(filename).stem.replace("v6-run-", "")
            samples = per_run[(shards, method, run_id)]
            if len(samples) != 7:
                raise SystemExit(f"FAIL: wrong sample count: {run_id}")
            run_medians.append(statistics.median(samples))

        q1, _, q3 = statistics.quantiles(
            run_medians, n=4, method="inclusive"
        )
        summary.append({
            "shards": shards,
            "method": method,
            "median_ns_per_id": statistics.median(run_medians),
            "Q1": q1,
            "Q3": q3,
        })

with open("v6-summary.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=[
        "shards", "method", "median_ns_per_id", "Q1", "Q3"
    ])
    writer.writeheader()
    writer.writerows(summary)

print("PASS: 10 runs, 14 rows/run, 7 samples per shard/run")
print("PASS: SMART and hash-lookup checksums match")
print("Created v6-summary.csv")
for row in summary:
    print(
        f'{row["shards"]:6} {row["method"]:12} '
        f'median={row["median_ns_per_id"]:.4f} '
        f'Q1={row["Q1"]:.4f} Q3={row["Q3"]:.4f} ns/ID'
    )
