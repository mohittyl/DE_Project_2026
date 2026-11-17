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

