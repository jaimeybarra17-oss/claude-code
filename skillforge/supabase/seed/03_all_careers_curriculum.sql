-- 03_all_careers_curriculum.sql
-- The 10-level module progression, signature simulations, an intro lesson, a
-- Level-1 quiz, and a starter badge for the other nine launch careers. Written
-- data-driven (VALUES joined to careers) to stay compact and consistent with
-- the Electrician template in 02. Lessons here are intentionally seeded one per
-- career (the canonical first lesson); deeper lessons are authored over time.

-- ---------------------------------------------------------------------------
-- Modules (Levels 1..10) for all nine careers in one statement.
-- ---------------------------------------------------------------------------
insert into modules (career_id, level, title, xp_reward)
select c.id, v.level, v.title,
       case when v.level = 10 then 400 when v.level >= 5 then 200 else 120 end
from careers c
join (values
  -- HVAC ---------------------------------------------------------------------
  ('hvac', 1,'HVAC Safety & Basics'),('hvac',2,'Tools & Instruments'),
  ('hvac', 3,'The Refrigeration Cycle'),('hvac',4,'Electrical for HVAC'),
  ('hvac', 5,'Heating Systems'),('hvac',6,'Air Conditioning Systems'),
  ('hvac', 7,'Airflow & Ductwork'),('hvac',8,'System Diagnostics'),
  ('hvac', 9,'Installation & Charging'),('hvac',10,'EPA 608 & Master HVAC'),
  -- Plumbing -----------------------------------------------------------------
  ('plumbing',1,'Plumbing Safety & Codes'),('plumbing',2,'Tools & Materials'),
  ('plumbing',3,'Pipe Types & Fittings'),('plumbing',4,'Measuring & Cutting'),
  ('plumbing',5,'Water Supply Systems'),('plumbing',6,'Drain, Waste & Vent'),
  ('plumbing',7,'Fixtures & Appliances'),('plumbing',8,'Water Heaters'),
  ('plumbing',9,'Leak Diagnosis & Repair'),('plumbing',10,'Master Plumber'),
  -- Welding ------------------------------------------------------------------
  ('welding',1,'Welding Safety & PPE'),('welding',2,'Tools & Equipment'),
  ('welding',3,'Metals & Joints'),('welding',4,'Oxy-Fuel & Cutting'),
  ('welding',5,'SMAW (Stick)'),('welding',6,'GMAW (MIG)'),
  ('welding',7,'GTAW (TIG)'),('welding',8,'Blueprints & Symbols'),
  ('welding',9,'Inspection & Defects'),('welding',10,'Certified Welder'),
  -- CDL / Truck Driving ------------------------------------------------------
  ('cdl',1,'CDL Basics & Licensing'),('cdl',2,'Vehicle Systems'),
  ('cdl',3,'Pre-Trip Inspection'),('cdl',4,'Controls & Shifting'),
  ('cdl',5,'Backing & Docking'),('cdl',6,'Coupling & Uncoupling'),
  ('cdl',7,'City & Highway Driving'),('cdl',8,'Hazard & Weather Driving'),
  ('cdl',9,'Hours of Service & Logs'),('cdl',10,'CDL Exam Ready'),
  -- Day Trading --------------------------------------------------------------
  ('day_trading',1,'Markets & Mechanics'),('day_trading',2,'Brokers & Order Types'),
  ('day_trading',3,'Candlesticks & Charts'),('day_trading',4,'Chart Patterns'),
  ('day_trading',5,'Technical Indicators'),('day_trading',6,'Risk Management'),
  ('day_trading',7,'Trading Strategies'),('day_trading',8,'Market Psychology'),
  ('day_trading',9,'Journaling & Review'),('day_trading',10,'Funded Trader'),
  -- Sales --------------------------------------------------------------------
  ('sales',1,'Sales Fundamentals'),('sales',2,'Prospecting & Cold Outreach'),
  ('sales',3,'Discovery & Qualifying'),('sales',4,'Building Rapport'),
  ('sales',5,'Presentations & Demos'),('sales',6,'Objection Handling'),
  ('sales',7,'Negotiation'),('sales',8,'Closing Techniques'),
  ('sales',9,'Pipeline & CRM'),('sales',10,'Top Closer'),
  -- Real Estate --------------------------------------------------------------
  ('real_estate',1,'Real Estate Basics'),('real_estate',2,'Licensing & Law'),
  ('real_estate',3,'Property Types & Valuation'),('real_estate',4,'Listings & Marketing'),
  ('real_estate',5,'Buyer Representation'),('real_estate',6,'Showings & Open Houses'),
  ('real_estate',7,'Offers & Contracts'),('real_estate',8,'Negotiation & Closing'),
  ('real_estate',9,'Financing & Mortgages'),('real_estate',10,'Top Producer'),
  -- Cybersecurity ------------------------------------------------------------
  ('cybersecurity',1,'Security Fundamentals'),('cybersecurity',2,'Networking Basics'),
  ('cybersecurity',3,'Operating Systems & Linux'),('cybersecurity',4,'Threats & Attacks'),
  ('cybersecurity',5,'Cryptography'),('cybersecurity',6,'Network Security'),
  ('cybersecurity',7,'Vulnerability Assessment'),('cybersecurity',8,'Incident Response'),
  ('cybersecurity',9,'Security Operations (SOC)'),('cybersecurity',10,'Certified Analyst'),
  -- Software Development -----------------------------------------------------
  ('software_dev',1,'Programming Basics'),('software_dev',2,'Data Structures'),
  ('software_dev',3,'Algorithms'),('software_dev',4,'Version Control with Git'),
  ('software_dev',5,'Web Fundamentals'),('software_dev',6,'Databases & SQL'),
  ('software_dev',7,'APIs & Backend'),('software_dev',8,'Testing & Debugging'),
  ('software_dev',9,'System Design'),('software_dev',10,'Job-Ready Engineer')
) as v(slug, level, title) on c.slug = v.slug
on conflict (career_id, level) do nothing;

