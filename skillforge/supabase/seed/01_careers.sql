-- 01_careers.sql — the launch career catalog.
-- Salary figures are US national approximations used for projection UI only.

insert into careers (slug, name, tagline, category, icon, accent_color,
                     entry_salary, median_salary, senior_salary, est_weeks_to_job, sort_order)
values
  ('electrician',  'Electrician',       'Wire the world, safely.',            'trades', '⚡', '#F5A623', 42000, 60000, 98000, 24, 1),
  ('hvac',         'HVAC Technician',   'Master heating & cooling.',          'trades', '❄️', '#4FC3F7', 40000, 57000, 90000, 20, 2),
  ('plumbing',     'Plumbing',          'Keep it flowing.',                   'trades', '🔧', '#29B6F6', 41000, 60000, 99000, 22, 3),
  ('welding',      'Welding',           'Join metal, build everything.',      'trades', '🔥', '#FF7043', 40000, 48000, 75000, 18, 4),
  ('cdl',          'CDL / Truck Driving','Drive your future forward.',        'trades', '🚛', '#8D6E63', 45000, 60000, 90000, 8,  5),
  ('day_trading',  'Day Trading',       'Read the market. Manage risk.',      'knowledge_work', '📈', '#26A69A', 0, 0, 0, 16, 6),
  ('sales',        'Sales',             'Turn conversations into closes.',    'knowledge_work', '🤝', '#AB47BC', 45000, 70000, 160000, 12, 7),
  ('real_estate',  'Real Estate',       'Help people find home.',             'knowledge_work', '🏠', '#66BB6A', 40000, 65000, 150000, 14, 8),
  ('cybersecurity','Cybersecurity',     'Defend the digital world.',          'knowledge_work', '🛡️', '#5C6BC0', 65000, 105000, 165000, 20, 9),
  ('software_dev', 'Software Development','Build what people use every day.',  'knowledge_work', '💻', '#42A5F5', 70000, 110000, 180000, 24, 10)
on conflict (slug) do nothing;
