-- Duolingo DBMS project schema. PostgreSQL 15+.
CREATE SCHEMA duolingo;
SET search_path TO duolingo;

CREATE TABLE languages (
    language_code varchar(2) PRIMARY KEY,
    language_name varchar(40) NOT NULL UNIQUE,
    CONSTRAINT languages_code_format CHECK (language_code ~ '^[a-z]{2}$')
);

CREATE TABLE courses (
    course_id integer PRIMARY KEY,
    from_lang varchar(2) NOT NULL REFERENCES languages(language_code) ON DELETE RESTRICT,
    learning_lang varchar(2) NOT NULL REFERENCES languages(language_code) ON DELETE RESTRICT,
    title varchar(120) NOT NULL,
    launched_on date NOT NULL,
    CONSTRAINT courses_distinct_languages CHECK (from_lang <> learning_lang),
    CONSTRAINT courses_language_pair_unique UNIQUE (from_lang, learning_lang)
);

CREATE TABLE units (
    unit_id integer PRIMARY KEY,
    course_id integer NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
    unit_no smallint NOT NULL,
    title varchar(100) NOT NULL,
    cefr_level varchar(2) NOT NULL,
    CONSTRAINT units_positive_number CHECK (unit_no > 0),
    CONSTRAINT units_cefr_level CHECK (cefr_level IN ('A1','A2','B1','B2','C1')),
    CONSTRAINT units_course_number_unique UNIQUE (course_id, unit_no)
);

CREATE TABLE lessons (
    lesson_id integer PRIMARY KEY,
    unit_id integer NOT NULL REFERENCES units(unit_id) ON DELETE RESTRICT,
    lesson_no smallint NOT NULL,
    lesson_type varchar(12) NOT NULL,
    xp_value smallint NOT NULL,
    CONSTRAINT lessons_positive_number CHECK (lesson_no > 0),
    CONSTRAINT lessons_type CHECK (lesson_type IN ('LEARN','PRACTICE','STORY','LEGENDARY')),
    CONSTRAINT lessons_xp_nonnegative CHECK (xp_value >= 0),
    CONSTRAINT lessons_unit_number_unique UNIQUE (unit_id, lesson_no)
);

CREATE TABLE learners (
    learner_id integer PRIMARY KEY,
    username varchar(40) NOT NULL UNIQUE,
    email varchar(254) NOT NULL UNIQUE,
    country_code varchar(2) NOT NULL,
    daily_goal_xp smallint NOT NULL,
    subscription varchar(8) NOT NULL,
    referred_by integer REFERENCES learners(learner_id) ON DELETE SET NULL,
    joined_at timestamptz NOT NULL,
    CONSTRAINT learners_username_format CHECK (username ~ '^[A-Za-z0-9_]+$'),
    CONSTRAINT learners_country_format CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT learners_daily_goal CHECK (daily_goal_xp IN (10,20,30,50)),
    CONSTRAINT learners_subscription CHECK (subscription IN ('FREE','SUPER','MAX')),
    CONSTRAINT learners_not_self_referred CHECK (referred_by IS NULL OR referred_by <> learner_id)
);

CREATE TABLE enrollments (
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    course_id integer NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
    enrolled_at timestamptz NOT NULL,
    total_xp integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    CONSTRAINT enrollments_xp_nonnegative CHECK (total_xp >= 0),
    CONSTRAINT enrollments_pk PRIMARY KEY (learner_id, course_id)
);

CREATE TABLE lesson_attempts (
    attempt_id bigint PRIMARY KEY,
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    lesson_id integer NOT NULL REFERENCES lessons(lesson_id) ON DELETE RESTRICT,
    started_at timestamptz NOT NULL,
    completed_at timestamptz,
    mistakes smallint NOT NULL DEFAULT 0,
    hearts_lost smallint NOT NULL DEFAULT 0,
    xp_earned smallint NOT NULL DEFAULT 0,
    is_perfect boolean NOT NULL DEFAULT false,
    device varchar(7) NOT NULL,
    CONSTRAINT attempts_mistakes_nonnegative CHECK (mistakes >= 0),
    CONSTRAINT attempts_hearts_nonnegative CHECK (hearts_lost >= 0),
    CONSTRAINT attempts_hearts_not_above_mistakes CHECK (hearts_lost <= mistakes),
    CONSTRAINT attempts_xp_nonnegative CHECK (xp_earned >= 0),
    CONSTRAINT attempts_perfect_no_mistakes CHECK (NOT is_perfect OR mistakes = 0),
    CONSTRAINT attempts_unfinished_no_xp CHECK (completed_at IS NOT NULL OR xp_earned = 0),
    CONSTRAINT attempts_completion_after_start CHECK (completed_at IS NULL OR completed_at >= started_at),
    CONSTRAINT attempts_device CHECK (device IN ('ANDROID','IOS','WEB'))
);

CREATE TABLE daily_activity (
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    activity_date date NOT NULL,
    xp integer NOT NULL DEFAULT 0,
    lessons_completed smallint NOT NULL DEFAULT 0,
    used_streak_freeze boolean NOT NULL DEFAULT false,
    CONSTRAINT daily_activity_xp_nonnegative CHECK (xp >= 0),
    CONSTRAINT daily_activity_lessons_nonnegative CHECK (lessons_completed >= 0),
    CONSTRAINT daily_activity_freeze_zero_xp CHECK (NOT used_streak_freeze OR xp = 0),
    CONSTRAINT daily_activity_pk PRIMARY KEY (learner_id, activity_date)
);

CREATE TABLE league_memberships (
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    week_start date NOT NULL,
    tier varchar(10) NOT NULL,
    cohort_id integer NOT NULL,
    weekly_xp integer NOT NULL DEFAULT 0,
    final_rank smallint,
    result varchar(8),
    CONSTRAINT league_tier CHECK (tier IN ('BRONZE','SILVER','GOLD','SAPPHIRE','EMERALD','AMETHYST','RUBY','DIAMOND')),
    CONSTRAINT league_week_monday CHECK (EXTRACT(ISODOW FROM week_start) = 1),
    CONSTRAINT league_xp_nonnegative CHECK (weekly_xp >= 0),
    CONSTRAINT league_rank_range CHECK (final_rank IS NULL OR final_rank BETWEEN 1 AND 30),
    CONSTRAINT league_result_value CHECK (result IS NULL OR result IN ('PROMOTED','DEMOTED','STAYED')),
    CONSTRAINT league_rank_result_together CHECK ((final_rank IS NULL) = (result IS NULL)),
    CONSTRAINT league_membership_pk PRIMARY KEY (learner_id, week_start)
);

CREATE TABLE achievements (
    achievement_id integer PRIMARY KEY,
    code varchar(40) NOT NULL UNIQUE,
    name varchar(80) NOT NULL
);

CREATE TABLE learner_achievements (
    learner_id integer NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    achievement_id integer NOT NULL REFERENCES achievements(achievement_id) ON DELETE RESTRICT,
    earned_at timestamptz NOT NULL,
    CONSTRAINT learner_achievements_pk PRIMARY KEY (learner_id, achievement_id)
);

-- No secondary indexes are created in Phase 2. PK/UNIQUE constraints create
-- their normal PostgreSQL backing indexes; additional tuning is deferred.
