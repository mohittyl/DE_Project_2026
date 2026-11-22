-- Phase 5: convert a loaded lesson_attempts table to monthly RANGE partitions.
-- Run once after loading large_data into the unpartitioned schema. Then run
-- sql/05_indexes.sql and ANALYZE. The old table is copied transactionally.
SET search_path TO duolingo;

BEGIN;

LOCK TABLE lesson_attempts IN ACCESS EXCLUSIVE MODE;
ALTER TABLE lesson_attempts RENAME TO lesson_attempts_unpartitioned;

-- PostgreSQL requires every unique/primary key on a partitioned table to
-- include its partition key. The old global PRIMARY KEY (attempt_id) therefore
-- becomes (attempt_id, started_at); global uniqueness of attempt_id alone is
-- not enforced by this partitioned table.
CREATE TABLE lesson_attempts (
    attempt_id bigint NOT NULL,
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    lesson_id integer NOT NULL REFERENCES lessons(lesson_id) ON DELETE RESTRICT,
    started_at timestamptz NOT NULL,
    completed_at timestamptz,
    mistakes smallint NOT NULL DEFAULT 0,
    hearts_lost smallint NOT NULL DEFAULT 0,
    xp_earned smallint NOT NULL DEFAULT 0,
    is_perfect boolean NOT NULL DEFAULT false,
    device varchar(7) NOT NULL,
    CONSTRAINT lesson_attempts_partitioned_pkey PRIMARY KEY (attempt_id, started_at),
    CONSTRAINT attempts_mistakes_nonnegative CHECK (mistakes >= 0),
    CONSTRAINT attempts_hearts_nonnegative CHECK (hearts_lost >= 0),
    CONSTRAINT attempts_hearts_not_above_mistakes CHECK (hearts_lost <= mistakes),
    CONSTRAINT attempts_xp_nonnegative CHECK (xp_earned >= 0),
    CONSTRAINT attempts_perfect_no_mistakes CHECK (NOT is_perfect OR mistakes = 0),
    CONSTRAINT attempts_unfinished_no_xp CHECK (completed_at IS NOT NULL OR xp_earned = 0),
    CONSTRAINT attempts_completion_after_start CHECK (completed_at IS NULL OR completed_at >= started_at),
    CONSTRAINT attempts_device CHECK (device IN ('ANDROID','IOS','WEB'))
) PARTITION BY RANGE (started_at);

-- Monthly boundaries use India local time, matching the timestamps in the
-- supplied CSV exports. Monthly partitions help date-bounded queries prune
-- most of the attempts table. The DEFAULT partition catches other years.
DO $$
DECLARE
    month_start date := DATE '2025-01-01';
    lower_bound timestamptz;
    upper_bound timestamptz;
    partition_name text;
BEGIN
    WHILE month_start < DATE '2027-01-01' LOOP
        lower_bound := month_start::timestamp AT TIME ZONE 'Asia/Kolkata';
        upper_bound := (month_start + INTERVAL '1 month') AT TIME ZONE 'Asia/Kolkata';
        partition_name := 'lesson_attempts_' || to_char(month_start, 'YYYYMM');

        EXECUTE format(
            'CREATE TABLE duolingo.%I PARTITION OF duolingo.lesson_attempts '
            'FOR VALUES FROM (%L) TO (%L)',
            partition_name, lower_bound, upper_bound
        );
        month_start := (month_start + INTERVAL '1 month')::date;
    END LOOP;
END
$$;

CREATE TABLE lesson_attempts_default
    PARTITION OF lesson_attempts DEFAULT;

INSERT INTO lesson_attempts (
    attempt_id, learner_id, lesson_id, started_at, completed_at,
    mistakes, hearts_lost, xp_earned, is_perfect, device
)
SELECT
    attempt_id, learner_id, lesson_id, started_at, completed_at,
    mistakes, hearts_lost, xp_earned, is_perfect, device
FROM lesson_attempts_unpartitioned;

DO $$
DECLARE
    source_count bigint;
    partitioned_count bigint;
BEGIN
    SELECT count(*) INTO source_count FROM lesson_attempts_unpartitioned;
    SELECT count(*) INTO partitioned_count FROM lesson_attempts;
    IF source_count <> partitioned_count THEN
        RAISE EXCEPTION 'Partition migration row-count mismatch: source %, partitioned %',
            source_count, partitioned_count;
    END IF;
END
$$;

DROP TABLE lesson_attempts_unpartitioned;

-- Examples for checking partition pruning after running this migration.
-- Each query should touch only the matching monthly partition in EXPLAIN.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT count(*) FROM lesson_attempts
-- WHERE started_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
--   AND started_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';
--
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT count(*) FROM lesson_attempts
-- WHERE started_at >= TIMESTAMPTZ '2026-06-30 00:00:00+05:30'
--   AND started_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

ANALYZE lesson_attempts;
COMMIT;

-- Rebuild workload indexes after partitioning:
-- psql -d <large_database> -f sql/05_indexes.sql
