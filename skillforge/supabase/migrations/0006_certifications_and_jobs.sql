-- 0006_certifications_and_jobs.sql
-- Certificates + the career readiness score, and the Job Section
-- (resumes, listings, applications, mock interviews).

-- ---------------------------------------------------------------------------
-- Certifications
-- ---------------------------------------------------------------------------
create table certificates (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  career_id     uuid not null references careers(id) on delete cascade,
  serial        text unique not null default encode(gen_random_bytes(8), 'hex'),
  readiness_score numeric(5,2) not null default 0,  -- 0..100 snapshot at issue time
  issued_at     timestamptz not null default now(),
  pdf_url       text,                              -- rendered + stored in Supabase Storage
  unique (user_id, career_id)
);

-- Mock interviews conducted by the AI (links back to an ai_thread).
create table mock_interviews (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  career_id   uuid not null references careers(id) on delete cascade,
  thread_id   uuid references ai_threads(id) on delete set null,
  score       numeric(5,2),
  feedback    jsonb not null default '{}'::jsonb,  -- strengths/weaknesses/next steps
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------
create table resumes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  title       text not null default 'My Resume',
  -- Structured resume so we can render to multiple templates + give AI feedback.
  content     jsonb not null default '{}'::jsonb,
  ai_feedback jsonb,                                -- last AI review result
  pdf_url     text,
  updated_at  timestamptz not null default now()
);

create table job_listings (
  id          uuid primary key default gen_random_uuid(),
  career_id   uuid references careers(id) on delete set null,
  title       text not null,
  company     text,
  location    text,
  remote      boolean not null default false,
  salary_min  integer,
  salary_max  integer,
  url         text,
  source      text,                                 -- aggregator / partner
  description text,
  posted_at   timestamptz,
  created_at  timestamptz not null default now()
);

create type application_status as enum ('saved', 'applied', 'interviewing', 'offer', 'rejected', 'accepted');

create table applications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  listing_id  uuid references job_listings(id) on delete set null,
  resume_id   uuid references resumes(id) on delete set null,
  status      application_status not null default 'saved',
  cover_letter text,
  notes       text,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index idx_applications_user on applications(user_id, status);
create index idx_job_listings_career on job_listings(career_id, posted_at desc);
