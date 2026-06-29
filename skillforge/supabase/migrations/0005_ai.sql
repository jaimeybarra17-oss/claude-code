-- 0005_ai.sql
-- The AI Teacher / Coach: threads, messages, remembered learning gaps, and
-- usage metering (for per-plan rate limits and the admin analytics panel).

create type ai_role     as enum ('system', 'user', 'assistant', 'tool');
create type ai_surface  as enum ('teacher', 'coach', 'exam', 'interview');

create table ai_threads (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  surface     ai_surface not null default 'coach',
  career_id   uuid references careers(id) on delete set null,
  lesson_id   uuid references lessons(id) on delete set null,
  title       text,
  -- Compact rolling summary of older turns so we never resend full history.
  summary     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table ai_messages (
  id          uuid not null default gen_random_uuid(),
  thread_id   uuid not null references ai_threads(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  role        ai_role not null,
  content     text not null,
  tokens      integer,
  created_at  timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);

create table ai_messages_default partition of ai_messages default;
create index idx_ai_messages_thread on ai_messages(thread_id, created_at);

-- Remembered mistakes / misconceptions so the coach can "remember previous
-- mistakes" and adapt. Surfaced into the prompt and into "Review my mistakes".
create table learning_gaps (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  career_id   uuid references careers(id) on delete set null,
  topic       text not null,                     -- 'ohms_law', 'wire_gauge'
  detail      text,
  severity    smallint not null default 1,       -- 1..5
  status      text not null default 'open',      -- open | reinforcing | resolved
  occurrences integer not null default 1,
  last_seen_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (user_id, topic)
);

create index idx_learning_gaps_user on learning_gaps(user_id, status);

-- Per-call usage metering: drives plan rate limits and admin AI analytics.
create table ai_usage (
  id            uuid not null default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  surface       ai_surface not null,
  model         text not null,
  prompt_tokens integer not null default 0,
  output_tokens integer not null default 0,
  cost_usd      numeric(10,6) not null default 0,
  created_at    timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);

create table ai_usage_default partition of ai_usage default;
create index idx_ai_usage_user_day on ai_usage(user_id, created_at);
