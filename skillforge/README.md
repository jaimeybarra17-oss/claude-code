# SkillForge

**The Duolingo for High-Income Careers.**

SkillForge turns complete beginners into job-ready professionals through AI-driven
lessons, hands-on simulations, gamified progression, and a personal AI mentor that
adapts to every learner. Launch careers span the skilled trades (Electrician, HVAC,
Plumbing, Welding, CDL/Truck Driving) and high-income knowledge work (Day Trading,
Sales, Real Estate, Cybersecurity, Software Development), with an architecture built
for unlimited future career paths.

> This repository contains the **platform foundation**: system architecture, a
> production-grade Supabase/PostgreSQL data model (with Row-Level Security and the
> gamification engine), seed curriculum, AI Edge Functions, a design system, and a
> structured Flutter client scaffold. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for
> exactly what is implemented here versus what is sequenced next.

---

## Repository layout

```
skillforge/
├── docs/                     # Architecture, data model, design system, AI, gamification
│   ├── ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   ├── DESIGN_SYSTEM.md
│   ├── AI_SYSTEM.md
│   ├── GAMIFICATION.md
│   ├── SECURITY.md
│   └── ROADMAP.md
├── supabase/
│   ├── migrations/           # Ordered SQL migrations (schema, RLS, triggers)
│   ├── seed/                 # Careers + Electrician curriculum seed data
│   └── functions/            # Deno Edge Functions (AI teacher, AI coach)
└── app/                      # Flutter client (mobile-first, web-capable)
    ├── pubspec.yaml
    └── lib/
        ├── core/             # Theme, config, routing
        ├── data/             # Models, repositories
        └── features/         # Onboarding, dashboard, learning, AI coach
```

## Tech stack

| Layer          | Choice                                  |
| -------------- | --------------------------------------- |
| Client         | Flutter (iOS, Android, Web)             |
| Backend / BaaS | Supabase (Postgres, Auth, Storage, Edge Functions) |
| Database       | PostgreSQL 15 + Row-Level Security      |
| AI             | OpenAI API via Supabase Edge Functions  |
| Payments       | Stripe (subscriptions + webhooks)       |
| Notifications  | Firebase Cloud Messaging                |
| State mgmt     | Riverpod                                |
| Routing        | go_router                               |

## Quick start (backend)

```bash
# 1. Install the Supabase CLI and start a local stack
supabase start

# 2. Apply migrations (schema, RLS, gamification triggers)
supabase db reset            # runs migrations/ in order, then seed.sql

# 3. Serve Edge Functions locally
supabase functions serve --env-file supabase/functions/.env
```

`supabase/seed.sql` aggregates the career catalog and the full 10-level Electrician
curriculum so a fresh database boots with real content.

## Quick start (Flutter client)

```bash
cd app
cp .env.example .env          # add SUPABASE_URL / SUPABASE_ANON_KEY
flutter pub get
flutter run                   # mobile; or: flutter run -d chrome
```

## Design principles

1. **Learn by doing.** Every skill is paired with an interactive simulation, not just text.
2. **Measurable mastery.** XP, level mastery %, and a Career Readiness Score quantify progress.
3. **One mentor per learner.** The AI Coach remembers mistakes and adapts difficulty.
4. **Scale from day one.** Stateless Edge compute + Postgres RLS is built for 100M users.
5. **Apple-level polish.** Dark-first design system, fluid motion, zero clutter.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) to go deeper.
