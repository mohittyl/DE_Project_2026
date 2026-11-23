# CP4 — Large-Data Scalability Report

## Dataset and method

- PostgreSQL 18.4 on Apple Silicon; seed and large databases were measured on the same local instance.
- Seed database: `duolingo_seed`; large database: `duolingo_large`.
- Each workload query was run three times with `EXPLAIN (ANALYZE, BUFFERS)` using `benchmarks/run_benchmark.sh`; write statements ran in transactions and were rolled back.
- The full 30-query optimized workload used for both measurements is from linked repository commit `ce61dbf` (`sql/06_optimized_queries.sql`). The current workspace copy contains only R01–R07, so sync that file before rerunning these benchmarks from this folder.
- Large-data run used monthly `started_at` range partitions created by `sql/08_partitioning.sql`, then `sql/05_indexes.sql` and `ANALYZE`.
- Timings below are averages in milliseconds. Growth is `large average / seed average`; target compliance is based on the large average.

## Loaded data

| Table | Seed rows | Large rows |
|---|---:|---:|
| languages | 10 | 10 |
| courses | 11 | 11 |
| units | 220 | 220 |
| lessons | 1,760 | 1,760 |
| learners | 30,000 | 600,000 |
| enrollments | 37,500 | 750,000 |
| lesson_attempts | 188,300 | 3,608,300 |
| daily_activity | 189,109 | 3,626,847 |
| league_memberships | 28,598 | 546,036 |
| achievements | 10 | 10 |
| learner_achievements | 38,860 | 773,472 |

Counts are data rows, excluding CSV headers. The actual large archive is close to 20× for the high-volume tables; its counts differ slightly from the approximate figures in the project brief.

## Query results and targets

| Query | Group | Seed avg (ms) | Large avg (ms) | Growth | Target | Result / note |
|---|---|---:|---:|---:|---:|---|
| R01 | Interactive | 0.109 | 0.198 | 1.8× | < 250 | PASS |
| R02 | Learner-facing | 0.127 | 0.172 | 1.4× | < 5 | PASS |
| R03 | Learner-facing | 0.121 | 0.161 | 1.3× | < 5 | PASS |
| R04 | Learner-facing | 0.145 | 2.492 | 17.2× | < 5 | PASS; Met on average; DATE(started_at) still prevents partition pruning. |
| R05 | Learner-facing | 0.069 | 0.232 | 3.4× | < 5 | PASS |
| R06 | Learner-facing | 0.126 | 2.333 | 18.5× | < 5 | PASS |
| R07 | Analytics | 6.674 | 1042.629 | 156.2× | < 5000 | PASS |
| R08 | Analytics | 15.813 | 269.739 | 17.1× | < 5000 | PASS |
| R09 | Analytics | 0.775 | 28.853 | 37.2× | < 5000 | PASS |
| R10 | Analytics | 2.923 | 26.345 | 9.0× | < 5000 | PASS |
| R11 | Learner-facing | 0.016 | 0.116 | 7.2× | < 5 | PASS |
| R12 | Learner-facing | 0.051 | 0.197 | 3.9× | < 5 | PASS |
| R13 | Interactive | 3.696 | 116.505 | 31.5× | < 250 | PASS |
| R14 | Analytics | 1.121 | 15.352 | 13.7× | < 5000 | PASS |
| R15 | Analytics | 1.292 | 15.264 | 11.8× | < 5000 | PASS |
| R16 | Interactive | 3.126 | 123.588 | 39.5× | < 250 | PASS |
| R17 | Analytics | 5.716 | 71.015 | 12.4× | < 5000 | PASS |
| R18 | Analytics | 5.798 | 51.074 | 8.8× | < 5000 | PASS |
| R19 | Analytics | 16.198 | 1108.879 | 68.5× | < 5000 | PASS |
| R20 | Analytics | 2.567 | 41.093 | 16.0× | < 5000 | PASS; Met; plan scans only the June 2026 partition. |
| R21 | Interactive | 0.913 | 34.007 | 37.2× | < 250 | PASS |
| R22 | Interactive | 6.023 | 15.600 | 2.6× | < 250 | PASS |
| R23 | Interactive | 0.739 | 31.323 | 42.4× | < 250 | PASS |
| R24 | Analytics | 22.816 | 344.985 | 15.1× | < 5000 | PASS |
| R25 | Analytics | 119.361 | 1608.345 | 13.5× | < 5000 | PASS |
| W01 | Learner-facing | 0.855 | 1.259 | 1.5× | < 5 | PASS |
| W02 | Learner-facing | 0.453 | 2.966 | 6.5× | < 5 | PASS; Met; ID-only UPDATE checks all partition indexes. |
| W03 | Learner-facing | 0.561 | 0.729 | 1.3× | < 5 | PASS |
| W04 | Batch | 7.785 | 277.655 | 35.7× | < 1000 | PASS |
| W05 | Batch | 42.875 | 1162.576 | 27.1× | < 1000 | MISS: 750,000 enrollment rows aggregated; 79,757 badge inserts trigger FK/unique checks. Needs further tuning. |