-- ---------------------------------------------------------------------------
-- Signature simulations per career (the "learn by doing" set from the spec).
-- ---------------------------------------------------------------------------
insert into simulations (career_id, slug, title, engine, difficulty, config, xp_reward)
select c.id, v.sim_slug, v.title, v.engine, v.difficulty, v.config::jsonb, 100
from careers c
join (values
  ('hvac','diagnose-system','Diagnose a Failing System','diagnostic',3,'{"fault":"low_charge"}'),
  ('hvac','read-gauges','Read the Manifold Gauges','meter',2,'{"task":"superheat"}'),
  ('hvac','replace-component','Replace a Capacitor','procedure',2,'{"part":"run_capacitor"}'),
  ('hvac','repair-ac','Repair an AC Unit','diagnostic',4,'{"symptom":"no_cooling"}'),

  ('plumbing','pipe-install','Install a Pipe Run','procedure',2,'{"material":"pex"}'),
  ('plumbing','leak-repair','Find & Fix a Leak','diagnostic',3,'{"leak":"slip_joint"}'),
  ('plumbing','drain-system','Build a DWV Drain','procedure',3,'{"fixture":"sink"}'),
  ('plumbing','water-heater','Service a Water Heater','procedure',3,'{"task":"replace_element"}'),

  ('welding','bead-practice','Lay a Straight Bead','welding',1,'{"process":"mig"}'),
  ('welding','joint-fitup','Fit Up a T-Joint','procedure',2,'{"joint":"tee"}'),
  ('welding','mig-sim','MIG Welding Simulator','welding',3,'{"process":"gmaw"}'),
  ('welding','weld-inspect','Inspect a Weld','inspection',2,'{"defects":["porosity","undercut"]}'),

  ('cdl','pretrip','Pre-Trip Inspection','inspection',2,'{"area":"engine_bay"}'),
  ('cdl','backing','Back the Trailer','driving',3,'{"maneuver":"offset_back"}'),
  ('cdl','parking','Alley Dock Parking','driving',3,'{"maneuver":"alley_dock"}'),
  ('cdl','highway','Highway Driving','driving',2,'{"scenario":"merge_and_follow"}'),
  ('cdl','weather','Adverse Weather Driving','driving',4,'{"condition":"rain_night"}'),

  ('day_trading','candlestick-replay','Candlestick Replay','chart_replay',2,'{"symbol":"AAPL","bars":120}'),
  ('day_trading','market-sim','Market Simulator','chart_replay',3,'{"mode":"live_sim"}'),
  ('day_trading','risk-mgmt','Position Sizing & Risk','calc',2,'{"account":25000,"risk_pct":1}'),
  ('day_trading','paper-trade','Paper Trading Session','chart_replay',2,'{"capital":10000}'),
  ('day_trading','chart-patterns','Spot the Pattern','quiz_visual',2,'{"patterns":["bull_flag","head_shoulders"]}'),

  ('sales','cold-call','Cold Call Roleplay','dialogue',2,'{"persona":"busy_gatekeeper"}'),
  ('sales','objection','Objection Handling','dialogue',3,'{"objection":"too_expensive"}'),
  ('sales','negotiation','Negotiate the Deal','dialogue',4,'{"persona":"price_anchorer"}'),
  ('sales','close','Close the Deal','dialogue',3,'{"stage":"closing"}'),

  ('real_estate','valuation','Price a Property','valuation',2,'{"comps":3}'),
  ('real_estate','listing-pitch','Listing Presentation','dialogue',3,'{"persona":"skeptical_seller"}'),
  ('real_estate','offer-negotiation','Negotiate an Offer','dialogue',4,'{"gap":"15000"}'),
  ('real_estate','closing-walk','Closing Walkthrough','procedure',2,'{"checklist":"final_walk"}'),

  ('cybersecurity','phishing-triage','Triage a Phishing Report','triage',2,'{"email":"spoofed_invoice"}'),
  ('cybersecurity','packet-analysis','Analyze the Traffic','packet',3,'{"capture":"port_scan"}'),
  ('cybersecurity','vuln-scan','Run a Vulnerability Scan','procedure',3,'{"target":"web_app"}'),
  ('cybersecurity','incident-response','Contain an Incident','tabletop',4,'{"scenario":"ransomware"}'),

  ('software_dev','coding-challenge','Solve a Coding Challenge','coding',2,'{"problem":"two_sum"}'),
  ('software_dev','debugging','Find the Bug','coding',3,'{"bug":"off_by_one"}'),
  ('software_dev','git-workflow','Git Branch & Merge','procedure',2,'{"task":"resolve_conflict"}'),
  ('software_dev','api-build','Build a REST Endpoint','coding',3,'{"endpoint":"GET /users"}'),
  ('software_dev','system-design','Whiteboard a System','design',4,'{"prompt":"url_shortener"}')
) as v(slug, sim_slug, title, engine, difficulty, config)
  on c.slug = v.slug
