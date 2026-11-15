-- Run from the project root after extracting seed_data.zip into ./seed_data/.
SET search_path TO duolingo;
\copy languages FROM 'seed_data/languages.csv' WITH (FORMAT csv, HEADER true)
\copy courses FROM 'seed_data/courses.csv' WITH (FORMAT csv, HEADER true)
\copy units FROM 'seed_data/units.csv' WITH (FORMAT csv, HEADER true)
\copy lessons FROM 'seed_data/lessons.csv' WITH (FORMAT csv, HEADER true)
\copy learners FROM 'seed_data/learners.csv' WITH (FORMAT csv, HEADER true)
\copy achievements FROM 'seed_data/achievements.csv' WITH (FORMAT csv, HEADER true)
\copy enrollments FROM 'seed_data/enrollments.csv' WITH (FORMAT csv, HEADER true)
\copy lesson_attempts FROM 'seed_data/lesson_attempts.csv' WITH (FORMAT csv, HEADER true)
\copy daily_activity FROM 'seed_data/daily_activity.csv' WITH (FORMAT csv, HEADER true)
\copy league_memberships FROM 'seed_data/league_memberships.csv' WITH (FORMAT csv, HEADER true)
\copy learner_achievements FROM 'seed_data/learner_achievements.csv' WITH (FORMAT csv, HEADER true)
ANALYZE;

-- Expected row counts:
SELECT 'languages' AS table_name, count(*) AS rows FROM duolingo.languages
UNION ALL SELECT 'courses', count(*) FROM duolingo.courses
UNION ALL SELECT 'units', count(*) FROM duolingo.units
UNION ALL SELECT 'lessons', count(*) FROM duolingo.lessons
UNION ALL SELECT 'learners', count(*) FROM duolingo.learners
UNION ALL SELECT 'enrollments', count(*) FROM duolingo.enrollments
UNION ALL SELECT 'lesson_attempts', count(*) FROM duolingo.lesson_attempts
UNION ALL SELECT 'daily_activity', count(*) FROM duolingo.daily_activity
UNION ALL SELECT 'league_memberships', count(*) FROM duolingo.league_memberships
UNION ALL SELECT 'achievements', count(*) FROM duolingo.achievements
UNION ALL SELECT 'learner_achievements', count(*) FROM duolingo.learner_achievements
ORDER BY table_name;
