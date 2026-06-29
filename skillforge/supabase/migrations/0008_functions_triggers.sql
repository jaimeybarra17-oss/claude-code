-- 0008_functions_triggers.sql
-- The server-authoritative gamification engine. None of this logic is trusted
-- to the client: XP, coins, levels, streaks, career progress, badges and
-- trophies are all derived here from completion events.
--
-- All functions are SECURITY DEFINER so they can write the read-only
-- (to clients) gamification tables while RLS still blocks direct client writes.

-- ---------------------------------------------------------------------------
-- Level curve: total XP required to reach a level. Quadratic growth keeps early
-- levels fast and later levels meaningful.  xp_for_level(n) = 50 * n * (n - 1)
-- => L1:0  L2:100  L3:300  L4:600  L5:1000 ...
-- ---------------------------------------------------------------------------
create or replace function level_for_xp(p_xp bigint)
returns integer language sql immutable as $$
  -- invert 50*n*(n-1) <= xp  ->  n = floor( (1 + sqrt(1 + xp/12.5)) / 2 )
  select greatest(1, floor((1 + sqrt(1 + p_xp / 12.5)) / 2)::int);
$$;

-- ---------------------------------------------------------------------------
-- award_xp: the ONLY sanctioned way to grant XP/coins. Appends to the ledger,
-- bumps the materialized totals + level, and updates leaderboard entries.
-- ---------------------------------------------------------------------------
create or replace function award_xp(
  p_user uuid, p_amount integer, p_reason xp_reason,
  p_ref uuid default null, p_coins integer default 0
) returns void language plpgsql security definer
set search_path = public as $$
declare
  v_total bigint;
  v_career text;
  v_week   text := to_char(now() at time zone 'utc', 'IYYY"-W"IW');
  v_day    text := to_char(now() at time zone 'utc', 'YYYY-MM-DD');
begin
  insert into xp_ledger(user_id, amount, coins, reason, ref_id)
  values (p_user, p_amount, p_coins, p_reason, p_ref);

  update profiles
     set total_xp = total_xp + p_amount,
         coins    = coins + p_coins,
         level    = level_for_xp(total_xp + p_amount)
   where id = p_user
  returning total_xp into v_total;

  -- Leaderboards: global + active-career, daily/weekly/all_time.
  v_career := (select coalesce(active_career_id::text, 'none') from profiles where id = p_user);

  perform bump_leaderboard('global', 'all_time', 'all',   p_user, p_amount);
  perform bump_leaderboard('global', 'weekly',   v_week,  p_user, p_amount);
  perform bump_leaderboard('global', 'daily',    v_day,   p_user, p_amount);
  if v_career <> 'none' then
    perform bump_leaderboard(v_career, 'weekly',   v_week, p_user, p_amount);
    perform bump_leaderboard(v_career, 'all_time', 'all',  p_user, p_amount);
  end if;
end $$;

create or replace function bump_leaderboard(
  p_scope text, p_period leaderboard_period, p_key text, p_user uuid, p_amount integer
) returns void language plpgsql security definer
set search_path = public as $$
begin
  insert into leaderboard_entries(scope, period, period_key, user_id, xp)
  values (p_scope, p_period, p_key, p_user, p_amount)
  on conflict (scope, period, period_key, user_id)
  do update set xp = leaderboard_entries.xp + excluded.xp,
                updated_at = now();
end $$;

