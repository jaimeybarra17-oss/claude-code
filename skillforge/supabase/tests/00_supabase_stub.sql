-- 00_supabase_stub.sql  (TEST ONLY — do NOT run against a real Supabase project)
--
-- Managed Supabase provides the `auth` schema, `auth.users`, and the
-- `auth.uid()` / `auth.jwt()` session helpers. To run the migrations and tests
-- on a bare PostgreSQL instance (e.g. in CI), we stub just enough of that layer.
-- Supabase already ships these, so applying this there would be redundant/wrong.

create schema if not exists auth;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb default '{}'::jsonb
);

-- Resolve the current user / claims from PostgREST-style GUCs.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb);
$$;

-- Extensions Supabase preloads.
create extension if not exists pgcrypto;
create extension if not exists citext;