The 1,000 ms batch-job limit is the only average target missed: W05 averages 1,162.576 ms. All other query averages meet their stated targets.

## Growth analysis

Growth here compares two runs on the same PostgreSQL instance but different database sizes; it is descriptive, not a controlled scale-factor experiment for every query.

- **Stayed near the seed time (≤2×):** R01, R02, R03, W01, W03. These are selective lookups or small writes; indexes keep their work bounded.
- **Grew 2–10×:** R05, R10, R11, R12, R18, R22, W02. These touch a limited set of records or use indexed paths, though more partitions and larger indexes add overhead.
- **Grew 10–30×:** R04, R06, R08, R14, R15, R17, R20, R24, R25, W05. These scan or aggregate a sizeable fraction of activity or attempts. R20 still prunes to a single month.
- **Grew over 30×:** R07, R09, R13, R16, R19, R21, R23, W04. These scan broad ranges or many records; the large-data plans show the increased work. R07, R19, and W04 remain within their looser query-group targets.

## Partitioning and plan observations

`lesson_attempts` is partitioned by monthly `RANGE (started_at)` from January 2025 through December 2026, with a default partition. The loaded timestamps span 2025-01-01 through 2026-06-30; 3,608,300 rows were preserved and the default partition is empty. R20’s saved plan scans only `lesson_attempts_202606`, demonstrating partition pruning for its June date range.

R04 still applies `DATE()` to `started_at`; its plan includes many partitions rather than pruning to June. Its mean (2.492 ms) is below the 5 ms target, but the largest of the three runs was 7.123 ms. Rewriting that predicate to a half-open timestamp range would allow pruning. W02’s subquery is date-bounded, but the outer update searches partitions by attempt ID because the partitioned primary key includes `started_at`.

The partitioned primary key is `(attempt_id, started_at)`, as PostgreSQL requires the partition key to be part of a unique or primary key. Therefore this table does not enforce global uniqueness of `attempt_id` alone. The loaded file has unique IDs; a separate ID registry or globally unique ID scheme is needed if the database must enforce this invariant across partitions.

W05 is the only target miss. Its plan aggregates all 750,000 enrollment rows and attempts 79,757 learner-achievement inserts; foreign-key and conflict checks add substantial time. The current run identifies the bottleneck but does not include a W05 optimization or before/after timing.

Raw plans: `benchmarks/results/large/` and `benchmarks/results/optimized/`. For partition pruning, see `benchmarks/results/large/R20.txt`; for the W05 bottleneck, see `benchmarks/results/large/W05.txt`.

## Storage

Measured with `pg_database_size()` and summed table/index relation sizes after loading and indexing. PostgreSQL’s database total also includes catalogs and other overhead, so the table and index figures do not sum exactly to the database total.

| Database | Table storage | Index storage | Total database size |
|---|---:|---:|---:|
| Seed (`duolingo_seed`) | 32 MiB | 65 MiB | 104 MiB |
| Large partitioned (`duolingo_large`) | 582 MiB | 1,289 MiB | 1,881 MiB |

The large table storage is about 18.2× the seed table storage; index storage is about 19.8×; total database size is about 18.1×.

## 100× architecture and operations

- **Partitioning:** Keep monthly `RANGE` partitions on `lesson_attempts.started_at`; create future partitions ahead of time, monitor default-partition growth, and archive/detach old months only when retention rules permit. The June R20 plan demonstrates pruning. Queries without a time predicate (for example R25) still scan every relevant partition.
- **Sharding:** Hash-shard learner-centric data by `learner_id` to keep enrollments, activity, attempts, and achievements for one learner together. League cohorts span learners, so league-close and leaderboard queries need fan-out across shards or a dedicated cohort/weekly leaderboard service that stores pre-aggregated weekly XP and rank inputs.
- **Replicas and caching:** Send long-running read-only analytics (R07–R10, R14–R20, R24–R25) to read replicas when replication lag is acceptable. Cache course paths, leaderboards, and daily summaries with short TTLs. Keep W01–W05 on the primary; sign-in and immediate post-lesson reads should use the primary or a read-your-writes path.
- **Maintenance:** Tune autovacuum per active partition based on update volume; run `ANALYZE` after bulk loads and new partition creation. Monitor dead tuples and index bloat, detach/archive old partitions according to retention, and refresh daily XP/lesson summary tables on a defined schedule.

## Conclusion

Monthly partitioning preserves all loaded attempt rows and allows date-bounded analytics such as R20 to prune to one partition. Twenty-nine of thirty average query times meet the project targets. W05 remains above its batch target, R04 misses pruning, and broad-history queries still read many partitions. Before claiming 100× readiness, tune W05, make R04 sargable, measure unpartitioned versus partitioned large data under the same workload, and verify the exact optimized SQL file is synced into the submission workspace.
