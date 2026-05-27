#!/usr/bin/env python3
import csv
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: select_cases.py cases.csv JOB_INDEX NUM_JOBS")

cases_csv, job_index_s, num_jobs_s = sys.argv[1:]
job_index = int(job_index_s)
num_jobs = int(num_jobs_s)

with open(cases_csv, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        cid = int(row["case_id"])
        if cid % num_jobs == job_index:
            print("\t".join([
                str(cid),
                row["run_name"],
                row["st1_file"],
                row["st2_file"],
                row["case_dir"],
            ]))
