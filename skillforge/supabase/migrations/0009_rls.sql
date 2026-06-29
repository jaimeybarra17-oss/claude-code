-- 0009_rls.sql
-- Row-Level Security. The trust model:
--   * Catalog content (careers/modules/lessons/simulations/badges/job_listings)
--     is world-readable when published; only admins write it.
--   * Per-user rows are readable/writable only by their owner — EXCEPT
--     gamification + billing tables, which are read-only to the owner and
--     written exclusively by SECURITY DEFINER functions / Edge Functions.
--   * Quiz answer keys are never exposed to learners.
--
-- "admin" is modeled as a custom JWT claim: auth.jwt()->>'role' = 'admin',
-- set via Supabase custom claims for staff accounts.

create or replace function is_admin() returns boolean
language sql stable as $$
  select coalesce(auth.jwt()->>'user_role', '') = 'admin';
$$;

-- Enable RLS everywhere.
alter table profiles              enable row level security;
alter table onboarding_responses enable row level security;
alter table careers              enable row level security;
alter table modules              enable row level security;
alter table lessons              enable row level security;
alter table quizzes              enable row level security;
alter table quiz_questions       enable row level security;
alter table quiz_attempts        enable row level security;
alter table enrollments          enable row level security;
alter table lesson_progress      enable row level security;
alter table roadmaps             enable row level security;
alter table simulations          enable row level security;
alter table simulation_attempts  enable row level security;
alter table xp_ledger            enable row level security;
alter table streaks              enable row level security;
alter table badges               enable row level security;
alter table user_badges          enable row level security;
alter table trophies             enable row level security;
alter table leaderboard_entries  enable row level security;
alter table daily_challenges     enable row level security;
alter table challenge_completions enable row level security;
alter table ai_threads           enable row level security;
alter table ai_messages          enable row level security;
alter table learning_gaps        enable row level security;
alter table ai_usage             enable row level security;
alter table certificates         enable row level security;
alter table mock_interviews      enable row level security;
alter table resumes              enable row level security;
alter table job_listings         enable row level security;
alter table applications         enable row level security;
alter table friendships          enable row level security;
alter table study_groups         enable row level security;
alter table group_members        enable row level security;
alter table posts                enable row level security;
alter table comments             enable row level security;
alter table subscriptions        enable row level security;
alter table audit_log            enable row level security;

-- ---------------------------------------------------------------------------
-- Profiles: a user can read any profile (public handle/avatar/level for
-- leaderboards & community) but update only their own.
-- ---------------------------------------------------------------------------
create policy profiles_read   on profiles for select using (true);
create policy profiles_update on profiles for update using (id = auth.uid())
  with check (id = auth.uid());

create policy onboarding_owner on onboarding_responses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Catalog: public read of published rows; admin full control.
-- ---------------------------------------------------------------------------
create policy careers_read on careers for select
  using (status = 'published' or is_admin());
create policy careers_admin on careers for all
  using (is_admin()) with check (is_admin());

create policy modules_read on modules for select
  using (status = 'published' or is_admin());
create policy modules_admin on modules for all
  using (is_admin()) with check (is_admin());

create policy lessons_read on lessons for select
  using (status = 'published' or is_admin());
create policy lessons_admin on lessons for all
  using (is_admin()) with check (is_admin());

create policy simulations_read on simulations for select
  using (status = 'published' or is_admin());
create policy simulations_admin on simulations for all
  using (is_admin()) with check (is_admin());

create policy badges_read on badges for select using (true);
create policy badges_admin on badges for all using (is_admin()) with check (is_admin());

create policy job_listings_read on job_listings for select using (true);
create policy job_listings_admin on job_listings for all using (is_admin()) with check (is_admin());

-- Quizzes are readable, but the ANSWER KEY lives in quiz_questions which is
-- hidden from learners. Grading happens in the grade-quiz Edge Function which
-- uses the service role and bypasses RLS.
create policy quizzes_read on quizzes for select using (true);
create policy quizzes_admin on quizzes for all using (is_admin()) with check (is_admin());
create policy quiz_questions_admin_only on quiz_questions for select using (is_admin());
create policy quiz_questions_admin on quiz_questions for all using (is_admin()) with check (is_admin());

create policy daily_challenges_read on daily_challenges for select using (true);
create policy daily_challenges_admin on daily_challenges for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- Owner-scoped learning data (read + write by owner).
-- ---------------------------------------------------------------------------
create policy enrollments_owner on enrollments
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy lesson_progress_owner on lesson_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy roadmaps_owner on roadmaps
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy quiz_attempts_owner on quiz_attempts
  for select using (user_id = auth.uid());      -- writes via grade-quiz fn only
create policy sim_attempts_owner on simulation_attempts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy resumes_owner on resumes
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy applications_owner on applications
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy mock_interviews_owner on mock_interviews
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy challenge_completions_owner on challenge_completions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- AI data: owner read/write of their own threads/messages/gaps; usage read-only.
create policy ai_threads_owner on ai_threads
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy ai_messages_owner on ai_messages
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy learning_gaps_owner on learning_gaps
  for select using (user_id = auth.uid());      -- writes via Edge Function
create policy ai_usage_owner on ai_usage
  for select using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Gamification + billing: READ-ONLY to the owner; written only by SECURITY
-- DEFINER functions (award_xp/touch_streak/check_badges) or the Stripe webhook.
-- ---------------------------------------------------------------------------
create policy xp_ledger_owner_read on xp_ledger for select using (user_id = auth.uid());
create policy streaks_owner_read   on streaks   for select using (user_id = auth.uid());
create policy user_badges_owner_read on user_badges for select using (user_id = auth.uid());
create policy trophies_owner_read  on trophies  for select using (user_id = auth.uid());
create policy subscriptions_owner_read on subscriptions for select using (user_id = auth.uid());

-- Leaderboards are world-readable (rankings are public by design).
create policy leaderboard_read on leaderboard_entries for select using (true);

-- ---------------------------------------------------------------------------
-- Community
-- ---------------------------------------------------------------------------
create policy friendships_party on friendships
  for all using (requester_id = auth.uid() or addressee_id = auth.uid())
  with check (requester_id = auth.uid());

create policy study_groups_read on study_groups for select using (true);
create policy study_groups_owner on study_groups for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy group_members_read on group_members for select using (true);
create policy group_members_self on group_members
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Posts/comments: readable by anyone in scope; authored only as yourself.
create policy posts_read on posts for select using (true);
create policy posts_author on posts for all
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy comments_read on comments for select using (true);
create policy comments_author on comments for all
  using (author_id = auth.uid()) with check (author_id = auth.uid());

-- Admin-only audit log.
create policy audit_admin on audit_log for select using (is_admin());

-- Certificates: owner reads; issued by the certificate Edge Function (service role).
create policy certificates_owner_read on certificates for select using (user_id = auth.uid());
