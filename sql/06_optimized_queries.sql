-- Phase 4 query set. Execute the statement under the matching workload ID.
-- Results are kept equivalent to queries/workload_30.sql.
SET search_path TO duolingo;

-- @R01
SELECT u.unit_no, u.title, u.cefr_level, l.lesson_no, l.lesson_type, l.xp_value
FROM courses c
JOIN units u ON u.course_id = c.course_id
JOIN lessons l ON l.unit_id = u.unit_id
WHERE c.from_lang = 'en' AND c.learning_lang = 'es'
ORDER BY u.unit_no, l.lesson_no;

-- @R02
SELECT c.title, e.total_xp, e.enrolled_at, e.is_active
FROM enrollments e JOIN courses c ON c.course_id = e.course_id
WHERE e.learner_id = 1042
ORDER BY e.total_xp DESC;

-- @R03
WITH days AS (
    SELECT activity_date,
           activity_date - row_number() OVER (ORDER BY activity_date)::int AS grp
    FROM daily_activity
    WHERE learner_id = 1042 AND activity_date <= DATE '2026-06-30'
)
SELECT count(*) AS streak_days, min(activity_date) AS streak_started
FROM days
WHERE grp = (SELECT grp FROM days WHERE activity_date = DATE '2026-06-30');

-- @R04
SELECT l.daily_goal_xp, coalesce(sum(a.xp_earned), 0) AS xp_today
FROM learners l
LEFT JOIN lesson_attempts a
  ON a.learner_id = l.learner_id AND DATE(a.started_at) = DATE '2026-06-30'
WHERE l.learner_id = 1042
GROUP BY l.daily_goal_xp;

-- @R05
SELECT lm.learner_id, le.username, lm.weekly_xp,
       RANK() OVER (ORDER BY lm.weekly_xp DESC) AS position
FROM league_memberships lm
JOIN learners le ON le.learner_id = lm.learner_id
WHERE lm.week_start = DATE '2026-06-29'
  AND lm.cohort_id = (SELECT cohort_id FROM league_memberships
                      WHERE learner_id = 1042 AND week_start = DATE '2026-06-29')
ORDER BY position;

-- @R06
SELECT l.lesson_id, u.unit_no, l.lesson_no, l.lesson_type
FROM units u JOIN lessons l ON l.unit_id = u.unit_id
WHERE u.course_id = 1
  AND NOT EXISTS (
      SELECT 1 FROM lesson_attempts a
      WHERE a.learner_id = 1042 AND a.lesson_id = l.lesson_id
        AND a.completed_at IS NOT NULL
  )
ORDER BY u.unit_no, l.lesson_no
LIMIT 1;

-- @R07
SELECT l.lesson_id, u.unit_no, l.lesson_no, count(*) AS attempts,
       round(avg(a.mistakes), 2) AS avg_mistakes
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
JOIN units u ON u.unit_id = l.unit_id
WHERE u.course_id = 1
GROUP BY l.lesson_id, u.unit_no, l.lesson_no
HAVING count(*) >= 100
ORDER BY avg_mistakes DESC
LIMIT 20;


-- @R08
-- Product analytics: quit rate per lesson type
SELECT l.lesson_type, count(*) AS attempts,
       round(100.0 * count(*) FILTER (WHERE a.completed_at IS NULL) / count(*), 2) AS quit_pct
FROM lesson_attempts a
JOIN lessons l ON l.lesson_id = a.lesson_id
GROUP BY l.lesson_type
ORDER BY quit_pct DESC;

-- @R09
-- Growth: daily active learners in June 2026
SELECT activity_date, count(*) AS active_learners
FROM daily_activity
WHERE xp > 0
  AND activity_date >= DATE '2026-06-01'
  AND activity_date < DATE '2026-07-01'
GROUP BY activity_date
ORDER BY activity_date;

-- @R10
-- Monetisation: streak freezes used per subscription tier in 2026
SELECT l.subscription, count(*) AS freezes_used
FROM daily_activity d
JOIN learners l ON l.learner_id = d.learner_id
WHERE d.used_streak_freeze
  AND d.activity_date >= DATE '2026-01-01'
  AND d.activity_date < DATE '2027-01-01'
GROUP BY l.subscription
ORDER BY freezes_used DESC;

-- @R11
-- Sign-in by username
SELECT learner_id, email, subscription, daily_goal_xp
FROM learners
WHERE username = 'Karan_xVerma1042';

-- @R12
-- Profile: learner 1042's achievements, newest first
SELECT a.code, a.name, la.earned_at
FROM learner_achievements la
JOIN achievements a ON a.achievement_id = la.achievement_id
WHERE la.learner_id = 1042
ORDER BY la.earned_at DESC;

-- @R13
-- Referral programme: learners who have not referred anyone yet
-- NOT EXISTS avoids the NULL-related issue caused by NOT IN.
SELECT l.learner_id, l.username
FROM learners l
WHERE NOT EXISTS (
    SELECT 1
    FROM learners r
    WHERE r.referred_by = l.learner_id
);


-- @R14
-- Leagues team: promotion and demotion rates per tier over the last 4 completed weeks
SELECT tier, count(*) AS memberships,
       round(100.0 * count(*) FILTER (WHERE result = 'PROMOTED') / count(*), 1) AS promoted_pct,
       round(100.0 * count(*) FILTER (WHERE result = 'DEMOTED') / count(*), 1) AS demoted_pct
FROM league_memberships
WHERE week_start >= DATE '2026-06-01'
  AND week_start < DATE '2026-06-23'
GROUP BY tier
ORDER BY tier;


-- @R15
-- Retention: learners who joined in January 2026 and were still active in June 2026
SELECT count(*) AS joined_jan,
       count(*) FILTER (
           WHERE EXISTS (
               SELECT 1
               FROM daily_activity d
               WHERE d.learner_id = l.learner_id
                 AND d.activity_date >= DATE '2026-06-01'
                 AND d.activity_date < DATE '2026-07-01'
                 AND d.xp > 0
           )
       ) AS active_june
FROM learners l
WHERE l.joined_at >= TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
  AND l.joined_at < TIMESTAMPTZ '2026-02-01 00:00:00+05:30';


-- @R16
-- Friends: search learners by username starting with "Karan"
SELECT learner_id, username, country_code
FROM learners
WHERE lower(username) LIKE 'karan%'
ORDER BY username
LIMIT 20;


-- @R17
-- Product analytics: perfect-lesson rate per device in 2026
SELECT device, count(*) AS completed,
       round(100.0 * count(*) FILTER (WHERE is_perfect) / count(*), 2) AS perfect_pct
FROM lesson_attempts
WHERE completed_at IS NOT NULL
  AND started_at >= TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
  AND started_at < TIMESTAMPTZ '2027-01-01 00:00:00+05:30'
GROUP BY device
ORDER BY perfect_pct DESC;

