# CP2 — Baseline Query Timings

## Methodology

- Database: `duolingo_db`
- Schema: `duolingo`
- Workload: `queries/workload_30.sql`
- Queries: 25 READ and 5 WRITE
- Each query was executed 3 times; Run 1, Run 2, and Run 3 show the measured execution times.
- Average timings are the arithmetic mean of the three runs, in milliseconds.
- Execution plans were collected using `EXPLAIN (ANALYZE, BUFFERS)`.
- Write queries were executed inside transactions and rolled back.

## Results

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan nodes |
|---|---|---:|---:|---:|---:|---|
| R01 | READ | 0.293 | 0.158 | 0.151 | 0.201 | Seq Scan on units \| Seq Scan on courses \| Index Scan using uq_lessons_unit_lesson on lessons |
| R02 | READ | 0.065 | 0.061 | 0.057 | 0.061 | Index Scan using enrollments_pkey on enrollments \| Seq Scan on courses |
| R03 | READ | 0.114 | 0.108 | 0.099 | 0.107 | Index Only Scan using daily_activity_pkey on daily_activity |
| R04 | READ | 5.239 | 4.875 | 4.355 | 4.823 | Index Scan using learners_pkey on learners \| Seq Scan on lesson_attempts |
| R05 | READ | 0.897 | 0.884 | 0.864 | 0.882 | Index Scan using league_memberships_pkey on league_memberships \| Seq Scan on league_memberships \| Index Scan using learners_pkey on learners |
| R06 | READ | 5.827 | 5.448 | 5.341 | 5.539 | Index Scan using uq_units_course_unit on units \| Index Scan using uq_lessons_unit_lesson on lessons \| Seq Scan on lesson_attempts |
| R07 | READ | 14.817 | 14.855 | 15.090 | 14.921 | Seq Scan on lesson_attempts \| Seq Scan on lessons \| Seq Scan on units |
| R08 | READ | 15.726 | 15.546 | 15.798 | 15.690 | Seq Scan on lesson_attempts \| Seq Scan on lessons |
| R09 | READ | 4.375 | 4.045 | 4.040 | 4.153 | Seq Scan on daily_activity |
| R10 | READ | 4.115 | 4.147 | 4.139 | 4.134 | Seq Scan on daily_activity \| Index Scan using learners_pkey on learners |
| R11 | READ | 0.027 | 0.023 | 0.027 | 0.026 | Index Scan using learners_username_key on learners |
| R12 | READ | 0.039 | 0.038 | 0.036 | 0.038 | Index Scan using learner_achievements_pkey on learner_achievements \| Seq Scan on achievements |
| R13 | READ | 3.929 | 4.224 | 3.981 | 4.045 | Seq Scan on learners |
| R14 | READ | 1.799 | 1.794 | 1.725 | 1.773 | Seq Scan on league_memberships |
| R15 | READ | 1.307 | 1.304 | 1.295 | 1.302 | Seq Scan on learners \| Index Scan using daily_activity_pkey on daily_activity |
| R16 | READ | 2.610 | 2.785 | 2.556 | 2.650 | Index Scan using learners_username_key on learners |
| R17 | READ | 12.593 | 12.723 | 12.467 | 12.594 | Seq Scan on lesson_attempts |
| R18 | READ | 5.565 | 5.621 | 5.581 | 5.589 | Seq Scan on enrollments \| Seq Scan on courses |
| R19 | READ | 1476.085 | 1438.062 | 1413.326 | 1442.491 | Index Scan using uq_units_course_unit on units \| Index Scan using uq_lessons_unit_lesson on lessons \| Seq Scan on lesson_attempts |
| R20 | READ | 8.363 | 7.724 | 7.806 | 7.964 | Seq Scan on lesson_attempts |
| R21 | READ | 2.204 | 2.092 | 2.123 | 2.140 | Index Only Scan using daily_activity_pkey on daily_activity |
| R22 | READ | 29.930 | 29.175 | 29.722 | 29.609 | Seq Scan on lesson_attempts |
| R23 | READ | 5.261 | 5.361 | 5.247 | 5.290 | Seq Scan on daily_activity \| Seq Scan on learners |
| R24 | READ | 21.983 | 21.914 | 21.670 | 21.856 | Seq Scan on lesson_attempts \| Seq Scan on lessons \| Seq Scan on units |
| R25 | READ | 109.606 | 109.787 | 110.407 | 109.933 | Seq Scan on lesson_attempts \| Seq Scan on learners |
| W01 | WRITE | 0.493 | 0.490 | 0.449 | 0.477 | (no scan) |
| W02 | WRITE | 0.633 | 0.538 | 0.520 | 0.564 | Index Scan using lesson_attempts_pkey on lesson_attempts |
| W03 | WRITE | 0.393 | 0.371 | 0.359 | 0.374 | (no scan) |
| W04 | WRITE | 5.848 | 4.712 | 4.849 | 5.136 | Seq Scan on league_memberships |
| W05 | WRITE | 43.130 | 33.803 | 32.874 | 36.602 | Seq Scan on achievements \| Seq Scan on enrollments |

## Observations

- The workload contains 25 read queries and 5 write queries.
- Fastest query by average time: R11 (0.026 ms).
- Slowest query by average time: R19 (1442.491 ms).
- Slowest read query: R19.
- Slowest write query: W05.
- Sequential scans appear in several query plans; these will be reviewed during the optimization checkpoint.

## Raw execution plans

The individual execution-plan files for all 30 queries are stored in `benchmarks/results/before/`.

The machine-readable timing summary is stored in `benchmarks/results/baseline/summary.csv`.
