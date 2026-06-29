-- 0001_identity_and_catalog.sql
-- Identity (profiles, onboarding) + the data-driven content catalog
-- (careers → modules → lessons → simulations → quizzes).
--
-- Design notes:
--   * `profiles.id` mirrors `auth.users.id` 1:1; we never store credentials here.
--   * The content graph is pure data: a new career is rows, never a deploy.
--   * Materialized totals (xp, coins) live on `profiles` and are maintained by
--     triggers defined in 0009; nothing client-side may write them.

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "citext";     -- case-insensitive handles/emails

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type experience_level as enum ('none', 'beginner', 'intermediate', 'advanced');
create type learning_style   as enum ('visual', 'hands_on', 'reading', 'mixed');
create type plan_tier        as enum ('free', 'premium', 'enterprise');
create type lesson_kind      as enum ('concept', 'video', 'interactive', 'quiz', 'simulation', 'boss');
create type content_status   as enum ('draft', 'published', 'archived');

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
create table profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  handle          citext unique,
  display_name    text,
  avatar_url      text,
  age             smallint check (age between 13 and 120),
  country         text,                       -- ISO-3166 alpha-2
  plan            plan_tier not null default 'free',
  active_career_id uuid,                       -- FK added after careers exists
  -- materialized gamification totals (trigger-maintained, read-only to clients)
  total_xp        bigint not null default 0,
  coins           bigint not null default 0,
  level           integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Captures the onboarding questionnaire that seeds the personalized roadmap.
create table onboarding_responses (
  user_id           uuid primary key references profiles(id) on delete cascade,
  career_interest_id uuid,                     -- FK added after careers exists
  experience         experience_level not null default 'none',
  current_income     integer,                  -- annual, USD
  income_goal        integer,                  -- annual, USD
  weekly_minutes     integer not null default 150,
  learning_style     learning_style not null default 'mixed',
  career_goal        text,
  completed_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Catalog: careers → modules → lessons
-- ---------------------------------------------------------------------------
create table careers (
  id               uuid primary key default gen_random_uuid(),
  slug             text unique not null,        -- 'electrician'
  name             text not null,
  tagline          text,
  description      text,
  icon             text,                         -- asset key / emoji
  accent_color     text,                         -- hex, drives per-career theming
  category         text,                         -- 'trades' | 'knowledge_work'
  median_salary    integer,                      -- USD, for salary projections
  entry_salary     integer,
  senior_salary    integer,
  est_weeks_to_job integer,                       -- guideline for roadmap pacing
  status           content_status not null default 'published',
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now()
);

-- A module is a "Level" in the UI (Level 1..N). Ordered within a career.
create table modules (
  id          uuid primary key default gen_random_uuid(),
  career_id   uuid not null references careers(id) on delete cascade,
  level       integer not null,                  -- 1..N, unique per career
  title       text not null,                     -- 'Electrical Safety'
  summary     text,
  xp_reward   integer not null default 100,      -- bonus for completing the module
  status      content_status not null default 'published',
  unique (career_id, level)
);

-- A lesson is a single learnable unit inside a module.
create table lessons (
  id            uuid primary key default gen_random_uuid(),
  module_id     uuid not null references modules(id) on delete cascade,
  position      integer not null,                -- order within the module
  title         text not null,
  kind          lesson_kind not null default 'concept',
  -- Rich, structured body (markdown blocks, media refs, sim config). JSONB keeps
  -- the schema stable while content authors evolve lesson layouts.
  body          jsonb not null default '{}'::jsonb,
  est_minutes   integer not null default 5,
  xp_reward     integer not null default 20,
  status        content_status not null default 'published',
  simulation_id uuid,                            -- FK added after simulations exists
  unique (module_id, position)
);

-- Now that careers/modules exist, wire the deferred FKs.
alter table profiles
  add constraint profiles_active_career_fk
  foreign key (active_career_id) references careers(id) on delete set null;

alter table onboarding_responses
  add constraint onboarding_career_fk
  foreign key (career_interest_id) references careers(id) on delete set null;

-- Helpful indexes for the common access patterns.
create index idx_modules_career on modules(career_id, level);
create index idx_lessons_module on lessons(module_id, position);
create index idx_careers_status on careers(status, sort_order);

-- Keep updated_at honest.
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_profiles_updated
  before update on profiles
  for each row execute function set_updated_at();
