# SkillForge — Security & Trust Model

Enterprise-grade security for a platform handling learner PII, payment state, and
AI history at scale.

## Authentication

- Supabase Auth issues JWTs; the Flutter client stores them in secure storage
  (Keychain / Keystore), never in plain prefs.
- A `handle_new_user()` trigger provisions `profiles` + `streaks` on signup, so
  there is no window where an authenticated user lacks a profile.
- Staff accounts carry a custom JWT claim `user_role = 'admin'`, checked by the
  `is_admin()` SQL function — admin access is enforced in the database, not the UI.

## Authorization — Row-Level Security on every table

RLS is the backbone (migration `0009`). The model in one sentence per category:

- **Catalog** (careers/modules/lessons/simulations/badges/jobs): world-readable
  when `published`; writable only by admins.
- **Owner data** (enrollments, progress, resumes, applications, AI threads):
  readable/writable only by `user_id = auth.uid()`.
- **Gamification & billing** (xp_ledger, streaks, badges, subscriptions): **read-
  only** to the owner; written exclusively by `SECURITY DEFINER` functions or the
  verified Stripe webhook. Clients physically cannot forge XP or entitlements.
- **Quiz answer keys** (`quiz_questions.correct_option`): never exposed to
  learners — only `is_admin()` can select the table; grading runs server-side.

Because authorization lives in Postgres, the Flutter client can query the database
directly (via PostgREST) with no bespoke per-entity API tier, and every path is
guarded the same way.

## Server-authoritative boundaries

| Sensitive action | Enforced by |
| ---------------- | ----------- |
| Granting XP / coins / levels | `award_xp()` (SECURITY DEFINER) |
| Streak integrity | `touch_streak()` (server time, idempotent) |
| Quiz/exam grading | `grade-quiz` Edge Function (service role) |
| Entitlement changes | `stripe-webhook` after signature verification |
| AI key usage + rate limits | Edge Functions only; key never client-side |

## Payments

- Stripe is the system of record. `subscriptions.status` is written **only** by the
  webhook function, which verifies the Stripe signature before acting.
- Webhook events are de-duplicated via the `stripe_events` table (idempotency by
  event id) so retries can't double-apply.

## Data protection

- Postgres at rest is encrypted (managed Supabase); TLS in transit everywhere.
- Storage buckets are private by default; assets are served via signed URLs.
- PII minimization: we store only what onboarding needs; no government IDs.
- Partitioned `ai_messages` / `ai_usage` support retention policies (detach + purge
  old partitions) for GDPR/CCPA deletion at scale.

## Secrets & supply chain

- All secrets via environment (`functions/.env`, never committed —
  see `.env.example`). CI uses encrypted secrets.
- Dependencies are pinned (Deno import URLs are version-locked; Flutter via
  `pubspec.lock`).

## Privacy & compliance posture

- **Right to deletion:** cascading FKs from `profiles` purge all user rows on
  account deletion; partitioned event tables purge with the retention job.
- **Minors:** onboarding captures age; under-13 signups are blocked (COPPA), and
  community features can be gated by age.
- **AI transparency:** AI history is owned by the user, readable and deletable by
  them, and metered transparently.

## Threat model highlights

| Threat | Mitigation |
| ------ | ---------- |
| Forged progress / XP | RLS read-only + SECURITY DEFINER writes |
| Quiz answer leakage | Answer keys RLS-hidden; server grading |
| Stolen OpenAI key | Key server-side only; never shipped to client |
| Webhook spoofing | Stripe signature verification + idempotency log |
| Cross-user data access | `auth.uid()` predicates on every owner table |
| Privilege escalation | Admin gate in DB via signed JWT claim |
