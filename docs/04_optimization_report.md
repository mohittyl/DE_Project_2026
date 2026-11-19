# Phase 4 — Query Optimization Report

## 1. Introduction

The objective of this phase was to optimize the 30 SQL queries in `queries/workload_30.sql` using indexes and query rewriting.

The main optimization techniques used were:

- Composite and covering indexes.
- Partial indexes.
- Date-range filtering.
- Replacing correlated subqueries with JOINs and aggregation.
- Using `NOT EXISTS` instead of `NOT IN` to handle NULL values.

The indexes are defined in `sql/05_indexes.sql`, and optimized queries are stored in `sql/06_optimized_queries.sql`.

## 2. Benchmark Methodology

| Property | Value |
|---|---|
| Database | PostgreSQL 18.6 |
| Database name | duolingo_db |
| Schema | duolingo |
| OS | macOS (Apple Silicon) |
| Dataset | Seed dataset |
| Lesson attempts | 188,300 |
| Learners | 30,000 |
| Total queries | 30 |
| Read queries | 25 |
| Write queries | 5 |

Each optimized query was executed three times using:

```bash
./benchmarks/run_benchmark.sh duolingo_db optimized 3 sql/06_optimized_queries.sql
```

Execution plans were collected using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

Write queries were executed inside transactions and rolled back.

**Baseline source:** The original recorded timings from `benchmarks/results/baseline/summary.csv` were used. Optimized timings were collected on the local PostgreSQL environment. The two sets of measurements come from separate benchmark runs.

## 3. Optimization Results

All execution times are in milliseconds.

| Query | Before (ms) | After (ms) | Improvement |
|---|---:|---:|---:|
| R01 | 0.201 | 0.178 | 11.44% |
| R02 | 0.061 | 0.072 | -18.03% |
| R03 | 0.107 | 0.088 | 17.76% |
| R04 | 4.823 | 0.080 | 98.34% |
| R05 | 0.882 | 0.078 | 91.16% |
| R06 | 5.539 | 0.071 | 98.72% |
| R07 | 14.921 | 7.259 | 51.35% |
| R08 | 15.690 | 15.820 | -0.83% |
| R09 | 4.153 | 0.795 | 80.86% |
| R10 | 4.134 | 3.367 | 18.55% |
| R11 | 0.026 | 0.016 | 38.46% |
| R12 | 0.038 | 0.104 | -173.68% |
| R13 | 4.045 | 3.525 | 12.86% |
| R14 | 1.773 | 1.018 | 42.58% |
| R15 | 1.302 | 1.346 | -3.38% |
| R16 | 2.650 | 0.751 | 71.66% |
| R17 | 12.594 | 7.480 | 40.61% |
| R18 | 5.589 | 5.711 | -2.18% |
| R19 | 1442.491 | 13.685 | 99.05% |
| R20 | 7.964 | 2.275 | 71.43% |
| R21 | 2.140 | 2.247 | -5.00% |
| R22 | 29.609 | 5.613 | 81.04% |
| R23 | 5.290 | 0.573 | 89.17% |
| R24 | 21.856 | 22.532 | -3.09% |
| R25 | 109.933 | 106.357 | 3.25% |
| W01 | 0.477 | 0.732 | -53.46% |
| W02 | 0.564 | 0.198 | 64.89% |
| W03 | 0.374 | 0.488 | -30.48% |
| W04 | 5.136 | 6.295 | -22.57% |
| W05 | 36.602 | 36.503 | 0.27% |

Improvement formula:

\[
\frac{\text{Before}-\text{After}}{\text{Before}}\times100
\]

Negative values indicate that the optimized query became slower.

### 3.1 Major improvements

| Query | Optimization | Improvement |
|---|---|---:|
| R19 | Replaced correlated subqueries with JOIN and aggregation | 99.05% |
| R06 | Added partial index for completed lesson attempts | 98.72% |
| R04 | Added learner and start-time composite index | 98.34% |
| R05 | Added composite index for league leaderboard | 91.16% |
| R23 | Added indexes for paid learners and daily activity | 89.17% |

### 3.2 Queries with limited improvement

Some queries became slightly slower.

