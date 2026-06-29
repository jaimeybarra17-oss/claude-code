-- 0003_gamification.sql
-- XP economy, streaks, badges, and leaderboards.
--
-- The xp_ledger is the source of truth and is APPEND-ONLY. The materialized
-- total on profiles.total_xp is maintained by trigger (0009) so the client can
-- read a single number without summing the ledger. This table is range
-- partitioned by month because it is a write hot-path at scale.

create type xp_reason as enum (
  'lesson_complete', 'module_complete', 'quiz_pass', 'exam_pass',
  'simulation_complete', 'daily_challenge', 'streak_bonus', 'boss_defeated',
  'badge_unlock', 'tournament_reward', 'daily_reward'
);

create table xp_ledger (
  id          uuid not null default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  amount      integer not null,                 -- XP granted (may include coins via meta)
  coins       integer not null default 0,
  reason      xp_reason not null,
  ref_id      uuid,                              -- lesson/module/quiz/etc.
  created_at  timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);

-- Bootstrap partitions; a scheduled job rolls new ones forward (see ops docs).
create table xp_ledger_default partition of xp_ledger default;
create index idx_xp_ledger_user on xp_ledger(user_id, created_at desc);

-- Daily streak, computed server-side and idempotent per UTC day.
create table streaks (
  user_id        uuid primary key references profiles(id) on delete cascade,
  current_streak integer not null default 0,
  longest_streak integer not null default 0,
  last_active_on date,
  freeze_tokens  integer not null default 0,     -- "streak freeze" power-up
  updated_at     timestamptz not null default now()
);

-- Badge catalog (data-driven) + unlocks.
create table badges (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,              -- 'first_spark'
  name        text not null,
  description text,
  icon        text,
  tier        text not null default 'bronze',    -- bronze|silver|gold|platinum
  -- Machine-evaluable unlock rule, e.g.
  -- { "type": "lessons_completed", "career_slug": "electrician", "count": 1 }
  criteria    jsonb not null default '{}'::jsonb,
  xp_reward   integer not null default 0,
  is_secret   boolean not null default false
);

create table user_badges (
  user_id     uuid not null references profiles(id) on delete cascade,
  badge_id    uuid not null references badges(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- Career trophies awarded for completing an entire career path.
create table trophies (
  user_id     uuid not null references profiles(id) on delete cascade,
  career_id   uuid not null references careers(id) on delete cascade,
  awarded_at  timestamptz not null default now(),
  primary key (user_id, career_id)
);

-- ---------------------------------------------------------------------------
-- Leaderboards — precomputed entries, not live ORDER BY over all users.
-- Scope: global or per-career, over a period (daily/weekly/all_time).
-- Refreshed incrementally by the gamification triggers + a scheduled rollup.
-- ---------------------------------------------------------------------------
create type leaderboard_period as enum ('daily', 'weekly', 'all_time');

create table leaderboard_entries (
  id          uuid primary key default gen_random_uuid(),
  scope       text not null,                     -- 'global' | career_id::text
  period      leaderboard_period not null,
  period_key  text not null,                     -- '2026-W26' | '2026-06-29' | 'all'
  user_id     uuid not null references profiles(id) on delete cascade,
  xp          bigint not null default 0,
  rank        integer,
  updated_at  timestamptz not null default now(),
  unique (scope, period, period_key, user_id)
);

create index idx_leaderboard_lookup on leaderboard_entries(scope, period, period_key, xp desc);

-- Weekly tournaments + daily challenges.
create table daily_challenges (
  id           uuid primary key default gen_random_uuid(),
  career_id    uuid references careers(id) on delete cascade,  -- null = universal
  for_date     date not null,
  title        text not null,
  description  text,
  challenge    jsonb not null default '{}'::jsonb,  -- {"type":"quiz","quiz_id":...}
  xp_reward    integer not null default 30,
  coin_reward  integer not null default 10,
  unique (career_id, for_date)
);

create table challenge_completions (
  user_id      uuid not null references profiles(id) on delete cascade,
  challenge_id uuid not null references daily_challenges(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, challenge_id)
);
