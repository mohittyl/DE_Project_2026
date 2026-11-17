-- Phase 4 secondary indexes for the supplied PostgreSQL workload.
-- Run after sql/01_schema.sql and loading the data. PK/UNIQUE indexes are
-- already created by the constraints in 01_schema.sql.
SET search_path TO duolingo;

-- The UNIQUE (course_id, unit_no) constraint on units already provides this
-- access path; avoid a duplicate secondary index here.
-- Child-side foreign keys and common learner-scoped lookups.
CREATE INDEX idx_lessons_unit_order
    ON lessons (unit_id, lesson_no) INCLUDE (lesson_id, lesson_type, xp_value);
CREATE INDEX idx_enrollments_course
    ON enrollments (course_id) INCLUDE (learner_id, enrolled_at, total_xp);
CREATE INDEX idx_enrollments_learner_xp
    ON enrollments (learner_id, total_xp DESC) INCLUDE (course_id, enrolled_at, is_active);
CREATE INDEX idx_learners_referrer
    ON learners (referred_by);

-- Attempts: learner progress, lesson reports, date-filtered metrics and feed.
CREATE INDEX idx_attempts_learner_lesson_completed
    ON lesson_attempts (learner_id, lesson_id)
    WHERE completed_at IS NOT NULL;
CREATE INDEX idx_attempts_learner_started
    ON lesson_attempts (learner_id, started_at);
CREATE INDEX idx_attempts_lesson_completed
    ON lesson_attempts (lesson_id)
    INCLUDE (mistakes, completed_at, hearts_lost);
CREATE INDEX idx_attempts_started_desc
    ON lesson_attempts (started_at DESC)
    INCLUDE (attempt_id, learner_id, lesson_id, xp_earned);
CREATE INDEX idx_attempts_completed_started
    ON lesson_attempts (started_at)
    WHERE completed_at IS NOT NULL;
CREATE INDEX idx_attempts_unfinished_started_desc
    ON lesson_attempts (started_at DESC, attempt_id DESC)
    WHERE completed_at IS NULL;

-- Activity feeds, date ranges, freeze reports, and learner activity checks.
CREATE INDEX idx_daily_activity_date_xp
    ON daily_activity (activity_date, learner_id)
    WHERE xp > 0;
CREATE INDEX idx_daily_activity_freeze_date
    ON daily_activity (activity_date, learner_id)
    WHERE used_streak_freeze;

-- Leaderboard and week-close access. The primary key already supports the
-- learner + week lookup used to find a learner's cohort.
CREATE INDEX idx_league_week_cohort_xp
    ON league_memberships (week_start, cohort_id, weekly_xp DESC, learner_id);
CREATE INDEX idx_league_week_tier
    ON league_memberships (week_start, tier)
    INCLUDE (result);

CREATE INDEX idx_learner_achievements_recent
    ON learner_achievements (learner_id, earned_at DESC)
    INCLUDE (achievement_id);

-- Username is constrained to ASCII letters, digits and underscore, making
-- lower(username) prefix matching equivalent to the workload's ILIKE prefix.
CREATE INDEX idx_learners_username_lower_prefix
    ON learners (lower(username) text_pattern_ops)
    INCLUDE (learner_id, country_code);

-- Paid-country cohort selection for R23.
CREATE INDEX idx_learners_paid_country
    ON learners (country_code, subscription, learner_id)
    WHERE subscription IN ('SUPER', 'MAX');