- R02, R12, R15 and R18 were already relatively fast.
- R08 and R24 require aggregation over a large number of attempts.
- R25 processes most lesson attempts and groups them by country and hour.
- W01, W03 and W04 experienced additional write overhead because of index maintenance.

Sequential scans can still be efficient when most rows of a table must be processed.

## 4. Execution Plan Analysis

The following five queries showed major improvements.

### R19 — Curriculum report

**Before:**

```text
Index Scan on units
Index Scan on lessons
Seq Scan on lesson_attempts
```

**After:**

```text
Seq Scan on lessons
Seq Scan on units
Index Scan using idx_attempts_lesson_completed
on lesson_attempts
```

The original query used two correlated subqueries for every lesson. The optimized query uses a `LEFT JOIN` and aggregation to calculate both values together.

**Improvement: 99.05%**

### R06 — Next incomplete lesson

**Before:**

```text
Index Scan on units
Index Scan on lessons
Seq Scan on lesson_attempts
```

**After:**

```text
Index Scan on units
Index Only Scan using idx_lessons_unit_order on lessons
Index Only Scan using idx_attempts_learner_lesson_completed
on lesson_attempts
```

The partial index makes it faster to check completed attempts for a learner.

**Improvement: 98.72%**

### R04 — Daily XP calculation

**Before:**

```text
Index Scan using learners_pkey on learners
Seq Scan on lesson_attempts
```

**After:**

```text
Index Scan using learners_pkey on learners
Bitmap Heap Scan on lesson_attempts
Bitmap Index Scan using idx_attempts_learner_started
```

The composite index helps find attempts belonging to the required learner and date.

**Improvement: 98.34%**

### R05 — League leaderboard

**Before:**

```text
Index Scan on league_memberships
Seq Scan on league_memberships
Index Scan on learners
```

**After:**

```text
Index Scan on league_memberships
Index Only Scan using idx_league_week_cohort_xp
on league_memberships
Index Scan on learners
```

The composite index supports filtering by week and cohort and retrieving the leaderboard in XP order.

**Improvement: 91.16%**

### R23 — Paid learners in India

**Before:**

```text
Seq Scan on daily_activity
Seq Scan on learners
```

**After:**

```text
Index Only Scan using idx_daily_activity_date_xp
on daily_activity
Index Only Scan using idx_learners_paid_country
on learners
```

The indexes help filter active learners and paid subscriptions.

**Improvement: 89.17%**

## 5. Indexes Created

All 17 secondary indexes are defined in `sql/05_indexes.sql`.

| Index | Table | Purpose |
|---|---|---|
| idx_lessons_unit_order | lessons | Ordered lesson retrieval |
| idx_enrollments_course | enrollments | Course-based enrollment lookups |
| idx_enrollments_learner_xp | enrollments | Learner enrollment and XP sorting |
| idx_learners_referrer | learners | Referral checks |
| idx_attempts_learner_lesson_completed | lesson_attempts | Completed lesson checks |
| idx_attempts_learner_started | lesson_attempts | Learner and date filtering |
| idx_attempts_lesson_completed | lesson_attempts | Lesson-level aggregation |
| idx_attempts_started_desc | lesson_attempts | Newest-first attempt retrieval |
| idx_attempts_completed_started | lesson_attempts | Completed attempt filtering |
| idx_attempts_unfinished_started_desc | lesson_attempts | Unfinished attempt lookup |
| idx_daily_activity_date_xp | daily_activity | Active learner filtering |
| idx_daily_activity_freeze_date | daily_activity | Streak freeze filtering |
| idx_league_week_cohort_xp | league_memberships | League leaderboard |
| idx_league_week_tier | league_memberships | Promotion and demotion reports |
| idx_learner_achievements_recent | learner_achievements | Recent achievements |
| idx_learners_username_lower_prefix | learners | Username prefix search |
| idx_learners_paid_country | learners | Paid learners by country |

## 6. Index Storage Analysis

Index sizes were collected using `pg_relation_size()`.

