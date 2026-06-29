# SkillForge — Gamification

Motivation is the product. Progress must feel earned, visible, and measurable.
All economy logic is **server-authoritative** (see `supabase/migrations/0008`).

## The XP economy

XP is granted only through `award_xp()` and recorded in the append-only
`xp_ledger`. Sources and default values:

| Action | XP | Coins |
| ------ | -- | ----- |
| Complete a lesson | `lessons.xp_reward` (≈20) | — |
| Pass a quiz | `quizzes.xp_reward` (≈50) | — |
| Complete a module/level | `modules.xp_reward` (100–400) | — |
| Complete a simulation | `simulations.xp_reward` (80–150) | — |
| Daily challenge | 30 | 10 |
| Streak bonus (per day) | `10 + min(streak, 50)` | 2 |
| Badge unlock | `badges.xp_reward` | — |
| Boss challenge | level-scaled | bonus |

**Coins** are the soft currency for cosmetics, streak freezes, and lesson skips —
earned, never required, and never pay-to-win on actual learning.

## Levels

```
xp_for_level(n) = 50 · n · (n − 1)
  L1: 0   L2: 100   L3: 300   L4: 600   L5: 1000   L10: 4500 ...
```

Quadratic growth: fast early wins, meaningful later levels. The current level is
derived by `level_for_xp(total_xp)` and cached on `profiles.level`.

## Streaks

`touch_streak()` runs on the first completion each UTC day and is idempotent:

- Same day → no-op.
- Consecutive day → `current_streak += 1`, pay a streak bonus.
- Gap with a **freeze token** → token consumed, streak preserved.
- Gap without a token → streak resets to 1.

`longest_streak` is tracked for bragging rights; freeze tokens are a retention lever.

## Badges & trophies

- **Badges** are data-driven (`badges.criteria` JSONB) and evaluated by
  `check_badges()` after every completion. Supported criteria types today:
  `lessons_completed` (optionally career-scoped), `streak`, `total_xp`. Add new
  types by extending the function — no schema change.
- **Trophies** are awarded automatically when a career hits 100% in
  `recompute_career_progress()`.

## Leaderboards

Rankings are **precomputed**, never a live sort over all users. `bump_leaderboard()`
incrementally maintains `leaderboard_entries` across scopes (`global` + active
career) and periods (`daily`, `weekly`, `all_time`). A scheduled job assigns
`rank` per board and resets daily/weekly keys. Hot global boards can migrate to
Redis sorted sets without changing the read API.

## Boss challenges, tournaments, daily rewards

- **Boss challenge:** the end-of-level gate (`lesson.kind = 'boss'`) — a tougher
  combined quiz/sim that must be passed to unlock the next level.
- **Weekly tournaments:** the `weekly` leaderboard period scoped to a career; top
  ranks earn `tournament_reward` XP + cosmetic trophies.
- **Daily rewards / mystery rewards:** a daily login grant (`daily_reward`) with a
  small randomized coin payout to drive habit formation.

## Career Readiness Score (0–100)

The headline "am I job-ready?" metric, blended from:

```
readiness = 0.40 · career_progress_pct
          + 0.35 · avg(exam_scores)
          + 0.15 · avg(simulation_scores)
          + 0.10 · (1 − open_gaps / total_topics) · 100
```

Computed when a certificate is issued and surfaced on the dashboard. It connects
gamification back to the real-world goal: getting hired.

## Anti-cheat

Because XP/streaks/badges are written only by `SECURITY DEFINER` functions and
quiz grading happens server-side (answer keys are RLS-hidden), a client cannot
forge progress by writing tables directly — RLS makes those columns read-only.