-- ---------------------------------------------------------------------------
-- touch_streak: idempotent per UTC day. Increments on consecutive days,
-- resets (or burns a freeze token) on a gap, and pays a streak bonus.
-- ---------------------------------------------------------------------------
create or replace function touch_streak(p_user uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_last  date;
  v_cur   integer;
  v_freeze integer;
begin
  insert into streaks(user_id, current_streak, longest_streak, last_active_on)
  values (p_user, 1, 1, v_today)
  on conflict (user_id) do nothing;

  select last_active_on, current_streak, freeze_tokens
    into v_last, v_cur, v_freeze
    from streaks where user_id = p_user for update;

  if v_last = v_today then
    return;                                   -- already counted today
  elsif v_last = v_today - 1 then
    v_cur := v_cur + 1;                        -- consecutive day
    perform award_xp(p_user, 10 + least(v_cur, 50), 'streak_bonus', null, 2);
  elsif v_freeze > 0 then
    update streaks set freeze_tokens = freeze_tokens - 1 where user_id = p_user;
    -- streak preserved by the freeze; do not increment
  else
    v_cur := 1;                               -- streak broken
  end if;

  update streaks
     set current_streak = v_cur,
         longest_streak = greatest(longest_streak, v_cur),
         last_active_on = v_today,
         updated_at = now()
   where user_id = p_user;
end $$;

-- ---------------------------------------------------------------------------
-- recompute_career_progress: % of published lessons in a career completed.
-- Also flips the enrollment to completed + awards a trophy at 100%.
-- ---------------------------------------------------------------------------
create or replace function recompute_career_progress(p_user uuid, p_career uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_total integer;
  v_done  integer;
  v_pct   numeric(5,2);
begin
  select count(*) into v_total
    from lessons l join modules m on m.id = l.module_id
   where m.career_id = p_career and l.status = 'published' and m.status = 'published';

  select count(*) into v_done
    from lesson_progress lp
    join lessons l on l.id = lp.lesson_id
    join modules m on m.id = l.module_id
   where lp.user_id = p_user and m.career_id = p_career and lp.status = 'completed';

  v_pct := case when v_total = 0 then 0 else round(100.0 * v_done / v_total, 2) end;

  update enrollments
     set progress_pct = v_pct,
         completed_at = case when v_pct >= 100 then coalesce(completed_at, now()) else null end
   where user_id = p_user and career_id = p_career;

  if v_pct >= 100 then
    insert into trophies(user_id, career_id) values (p_user, p_career)
    on conflict do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- check_badges: evaluate data-driven badge criteria for a user and grant any
-- newly-earned badges (awarding their XP). Extend `criteria.type` over time.
-- ---------------------------------------------------------------------------
create or replace function check_badges(p_user uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  b record;
  v_count integer;
  v_earned boolean;
begin
  for b in
    select * from badges
    where id not in (select badge_id from user_badges where user_id = p_user)
  loop
    v_earned := false;

    if b.criteria->>'type' = 'lessons_completed' then
      select count(*) into v_count
        from lesson_progress lp
        join lessons l on l.id = lp.lesson_id
        join modules m on m.id = l.module_id
        join careers c on c.id = m.career_id
       where lp.user_id = p_user and lp.status = 'completed'
         and (b.criteria->>'career_slug' is null or c.slug = b.criteria->>'career_slug');
      v_earned := v_count >= (b.criteria->>'count')::int;

    elsif b.criteria->>'type' = 'streak' then
      select current_streak into v_count from streaks where user_id = p_user;
      v_earned := coalesce(v_count,0) >= (b.criteria->>'count')::int;

    elsif b.criteria->>'type' = 'total_xp' then
      select total_xp into v_count from profiles where id = p_user;
      v_earned := coalesce(v_count,0) >= (b.criteria->>'count')::int;
    end if;

    if v_earned then
      insert into user_badges(user_id, badge_id) values (p_user, b.id)
      on conflict do nothing;
      if b.xp_reward > 0 then
        perform award_xp(p_user, b.xp_reward, 'badge_unlock', b.id);
      end if;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Trigger: when a lesson flips to 'completed', run the full reward pipeline.
-- ---------------------------------------------------------------------------
create or replace function on_lesson_completed()
returns trigger language plpgsql security definer
set search_path = public as $$
declare
  v_lesson lessons%rowtype;
  v_career uuid;
begin
  if new.status = 'completed' and coalesce(old.status,'') <> 'completed' then
    select * into v_lesson from lessons where id = new.lesson_id;
    select m.career_id into v_career from modules m where m.id = v_lesson.module_id;

    new.completed_at := now();
    perform award_xp(new.user_id, v_lesson.xp_reward, 'lesson_complete', v_lesson.id);
    perform touch_streak(new.user_id);
    perform recompute_career_progress(new.user_id, v_career);
    perform check_badges(new.user_id);
  end if;
  return new;
end $$;

create trigger trg_lesson_completed
  before update on lesson_progress
  for each row execute function on_lesson_completed();

-- ---------------------------------------------------------------------------
-- Auto-provision a profile row when a new auth user is created.
-- ---------------------------------------------------------------------------
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  insert into public.streaks(user_id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
