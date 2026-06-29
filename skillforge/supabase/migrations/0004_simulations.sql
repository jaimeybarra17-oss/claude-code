-- 0004_simulations.sql
-- Interactive, "learn by doing" simulations and their attempt records.
--
-- A simulation is engine-agnostic: `engine` selects the client renderer
-- (e.g. wiring board, chart replay, dialogue tree) and `config` is the
-- engine-specific scenario. This lets us add new simulation types without
-- schema changes — the same pattern as the content catalog.

create table simulations (
  id          uuid primary key default gen_random_uuid(),
  career_id   uuid not null references careers(id) on delete cascade,
  slug        text not null,
  title       text not null,
  description text,
  engine      text not null,                     -- 'wiring' | 'chart_replay' | 'dialogue' | 'inspection' | ...
  difficulty  smallint not null default 1,       -- 1..5
  -- Scenario definition consumed by the client engine. Examples:
  --  wiring:        { "circuits": [...], "fault": "open_neutral" }
  --  chart_replay:  { "symbol":"AAPL", "from":"2021-01-04", "bars":120 }
  --  dialogue:      { "persona":"skeptical_buyer", "objective":"close" }
  config      jsonb not null default '{}'::jsonb,
  xp_reward   integer not null default 80,
  status      content_status not null default 'published',
  unique (career_id, slug)
);

-- Wire the deferred FK from lessons → simulations now that the table exists.
alter table lessons
  add constraint lessons_simulation_fk
  foreign key (simulation_id) references simulations(id) on delete set null;

create table simulation_attempts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  simulation_id uuid not null references simulations(id) on delete cascade,
  score         numeric(5,2),                    -- 0..100 performance grade
  passed        boolean not null default false,
  -- Engine telemetry: steps taken, mistakes, timings — feeds learning_gaps + analytics.
  telemetry     jsonb not null default '{}'::jsonb,
  seconds_spent integer not null default 0,
  created_at    timestamptz not null default now()
);

create index idx_sim_attempts_user on simulation_attempts(user_id, simulation_id);
