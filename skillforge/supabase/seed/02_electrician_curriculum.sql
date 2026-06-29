-- 02_electrician_curriculum.sql
-- The full 10-level Electrician path: modules, representative lessons, the
-- signature simulations, a sample graded quiz, and the career's badges.
-- This is the canonical template every other career mirrors.

do $$
declare
  c_id uuid;
  m_id uuid;
  sim_safety uuid;
  sim_panel  uuid;
  sim_volt   uuid;
  sim_trouble uuid;
  q_id uuid;
begin
  select id into c_id from careers where slug = 'electrician';

  -- -------------------------------------------------------------------------
  -- Modules (Levels 1..10)
  -- -------------------------------------------------------------------------
  insert into modules (career_id, level, title, summary, xp_reward) values
    (c_id, 1,  'Electrical Safety',  'PPE, lockout/tagout, arc flash, and working safely with live circuits.', 150),
    (c_id, 2,  'Hand Tools',         'Identify and correctly use the electrician''s core tools.', 120),
    (c_id, 3,  'Wire Identification','Gauges, insulation types, color codes, and ampacity.', 120),
    (c_id, 4,  'Residential Wiring', 'Outlets, switches, lighting, and branch circuits in homes.', 200),
    (c_id, 5,  'Commercial Wiring',  'Conduit, three-phase basics, and commercial loads.', 220),
    (c_id, 6,  'Blueprint Reading',  'Electrical symbols, plans, and one-line diagrams.', 160),
    (c_id, 7,  'Code Requirements',  'Navigating the NEC and passing inspection.', 200),
    (c_id, 8,  'Troubleshooting',    'Systematic fault diagnosis with the right instruments.', 240),
    (c_id, 9,  'Panels',             'Service panels, breakers, grounding, and load balancing.', 240),
    (c_id, 10, 'Master Electrician', 'Capstone: design, estimate, and lead a full install.', 400)
  on conflict (career_id, level) do nothing;

  -- -------------------------------------------------------------------------
  -- Signature simulations
  -- -------------------------------------------------------------------------
  insert into simulations (career_id, slug, title, description, engine, difficulty, config, xp_reward) values
    (c_id, 'house-wiring', 'Virtual House Wiring',
     'Wire a room to code: run cable, land conductors, and energize safely.',
     'wiring', 2,
     '{"rooms":["kitchen"],"circuits":[{"type":"gfci","load":"counter_outlets"}],"checks":["polarity","ground","gfci_trip"]}', 120),
    (c_id, 'breaker-panel', 'Breaker Panel Builder',
     'Populate a load center, balance phases, and size breakers correctly.',
     'panel', 3,
     '{"bus":"200A","slots":40,"loads":["range","dryer","hvac","lighting"],"goal":"balance_phases"}', 120),
    (c_id, 'voltage-testing', 'Voltage Testing Lab',
     'Use a multimeter to verify voltage, continuity, and dead circuits.',
     'meter', 1,
     '{"instruments":["multimeter","non_contact"],"tasks":["verify_120v","verify_dead","continuity"]}', 80),
    (c_id, 'circuit-troubleshoot', 'Circuit Troubleshooting',
     'A dead outlet — find the fault: open neutral, tripped GFCI, or loose wire?',
     'wiring', 4,
     '{"fault":"open_neutral","symptoms":["no_power","downstream_dead"],"tools":["multimeter"]}', 150)
  on conflict (career_id, slug) do nothing;

  select id into sim_safety  from simulations where career_id = c_id and slug = 'voltage-testing';
  select id into sim_panel   from simulations where career_id = c_id and slug = 'breaker-panel';
  select id into sim_volt    from simulations where career_id = c_id and slug = 'voltage-testing';
  select id into sim_trouble from simulations where career_id = c_id and slug = 'circuit-troubleshoot';

  -- -------------------------------------------------------------------------
  -- Level 1 lessons (the template; other levels follow the same shape)
  -- -------------------------------------------------------------------------
  select id into m_id from modules where career_id = c_id and level = 1;

  insert into lessons (module_id, position, title, kind, est_minutes, xp_reward, body) values
    (m_id, 1, 'Why Electricity Is Dangerous', 'concept', 5, 20,
     '{"blocks":[{"type":"text","md":"Electricity can injure in three ways: **shock**, **arc flash**, and **arc blast**. As little as 50 mA across the heart can be fatal."},{"type":"callout","style":"warning","md":"Treat every conductor as live until you have personally tested it dead."}]}'),
    (m_id, 2, 'Personal Protective Equipment', 'concept', 6, 20,
     '{"blocks":[{"type":"text","md":"PPE is your last line of defense: insulated gloves rated for the voltage, safety glasses, and arc-rated clothing for panel work."}]}'),
    (m_id, 3, 'Lockout / Tagout', 'video', 7, 25,
     '{"blocks":[{"type":"video","asset":"loto-intro"},{"type":"text","md":"De-energize, lock the disconnect, tag it with your name, and verify zero energy before touching anything."}]}'),
    (m_id, 4, 'Verify Dead: Voltage Testing', 'simulation', 10, 80,
     '{"blocks":[{"type":"text","md":"Practice the test-before-touch rule on a real meter."}]}')
  on conflict (module_id, position) do nothing;

  -- Link the simulation lesson to the voltage-testing sim.
  update lessons set simulation_id = sim_volt
   where module_id = m_id and position = 4;

  -- -------------------------------------------------------------------------
  -- A graded quiz for Level 1 (answer keys are RLS-hidden from learners).
  -- -------------------------------------------------------------------------
  insert into quizzes (module_id, title, pass_score, xp_reward)
  values (m_id, 'Electrical Safety Check', 70, 50)
  returning id into q_id;

  insert into quiz_questions (quiz_id, position, prompt, options, correct_option, explanation) values
    (q_id, 1, 'What is the FIRST step before working on a circuit?',
     '["Put on gloves","De-energize and verify it is dead","Call an inspector","Strip the wires"]', 1,
     'Always de-energize and verify zero voltage before contact — test before touch.'),
    (q_id, 2, 'Roughly how much current across the heart can be fatal?',
     '["50 mA","5 A","120 A","Only above 240 V"]', 0,
     'As little as ~50 mA through the chest can cause ventricular fibrillation.'),
    (q_id, 3, 'What does the tag in lockout/tagout communicate?',
     '["The wire gauge","Who de-energized the equipment and that it must stay off","The circuit number","The breaker brand"]', 1,
     'The tag identifies who locked it out so no one re-energizes it.')
  on conflict (quiz_id, position) do nothing;

  -- -------------------------------------------------------------------------
  -- Electrician badges (data-driven criteria evaluated by check_badges()).
  -- -------------------------------------------------------------------------
  insert into badges (slug, name, description, icon, tier, criteria, xp_reward) values
    ('first_spark', 'First Spark', 'Complete your first electrician lesson.', '⚡', 'bronze',
     '{"type":"lessons_completed","career_slug":"electrician","count":1}', 25),
    ('safety_first', 'Safety First', 'Finish the Electrical Safety level.', '🦺', 'silver',
     '{"type":"lessons_completed","career_slug":"electrician","count":4}', 75),
    ('journeyman', 'Journeyman', 'Complete 50 electrician lessons.', '🔌', 'gold',
     '{"type":"lessons_completed","career_slug":"electrician","count":50}', 250)
  on conflict (slug) do nothing;

  -- Universal badges (career-agnostic).
  insert into badges (slug, name, description, icon, tier, criteria, xp_reward) values
    ('week_warrior', 'Week Warrior', 'Maintain a 7-day streak.', '🔥', 'silver',
     '{"type":"streak","count":7}', 100),
    ('rising_star', 'Rising Star', 'Earn 1,000 total XP.', '🌟', 'silver',
     '{"type":"total_xp","count":1000}', 100)
  on conflict (slug) do nothing;
end $$;
