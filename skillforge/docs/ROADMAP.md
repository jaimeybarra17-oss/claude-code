# SkillForge — Roadmap & Status

Honest accounting of what this repository delivers today versus what is sequenced
next. This is a **platform foundation**, not a finished 100M-user app — but every
piece here is real and coherent, and the hard architectural decisions are made.

## ✅ Delivered in this foundation

**Architecture & docs**
- System architecture, scaling strategy, data flows (`ARCHITECTURE.md`)
- Data model rationale (`DATA_MODEL.md`)
- Design system: dark-first tokens, components, dashboard layout (`DESIGN_SYSTEM.md`)
- AI mentor design: prompt layering, adaptive learning-gap loop (`AI_SYSTEM.md`)
- Gamification spec: XP curve, streaks, badges, readiness score (`GAMIFICATION.md`)
- Security & trust model (`SECURITY.md`)

**Backend (Supabase / Postgres)**
- Complete schema across 10 migrations: identity, catalog, learning, gamification,
  simulations, AI, certifications, jobs, community, billing, admin audit, and
  scheduled-maintenance jobs
- Row-Level Security on **every** table
- Server-authoritative gamification engine: `award_xp`, `touch_streak`,
  `recompute_career_progress`, `check_badges`, level curve, leaderboard bumps
- Scheduled maintenance (0010): leaderboard rank assignment, learning-gap
  resolution/decay, monthly partition rollover
- Partitioned hot-path tables (xp_ledger, ai_messages, ai_usage)
- Auto-provisioning of profiles on signup

**Content**
- All 10 launch careers seeded
- **Every career broken into its 10 levels**, each with its signature
  "learn by doing" simulations, an intro lesson, a Level-1 graded quiz, and a
  starter badge — data-driven, mirroring the Electrician template
- Full Electrician vertical slice: modules, multiple lessons, 4 simulations, a
  graded quiz with answer key, and career + universal badges

**AI / Edge Functions** (8 functions)
- `ai-coach`, `ai-teacher`: JWT auth, per-plan rate limiting, context assembly,
  OpenAI streaming, usage metering, and the adaptive learning-gap loop
- `grade-quiz`: server-authoritative grading vs. RLS-hidden answer keys + XP award
- `generate-roadmap`: AI-paced plan with deterministic fallback; sets enrollment
- `issue-certificate`: Career Readiness Score blend + certificate issuance
- `resume-feedback`: scored, sectioned AI resume review
- `mock-interview`: streamed AI interview with a finalize/scoring path
- `stripe-webhook`: signature-verified, idempotent entitlement sync

**Client (Flutter)**
- App scaffold: theme system from design tokens, routing, config, Supabase
  bootstrap, core data models, unit test pinning the level curve to SQL
- Five-tab shell (Learn · Practice · Coach · Jobs · Profile) with full screens:
  dashboard, onboarding, AI coach chat, lesson player, practice grid, jobs hub,
  and profile

## 🔜 Next (sequenced)

1. **Curriculum depth** — author the remaining lessons for every level across all
   careers (pure content; the modules/sims/quizzes/badges already exist).
2. **Simulation engines** — implement the Flutter renderers: wiring board, breaker
   panel, multimeter, candlestick chart-replay, sales dialogue trees.
3. **Billing UI** — Stripe checkout + customer portal in-app (webhook sync done).
4. **Notifications** — Firebase Cloud Messaging for streak reminders & challenges.
5. **Community** — friends, study groups, clubs, discussion UI on the existing schema.
6. **Admin panel** — web console over the admin-scoped RLS policies + audit log.
7. **Certificate render worker** — PDF generation + Storage upload for `pdf_url`.
8. **Offline mode** — local cache of lessons for the premium offline feature.

## ⚙️ Engineering hardening (ongoing)

- CI: `supabase db lint`, migration tests, `flutter analyze` + widget tests.
- Load tests against the read hot-paths; add read replicas in production.
- Observability: structured logs from Edge Functions → analytics; AI cost dashboards.
- pgTAP tests for the gamification functions (XP/streak/badge correctness).

## Definition of "v1 launch"

All 10 careers have ≥5 fleshed levels, all signature simulations playable, billing
live, certificates issuable, push notifications on, and the admin panel usable by
content staff. The schema and architecture in this repo are designed to reach that
without structural rewrites.
