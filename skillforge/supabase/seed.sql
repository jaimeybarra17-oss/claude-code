-- seed.sql — aggregated seed run by `supabase db reset`.
-- Order matters: careers must exist before curriculum.
\i seed/01_careers.sql
\i seed/02_electrician_curriculum.sql
\i seed/03_all_careers_curriculum.sql

-- Daily challenge for today (universal).
insert into daily_challenges (career_id, for_date, title, description, challenge, xp_reward, coin_reward)
values (null, current_date, 'Daily Warm-up', 'Complete one lesson in your active career today.',
        '{"type":"complete_lesson","count":1}', 30, 10)
on conflict (career_id, for_date) do nothing;
