-- 0002_learning_progress.sql
-- Enrollment, per-lesson progress, personalized roadmaps, and quizzes.

create type progress_status as enum ('locked', 'available', 'in_progress', 'completed');

-- A learner enrolls in a career; one active enrollment drives the dashboard.
create table enrollments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  career_id     uuid not null references careers(id) on delete cascade,
  progress_pct  numeric(5,2) not null default 0,   -- 0..100, trigger-maintained
  current_module_id uuid references modules(id) on delete set null,
  hours_studied numeric(8,2) not null default 0,
  started_at    timestamptz not null default now(),
  completed_at  timestamptz,
  unique (user_id, career_id)
);

-- Per-lesson state. History of state changes is implied by updated_at; the
-- append-only event stream lives in xp_ledger / analytics (0003, 0008).
create table lesson_progress (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  lesson_id    uuid not null references lessons(id) on delete cascade,
  status       progress_status not null default 'available',
  score        numeric(5,2),                      -- best score if the lesson is graded
  attempts     integer not null default 0,
  seconds_spent integer not null default 0,
  completed_at timestamptz,
  updated_at   timestamptz not null default now(),
  unique (user_id, lesson_id)
);

create index idx_lesson_progress_user on lesson_progress(user_id, status);

-- The personalized roadmap generated at onboarding (and re-generated on demand).
-- Stored as an ordered plan so it can be rendered without recomputation.
create table roadmaps (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  career_id   uuid not null references careers(id) on delete cascade,
  -- [{ "module_id": "...", "target_week": 1, "rationale": "..." }, ...]
  plan        jsonb not null default '[]'::jsonb,
  generated_by text not null default 'ai',        -- 'ai' | 'default'
  created_at  timestamptz not null default now(),
  unique (user_id, career_id)
);

-- ---------------------------------------------------------------------------
-- Quizzes (answer keys are RLS-hidden from learners; grading is server-side)
-- ---------------------------------------------------------------------------
create table quizzes (
  id          uuid primary key default gen_random_uuid(),
  lesson_id   uuid references lessons(id) on delete cascade,
  module_id   uuid references modules(id) on delete cascade,  -- module-level quiz
  title       text not null,
  pass_score  numeric(5,2) not null default 70,
  xp_reward   integer not null default 50,
  is_exam     boolean not null default false,     -- practice exam vs lesson quiz
  check (lesson_id is not null or module_id is not null)
);

create table quiz_questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references quizzes(id) on delete cascade,
  position       integer not null,
  prompt         text not null,
  -- ["option a", "option b", ...]
  options        jsonb not null default '[]'::jsonb,
  correct_option smallint not null,               -- index into options (RLS-hidden)
  explanation    text,                             -- shown after answering
  unique (quiz_id, position)
);

create table quiz_attempts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  quiz_id     uuid not null references quizzes(id) on delete cascade,
  score       numeric(5,2) not null,
  passed      boolean not null,
  -- [{ "question_id": "...", "chosen": 2, "correct": true }, ...]
  answers     jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now()
);

create index idx_quiz_questions_quiz on quiz_questions(quiz_id, position);
create index idx_quiz_attempts_user on quiz_attempts(user_id, quiz_id);
