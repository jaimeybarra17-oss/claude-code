-- gamification_test.sql
-- Runnable regression test for the server-authoritative reward pipeline.
-- Assumes all migrations + seed.sql have been applied. Runs in a transaction
-- and ROLLBACKs, so it is safe to run repeatedly against a seeded database:
--
--   psql "$DATABASE_URL" -f supabase/tests/gamification_test.sql
--
-- Any failed assertion RAISEs and aborts with a non-zero exit code.

\set ON_ERROR_STOP on
begin;

do $$
declare
  u uuid := '0e57e57e-0000-4000-8000-000000000001';
  elec uuid := (select id from careers where slug = 'electrician');
  l1 uuid := (select l.id from lessons l
              join modules m on m.id = l.module_id
              where m.career_id = elec and m.level = 1 and l.position = 1);
  v_xp bigint; v_pct numeric; v_streak int; v_trophies int;
  has_first_spark boolean; has_safety boolean;
begin
  -- Provision a learner (handle_new_user trigger creates profile + streak).
  insert into auth.users(id, email, raw_user_meta_data)
    values (u, 'test@skillforge.dev', '{"display_name":"Tester"}');
  update profiles set active_career_id = elec where id = u;
  insert into enrollments(user_id, career_id) values (u, elec);

  -- Complete the first lesson.
  insert into lesson_progress(user_id, lesson_id, status)
    values (u, l1, 'completed');

  select total_xp into v_xp from profiles where id = u;
  select round(progress_pct, 2) into v_pct from enrollments where user_id = u;
  select current_streak into v_streak from streaks where user_id = u;
  has_first_spark := exists (
    select 1 from user_badges ub join badges b on b.id = ub.badge_id
    where ub.user_id = u and b.slug = 'first_spark');

  assert v_xp >= 20, format('expected >=20 XP after one lesson, got %s', v_xp);
  assert v_pct = 25.00, format('expected 25%% progress, got %s', v_pct);
  assert v_streak = 1, format('expected streak 1, got %s', v_streak);
  assert has_first_spark, 'expected first_spark badge after one lesson';

  -- Complete the rest of Level 1.
  insert into lesson_progress(user_id, lesson_id, status)
    select u, l.id, 'completed'
    from lessons l join modules m on m.id = l.module_id
    where m.career_id = elec and m.level = 1 and l.position in (2, 3, 4);

  select round(progress_pct, 2) into v_pct from enrollments where user_id = u;
  select count(*) into v_trophies from trophies where user_id = u;
  has_safety := exists (
    select 1 from user_badges ub join badges b on b.id = ub.badge_id
    where ub.user_id = u and b.slug = 'safety_first');

  assert v_pct = 100.00, format('expected 100%% progress, got %s', v_pct);
  assert v_trophies = 1, format('expected 1 career trophy, got %s', v_trophies);
  assert has_safety, 'expected safety_first badge after finishing Level 1';

  -- Leaderboards should have received the XP across global + career scopes.
  assert (select count(*) from leaderboard_entries where user_id = u) >= 4,
    'expected leaderboard entries to be populated';

  raise notice 'gamification_test: ALL ASSERTIONS PASSED';
end $$;

rollback;