| Index | Table | Index Size | Table Size |
|---|---|---:|---:|
| idx_attempts_started_desc | lesson_attempts | 9136 kB | 14 MB |
| idx_attempts_lesson_completed | lesson_attempts | 7288 kB | 14 MB |
| idx_attempts_learner_started | lesson_attempts | 5824 kB | 14 MB |
| idx_attempts_completed_started | lesson_attempts | 3664 kB | 14 MB |
| idx_daily_activity_date_xp | daily_activity | 3656 kB | 8448 kB |
| idx_attempts_learner_lesson_completed | lesson_attempts | 3584 kB | 14 MB |
| idx_learner_achievements_recent | learner_achievements | 3080 kB | 1688 kB |
| idx_enrollments_learner_xp | enrollments | 1824 kB | 1920 kB |
| idx_enrollments_course | enrollments | 1496 kB | 1920 kB |
| idx_learners_username_lower_prefix | learners | 1360 kB | 2944 kB |
| idx_league_week_tier | league_memberships | 1200 kB | 2248 kB |
| idx_league_week_cohort_xp | league_memberships | 920 kB | 2248 kB |
| idx_attempts_unfinished_started_desc | lesson_attempts | 680 kB | 14 MB |
| idx_learners_referrer | learners | 328 kB | 2944 kB |
| idx_learners_paid_country | learners | 152 kB | 2944 kB |
| idx_lessons_unit_order | lessons | 88 kB | 96 kB |
| idx_daily_activity_freeze_date | daily_activity | 64 kB | 8448 kB |

**Total secondary index storage: approximately 43.3 MiB.**

The largest indexes belong to `lesson_attempts`, which is frequently accessed by the workload.

Partial indexes help reduce storage by indexing only rows that satisfy their conditions.

## 7. Write Overhead

Indexes require additional maintenance during INSERT, UPDATE and DELETE operations.

| Query | Before (ms) | After (ms) | Observation |
|---|---:|---:|---|
| W01 | 0.477 | 0.732 | 53.46% slower |
| W02 | 0.564 | 0.198 | 64.89% faster |
| W03 | 0.374 | 0.488 | 30.48% slower |
| W04 | 5.136 | 6.295 | 22.57% slower |
| W05 | 36.602 | 36.503 | 0.27% faster |

W01 and W03 perform inserts, while W04 updates league membership records. These operations may require additional index maintenance.

W02 became faster because the partial index `idx_attempts_unfinished_started_desc` helps locate unfinished attempts.

The write overhead should be considered when deciding whether an index is worth keeping.

## 8. NULL Handling in R13

The original query uses `NOT IN`:

```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE l.learner_id NOT IN (
    SELECT r.referred_by
    FROM learners r
);
```

The `referred_by` column allows NULL values.

When the subquery returns NULL, `NOT IN` can evaluate to UNKNOWN, causing the original query to return no matching learners.

The optimized query uses `NOT EXISTS`:

```sql
SELECT l.learner_id, l.username
FROM learners l
WHERE NOT EXISTS (
    SELECT 1
    FROM learners r
    WHERE r.referred_by = l.learner_id
);
```

`NOT EXISTS` correctly identifies learners who have not referred anyone.

This is an intentional correctness fix. Its result is not necessarily identical to the original query's incorrect empty result.

**Note:** A separate row-by-row equivalence check has not yet been performed for all rewritten queries. R13 is an intentional correction rather than a strictly result-identical rewrite.

## 9. Conclusion

The optimization phase improved several important queries, particularly learner-specific lookups, lesson completion checks, date filtering, league leaderboards and curriculum reports.

The largest improvement was R19, which decreased from 1442.491 ms to 13.685 ms (99.05%).

Other major improvements included R06, R04, R05 and R23.

The indexes improved several execution plans but also introduced additional storage and write-maintenance costs. Queries that need to process most of the dataset still use sequential scans.

The R13 correction also demonstrates the importance of understanding SQL NULL behaviour.

The optimized queries and indexes provide a foundation for the Phase 5 scalability testing.

## 10. Benchmark Files

```text
benchmarks/
└── results/
    ├── baseline/
    │   └── summary.csv
    ├── before/
    │   ├── summary.csv
    │   └── R01.txt ... W05.txt
    └── optimized/
        ├── summary.csv
        └── R01.txt ... W05.txt
```

SQL files:

```text
sql/
├── 05_indexes.sql
└── 06_optimized_queries.sql
```