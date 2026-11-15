# Phase 1 — Problem understanding

I read the seven problems as a mix of app features that need quick answers and reports that can run in the background.

| Problem | What the database needs to do | Who needs it | Type |
|---|---|---|---|
| P1 — Home screen | Show courses, XP, daily goal, next lesson and streak. | Learners, app team | Real-time |
| P2 — Leagues | Show the leaderboard and save weekly promotion results. | Learners, league team | Real-time for the leaderboard; weekly processing for results |
| P3 — Lessons | Save lesson attempts and update XP. | Learners, app team | Real-time |
| P4 — Curriculum | Show which lessons have more mistakes, quits and hearts lost. | Curriculum team | Reporting |
| P5 — Referrals | Find learners who have not referred anyone. | Growth team | Reporting |
| P6 — Growth | Show daily activity, retention, streaks, XP and popular courses. | Growth and notifications teams | Reporting; reminders can run in batches |
| P7 — Accounts and support | Make sign-in, username search, achievements and support lookups work quickly. Also track paid plans and future growth. | Learners, support, platform and paid-plan teams | Real-time for app actions; reporting for paid plans |

## Assumptions

- I use the 30 supplied queries to understand what the database needs to support.
- An attempt with no `completed_at` was not finished in the seed data. It has no XP.
- A blank `referred_by` means no referrer was recorded.
- A league row with no rank or result is for a week that has not finished yet. Both fields should be filled together.
- Daily activity, course XP and league XP are stored totals. They can be compared with lesson attempts, but are kept because the project queries use them.
- CSV timestamps include a time-zone offset, so I use `timestamptz` for them.
