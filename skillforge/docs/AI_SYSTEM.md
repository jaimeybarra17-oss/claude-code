# SkillForge — AI System

Every learner has one adaptive mentor. The AI appears in four **surfaces**, all
backed by the same infrastructure (`ai_threads`, `ai_messages`, `learning_gaps`,
`ai_usage`) and the same Edge Function patterns.

| Surface | Function | Scope | Job |
| ------- | -------- | ----- | --- |
| Teacher | `ai-teacher` | one lesson | Explain, exemplify, generate practice, correct misconceptions |
| Coach | `ai-coach` | whole journey | Plan study, recommend next, motivate, "review my mistakes", "test me" |
| Exam | (coach reuse) | a module | Generate + grade practice exams |
| Interview | (coach reuse) | a career | Run mock interviews, score readiness |

## Why Edge Functions (not direct client → OpenAI)

1. **Secret safety** — the OpenAI key never leaves the server.
2. **Entitlements** — per-plan daily caps enforced in `enforceRateLimit()`.
3. **Server-authoritative context** — the function can read RLS-protected data
   (full progress, answer keys for grading) via the service role.
4. **Metering** — every call is logged to `ai_usage` for cost control + admin
   analytics.

## Prompt architecture

Each request is assembled as layered system context, kept compact to control cost:

```
[system]  Role + rules for the surface (teacher vs coach)
[system]  Learner card: name, level, XP, career, experience,
          weekly time, learning style, goal, and OPEN learning gaps
[system]  (teacher) the actual lesson material (JSONB body, truncated)
[...]     Rolling window of the last ~10-12 turns
[user]    The new message
```

We never resend full history. Older turns are compressed into
`ai_threads.summary` (a background job, roadmapped) so long relationships stay
cheap. Responses are **streamed** token-by-token to the client over plain-text SSE
for an instant, "alive" feel.

## Remembering mistakes (the adaptive loop)

This is what makes the mentor feel personal:

1. The **Teacher** is instructed, when it corrects a misconception, to append a
   machine-readable `GAP: <topic>` marker.
2. The function strips that marker from the visible reply and upserts the topic
   into `learning_gaps` (incrementing `occurrences`, raising `severity`).
3. The **Coach** loads open gaps into its learner card on every turn, so it
   proactively reinforces them and powers the "Review my mistakes" feature.
4. When the learner later demonstrates mastery (passes a related quiz/sim), a
   roadmapped trigger flips the gap to `resolved`.

```
Teacher corrects ──► GAP marker ──► learning_gaps (open)
                                          │
Coach turn ◄── learner card ◄────────────┘
                                          │
quiz/sim mastery ──► resolve gap ─────────┘
```

## Personalized roadmap generation

At onboarding completion we call a roadmap generator (coach surface) with the
questionnaire (`onboarding_responses`) and the career's module list. It returns an
ordered plan — `[{ module_id, target_week, rationale }]` — paced to the learner's
`weekly_minutes`, persisted in `roadmaps`. A deterministic default plan is used as
a fallback so onboarding never blocks on the model.

## Safety, cost & quality

- **Rate limiting:** free = 20 msgs/day; premium/enterprise effectively unlimited.
- **Grounding:** the Teacher is given the lesson material and told to stay on
  topic, reducing hallucination and keeping answers curriculum-aligned.
- **Model tiering:** default `gpt-4o-mini` for chat; escalate to a larger model
  for exam generation and resume review (configurable via `OPENAI_MODEL`).
- **Graceful degradation:** if OpenAI errors, surfaces fall back to cached tips and
  the deterministic roadmap so the product never hard-fails on AI.

Implementation: `supabase/functions/ai-coach/index.ts`,
`supabase/functions/ai-teacher/index.ts`, shared helpers in `_shared/ai.ts`.
