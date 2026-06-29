# SkillForge — Data Model

The schema is defined by the ordered migrations in `supabase/migrations/`. This
document explains the *why*; the SQL is the source of truth.

## Guiding decisions

1. **The content graph is data, not code.** Careers → modules (levels) → lessons →
   simulations/quizzes are all rows. A new career path is an INSERT, never a
   deploy. This is what makes "unlimited career paths" real.
2. **JSONB for evolving content, columns for relationships.** Lesson bodies,
   simulation scenarios, quiz options, and roadmap plans are JSONB so authors can
   evolve layouts without migrations; everything we filter/join on is a real column.
3. **Append-only ledgers for hot paths.** `xp_ledger`, `ai_messages`, and
   `ai_usage` are range-partitioned by month so writes stay cheap and old data is
   detachable. Materialized totals (`profiles.total_xp`, `coins`, `level`) give the
   client O(1) reads.
4. **Server-authoritative gamification.** Clients can *read* XP/streaks/badges but
   never *write* them; only `SECURITY DEFINER` functions do (see `0008`).

## Entity map

```
auth.users ─1:1─ profiles ─1:1─ onboarding_responses
                    │
   ┌────────────────┼───────────────────────────────────────────┐
   │                │                                             │
careers ─< modules ─< lessons ─?─ simulations          enrollments >─ careers
   │                    │   │                                │
   │                 quizzes │                         lesson_progress
   │                    │  quiz_questions (answer key, RLS-hidden)
   │                    └─ quiz_attempts
   │
   └─< daily_challenges, badges(criteria), job_listings

profiles ─< xp_ledger, streaks(1:1), user_badges, trophies,
            leaderboard_entries, ai_threads ─< ai_messages,
            learning_gaps, certificates, resumes, applications,
            simulation_attempts, subscriptions(1:1)
```

## Table reference (selected)

| Table | Purpose | Notable columns |
| ----- | ------- | --------------- |
| `profiles` | Public identity + materialized gamification totals | `total_xp`, `coins`, `level`, `active_career_id` |
| `onboarding_responses` | Drives roadmap generation | `experience`, `weekly_minutes`, `income_goal` |
| `careers` / `modules` / `lessons` | The content graph | `lessons.body` JSONB, `lessons.kind` |
| `simulations` | Engine-agnostic "learn by doing" scenarios | `engine`, `config` JSONB |
| `quiz_questions` | Includes `correct_option` (RLS-hidden) | graded server-side |
| `lesson_progress` | Per-lesson state; trigger source for rewards | `status`, `completed_at` |
| `xp_ledger` | Append-only XP/coin events (partitioned) | `reason`, `ref_id` |
| `streaks` | Server-computed daily streak | `current_streak`, `freeze_tokens` |
| `leaderboard_entries` | Precomputed rankings (scope × period) | `scope`, `period_key`, `xp` |
| `ai_threads` / `ai_messages` | Mentor conversations (partitioned) | `surface`, `summary` |
| `learning_gaps` | Remembered mistakes for adaptive coaching | `topic`, `severity`, `status` |
| `certificates` | Issued on path completion | `readiness_score`, `serial` |
| `subscriptions` | Stripe entitlement (webhook-written) | `status`, `current_period_end` |

## Derived values & where they live

| Value | Computed by | Stored on |
| ----- | ----------- | --------- |
| Level | `level_for_xp(total_xp)` | `profiles.level` |
| Career progress % | `recompute_career_progress()` | `enrollments.progress_pct` |
| Streak | `touch_streak()` | `streaks.current_streak` |
| Leaderboard rank | `bump_leaderboard()` + scheduled rank pass | `leaderboard_entries` |
| Badge unlocks | `check_badges()` | `user_badges` |
| Career Readiness Score | exam + simulation + progress blend (see GAMIFICATION) | `certificates.readiness_score` |

## Replicating a career

To add e.g. HVAC, mirror `seed/02_electrician_curriculum.sql`: insert 10 `modules`,
their `lessons`, the career's `simulations` (with the right `engine`), at least one
graded `quiz`, and career-specific `badges`. No schema change required.
