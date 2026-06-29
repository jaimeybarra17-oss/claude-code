# SkillForge — System Architecture

## 1. Goals & constraints

SkillForge must take a complete beginner to job-ready entirely in-app, across
trades and knowledge-work careers, while remaining:

- **Scalable to 100M+ users** — read-heavy learning traffic, bursty AI calls.
- **Secure by default** — learner data, payment state, and AI history are sensitive.
- **Modular** — adding a new career must not require schema changes.
- **Offline-tolerant** — lessons should degrade gracefully on poor connections.
- **Low operational cost** — a managed BaaS core keeps the team small.

## 2. High-level topology

```
            ┌─────────────────────────────────────────────┐
            │                 Clients                      │
            │   Flutter (iOS · Android · Web)              │
            └───────────────┬─────────────────────────────┘
                            │ HTTPS / WSS
            ┌───────────────▼─────────────────────────────┐
            │              Supabase Edge                   │
            │  • Auth (JWT)         • Realtime channels    │
            │  • PostgREST (CRUD)   • Storage (CDN assets) │
            │  • Edge Functions (Deno): ai-teacher,        │
            │    ai-coach, stripe-webhook, grade-quiz      │
            └───────┬───────────────────────┬──────────────┘
                    │                       │
        ┌───────────▼─────────┐   ┌─────────▼──────────────┐
        │   PostgreSQL 15     │   │     External APIs      │
        │  • RLS on every     │   │  • OpenAI (LLM)        │
        │    table            │   │  • Stripe (billing)    │
        │  • Gamification     │   │  • Firebase FCM (push) │
        │    triggers/fns     │   └────────────────────────┘
        │  • Partitioned      │
        │    event tables     │
        └─────────────────────┘
```

Clients talk to Postgres directly through PostgREST for ordinary CRUD (guarded by
RLS), and to **Edge Functions** for anything requiring a server secret (OpenAI key,
Stripe key) or server-authoritative logic (quiz grading, XP integrity).

## 3. Why this stack

- **Supabase** gives us Auth, a Postgres database, storage CDN, realtime, and Deno
  Edge Functions behind one product — the smallest possible surface for a small team
  to operate at scale. Postgres RLS lets us push authorization into the database so
  the client can query directly without a bespoke API tier for every entity.
- **Flutter** ships one codebase to iOS, Android, and Web — essential for a
  mobile-first product that also needs a web dashboard and an enterprise portal.
- **OpenAI via Edge Functions** keeps the API key server-side and lets us enforce
  per-plan rate limits and log token usage for the admin panel.

## 4. Core domains (bounded contexts)

| Domain          | Responsibility                                              | Key tables |
| --------------- | ----------------------------------------------------------- | ---------- |
| Identity        | Auth, profile, onboarding answers, plan                     | `profiles`, `onboarding_responses`, `subscriptions` |
| Catalog         | Careers → modules → lessons → simulations (content graph)   | `careers`, `modules`, `lessons`, `simulations`, `quizzes` |
| Learning        | Enrollment, per-lesson progress, quiz attempts, roadmaps    | `enrollments`, `lesson_progress`, `quiz_attempts`, `roadmaps` |
| Gamification    | XP, levels, coins, streaks, badges, leaderboards            | `xp_ledger`, `streaks`, `badges`, `user_badges`, `leaderboard_entries` |
| AI              | Teacher/coach threads, message history, remembered mistakes | `ai_threads`, `ai_messages`, `learning_gaps`, `ai_usage` |
| Certification   | Practice exams, certificates, readiness score               | `exams`, `exam_attempts`, `certificates` |
| Jobs            | Resumes, applications, saved jobs, mock interviews          | `resumes`, `job_listings`, `applications`, `mock_interviews` |
| Community       | Friends, study groups, clubs, discussion, mentorship        | `friendships`, `study_groups`, `posts`, `comments` |
| Billing         | Stripe subscription + entitlement state                     | `subscriptions`, `stripe_events` |
| Admin/Analytics | Moderation, content authoring, usage analytics              | views + `audit_log` |

The **content graph is fully data-driven**: a career is rows, not code. Adding
"Graphic Design" is an INSERT into `careers` + `modules` + `lessons`, never a deploy.

## 5. Server-authoritative logic

Some actions must never be trusted to the client:

- **XP / coin awards** — granted only by Postgres functions (`award_xp`) invoked
  from triggers when `lesson_progress` flips to `completed`, or from the
  `grade-quiz` Edge Function. The `xp_ledger` is append-only; the materialized total
  on `profiles` is maintained by trigger. Clients can read XP but never write it.
- **Quiz grading** — answer keys live in `quiz_questions.correct_option` which RLS
  hides from learners; grading runs in the `grade-quiz` Edge Function.
- **Streaks** — computed by `touch_streak()` against server time, idempotent per day.
- **Entitlements** — `subscriptions.status` is written only by the Stripe webhook
  function after signature verification.

## 6. Scaling strategy (→100M users)

1. **Read scaling.** Catalog content is immutable-ish and globally shared; it is
   served from PostgREST with aggressive CDN/edge caching and is a prime candidate
   for read replicas. Per-user rows are small and indexed on `user_id`.
2. **Write hot-paths.** High-frequency events (`xp_ledger`, `ai_messages`,
   `lesson_progress` history, analytics events) are **range-partitioned by month**
   so old partitions can be detached/archived cheaply.
3. **Leaderboards.** Computed incrementally into `leaderboard_entries` (career +
   period scoped) rather than `ORDER BY` over the whole user base; refreshed by a
   scheduled job. Hot global boards can move to Redis sorted sets later.
4. **AI cost & latency.** Edge Functions stream tokens to the client; usage is
   metered in `ai_usage` and rate-limited per plan. Prompt context is trimmed to a
   rolling window plus a compact "learner profile" summary, not the full history.
5. **Stateless compute.** Edge Functions hold no session state, so they scale
   horizontally with zero coordination.

## 7. Data flow examples

**Completing a lesson**

```
Client marks lesson_progress.status = 'completed'
   └─► AFTER UPDATE trigger on lesson_progress
         ├─ award_xp(user, lesson.xp_reward, 'lesson_complete')  → xp_ledger + profile total
         ├─ touch_streak(user)                                   → streaks
         ├─ recompute_career_progress(user, career)              → enrollments.progress_pct
         └─ check_badges(user)                                   → user_badges (e.g. "First Spark")
```

**Asking the AI Coach**

```
Client → POST /functions/v1/ai-coach { threadId, message }
   ├─ verify JWT, load plan, enforce ai_usage rate limit
   ├─ load thread window + learner profile + open learning_gaps
   ├─ stream OpenAI completion back to client (SSE)
   ├─ persist user + assistant messages to ai_messages
   └─ if the model flags a misconception, upsert into learning_gaps
```

## 8. Environments

- **local** — `supabase start`, OpenAI/Stripe in test mode, seeded curriculum.
- **staging** — full managed Supabase project, Stripe test, TestFlight/Internal track.
- **production** — managed Supabase (read replicas + PITR), Stripe live, store builds.

See [`DATA_MODEL.md`](DATA_MODEL.md) for the schema, [`AI_SYSTEM.md`](AI_SYSTEM.md)
for the mentor design, and [`SECURITY.md`](SECURITY.md) for the trust model.
