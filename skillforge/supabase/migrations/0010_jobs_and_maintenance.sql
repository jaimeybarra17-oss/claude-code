-- 0010_jobs_and_maintenance.sql
-- Scheduled-maintenance machinery referenced by the architecture: leaderboard
-- rank assignment, learning-gap resolution/decay, and monthly partition
-- rollover for the append-only hot-path tables.
--
-- These functions are invoked by a scheduler. On managed Supabase use either
-- pg_cron (example schedules at the bottom) or a Supabase Scheduled Function.

-- ---------------------------------------------------------------------------
-- Leaderboards: assign dense ranks within each board. Cheap because
-- leaderboard_entries is already aggregated (not a scan over all users).
-- ---------------------------------------------------------------------------
create or replace function assign_leaderboard_ranks()
returns void language plpgsql security definer
set search_path = public as $$
begin
  with ranked as (
    select id,
           row_number() over (
             partition by scope, period, period_key
             order by xp desc, updated_at asc
           ) as rnk
    from leaderboard_entries
  )
  update leaderboard_entries le
     set rank = ranked.rnk
    from ranked
   where ranked.id = le.id
     and le.rank is distinct from ranked.rnk;
end $$;

-- ---------------------------------------------------------------------------
-- Learning gaps: explicit resolution when mastery is demonstrated, plus a
-- decay pass that resolves stale, low-severity gaps so the coach doesn't nag
-- about things the learner has clearly moved past.
-- ---------------------------------------------------------------------------
create or replace function mark_gap_resolved(p_user uuid, p_topic text)
returns void language plpgsql security definer
set search_path = public as $$
begin
  update learning_gaps
     set status = 'resolved', resolved_at = now()
   where user_id = p_user and topic = p_topic and status <> 'resolved';
end $$;

create or replace function decay_stale_gaps()
returns void language plpgsql security definer
set search_path = public as $$
begin
  update learning_gaps
     set status = 'resolved', resolved_at = now()
   where status = 'open'
     and severity <= 2
     and last_seen_at < now() - interval '14 days';
end $$;

-- When an EXAM is passed, treat it as mastery of its module's career and gently
-- resolve that career's open gaps (best-effort; topic-precise resolution is the
-- mark_gap_resolved path called from the lesson flow).
create or replace function on_exam_passed()
returns trigger language plpgsql security definer
set search_path = public as $$
declare
  v_is_exam boolean;
  v_career uuid;
begin
  if new.passed then
    select q.is_exam, m.career_id into v_is_exam, v_career
      from quizzes q
      left join modules m on m.id = q.module_id
     where q.id = new.quiz_id;

    if v_is_exam and v_career is not null then
      update learning_gaps
         set status = 'reinforcing', last_seen_at = now()
       where user_id = new.user_id and career_id = v_career and status = 'open';
    end if;
  end if;
  return new;
end $$;

create trigger trg_exam_passed
  after insert on quiz_attempts
  for each row execute function on_exam_passed();

-- ---------------------------------------------------------------------------
-- Partition rollover: ensure next month's partition exists for each
-- range-partitioned hot-path table. Idempotent; safe to run daily.
-- ---------------------------------------------------------------------------
create or replace function ensure_month_partition(p_parent text, p_month date)
returns void language plpgsql as $$
declare
  v_start date := date_trunc('month', p_month)::date;
  v_end   date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_name  text := format('%s_%s', p_parent, to_char(v_start, 'YYYYMM'));
begin
  if not exists (select 1 from pg_class where relname = v_name) then
    execute format(
      'create table %I partition of %I for values from (%L) to (%L)',
      v_name, p_parent, v_start, v_end);
  end if;
end $$;

create or replace function roll_partitions_forward()
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_next date := (date_trunc('month', now()) + interval '1 month')::date;
begin
  perform ensure_month_partition('xp_ledger',   v_next);
  perform ensure_month_partition('ai_messages', v_next);
  perform ensure_month_partition('ai_usage',    v_next);
end $$;

-- ---------------------------------------------------------------------------
-- Example schedules (enable pg_cron, or replicate as Supabase Scheduled Funcs):
--
--   select cron.schedule('ranks-5m',  '*/5 * * * *', $$select assign_leaderboard_ranks()$$);
--   select cron.schedule('gaps-daily','30 3 * * *',  $$select decay_stale_gaps()$$);
--   select cron.schedule('partitions','0  0 28 * *', $$select roll_partitions_forward()$$);
--
-- Daily/weekly leaderboard *period* keys roll over automatically because
-- award_xp() writes to the current key; old keys simply stop receiving writes.
-- ---------------------------------------------------------------------------