-- NOTE: the join column names below come from the VALUES list above.
where v.sim_slug is not null
on conflict (career_id, slug) do nothing;

-- ---------------------------------------------------------------------------
-- One intro lesson per career (Level 1, position 1) so every path is playable.
-- ---------------------------------------------------------------------------
insert into lessons (module_id, position, title, kind, est_minutes, xp_reward, body)
select m.id, 1, v.title, 'concept', 5, 20, v.body::jsonb
from modules m
join careers c on c.id = m.career_id and m.level = 1
join (values
  ('hvac','Welcome to HVAC','{"blocks":[{"type":"text","md":"HVAC keeps buildings comfortable and safe. You will master the refrigeration cycle, electrical troubleshooting, and EPA-certified handling of refrigerants."}]}'),
  ('plumbing','Welcome to Plumbing','{"blocks":[{"type":"text","md":"Plumbers protect the health of nations. You will learn supply, drain-waste-vent, and how to diagnose leaks fast."}]}'),
  ('welding','Welcome to Welding','{"blocks":[{"type":"text","md":"Welding joins the metal that builds the world. Safety first: light, fumes, and heat all demand respect."}]}'),
  ('cdl','Welcome to Truck Driving','{"blocks":[{"type":"text","md":"A CDL opens the road to a high-paying career fast. You will master inspections, backing, and safe highway driving."}]}'),
  ('day_trading','Welcome to Day Trading','{"blocks":[{"type":"text","md":"Trading rewards discipline, not luck. Job one is risk management; everything else builds on protecting capital."},{"type":"callout","style":"warning","md":"Never risk money you cannot afford to lose. We trade on paper first."}]}'),
  ('sales','Welcome to Sales','{"blocks":[{"type":"text","md":"Sales is the highest-leverage skill in business. You will learn to prospect, discover needs, handle objections, and close."}]}'),
  ('real_estate','Welcome to Real Estate','{"blocks":[{"type":"text","md":"Help people find home while building wealth. You will learn valuation, contracts, and negotiation."}]}'),
  ('cybersecurity','Welcome to Cybersecurity','{"blocks":[{"type":"text","md":"Defenders keep the digital world running. You will learn networks, threats, and incident response from the ground up."}]}'),
  ('software_dev','Welcome to Software Development','{"blocks":[{"type":"text","md":"Code is the most leveraged tool ever built. You will go from first program to system design and job-ready interviews."}]}')
) as v(slug, title, body) on c.slug = v.slug
on conflict (module_id, position) do nothing;

-- ---------------------------------------------------------------------------
-- A Level-1 quiz (2 questions) + a starter badge for each of the nine careers.
-- Done in a loop so we can fetch the generated quiz id per career.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  q_id uuid;
begin
  for r in
    select c.slug, c.name, m.id as module_id
    from careers c
    join modules m on m.career_id = c.id and m.level = 1
    where c.slug <> 'electrician'
  loop
    insert into quizzes (module_id, title, pass_score, xp_reward)
    values (r.module_id, r.name || ' Basics Check', 70, 50)
    returning id into q_id;

    insert into quiz_questions (quiz_id, position, prompt, options, correct_option, explanation) values
      (q_id, 1, 'What should always come first in ' || r.name || '?',
       '["Speed","Safety and fundamentals","Advanced tricks","Skipping the basics"]', 1,
       'Master the fundamentals and work safely before anything advanced.'),
      (q_id, 2, 'How do you build real skill on SkillForge?',
       '["Only watch videos","Learn by doing with simulations and practice","Memorize without practice","Skip the quizzes"]', 1,
       'Every skill is paired with interactive practice — you learn by doing.')
    on conflict (quiz_id, position) do nothing;

    insert into badges (slug, name, description, icon, tier, criteria, xp_reward)
    values (r.slug || '_starter', r.name || ' Starter',
            'Complete your first ' || r.name || ' lesson.', '🚀', 'bronze',
            jsonb_build_object('type','lessons_completed','career_slug',r.slug,'count',1), 25)
    on conflict (slug) do nothing;
  end loop;
end $$;
