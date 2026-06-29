// ai-coach — the personal AI Career Coach.
//
// Responsibilities:
//   * Authenticate + rate-limit per plan.
//   * Build a context-rich prompt: learner profile, active career, current
//     progress, and OPEN learning gaps (so the coach "remembers mistakes").
//   * Stream the answer back to the client.
//   * Persist the turn and meter usage.
//
// The coach can answer: "How do I become an electrician?", "What should I study
// next?", "Test me", "Create today's study plan", "Review my mistakes", etc.

import {
  authenticate, cors, enforceRateLimit, meter, streamCompletion, type ChatMessage,
} from "../_shared/ai.ts";

const SYSTEM = `You are the SkillForge AI Career Coach — an encouraging, expert
mentor who takes complete beginners to job-ready. You are concrete and practical.
Rules:
- Adapt difficulty to the learner's experience level.
- When the learner struggles, explain with plain language and a real-world example.
- Reference the learner's OPEN learning gaps and gently reinforce them.
- When asked to "test me", produce a short quiz and wait for answers.
- When asked for a study plan, give a specific, time-boxed plan for their weekly time.
- Keep answers focused; prefer steps and examples over walls of text.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    await enforceRateLimit(ctx);

    const { threadId, message } = await req.json();
    if (!message) {
      return new Response(JSON.stringify({ error: "message required" }), {
        status: 400, headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // --- Assemble learner context (service role, bypasses RLS) ----------------
    const { data: profile } = await ctx.admin
      .from("profiles")
      .select("display_name, level, total_xp, active_career_id, careers:active_career_id(name)")
      .eq("id", ctx.userId).single();

    const { data: onboarding } = await ctx.admin
      .from("onboarding_responses")
      .select("experience, weekly_minutes, learning_style, income_goal, career_goal")
      .eq("user_id", ctx.userId).maybeSingle();

    const { data: gaps } = await ctx.admin
      .from("learning_gaps")
      .select("topic, detail, severity")
      .eq("user_id", ctx.userId).eq("status", "open")
      .order("severity", { ascending: false }).limit(5);

    const careerName =
      // deno-lint-ignore no-explicit-any
      (profile as any)?.careers?.name ?? "their chosen career";

    const learnerCard = [
      `Learner: ${profile?.display_name ?? "there"} (Level ${profile?.level ?? 1}, ${profile?.total_xp ?? 0} XP)`,
      `Career: ${careerName}`,
      onboarding && `Experience: ${onboarding.experience}; Weekly time: ${onboarding.weekly_minutes} min; Style: ${onboarding.learning_style}`,
      onboarding?.career_goal && `Goal: ${onboarding.career_goal}`,
      gaps?.length
        ? `Open learning gaps to reinforce: ${gaps.map((g) => g.topic).join(", ")}`
        : "No recorded learning gaps yet.",
    ].filter(Boolean).join("\n");

    // --- Rolling thread window ----------------------------------------------
    let history: ChatMessage[] = [];
    if (threadId) {
      const { data: msgs } = await ctx.admin
        .from("ai_messages")
        .select("role, content")
        .eq("thread_id", threadId)
        .order("created_at", { ascending: false }).limit(12);
      history = (msgs ?? []).reverse().map((m) => ({
        role: m.role as ChatMessage["role"], content: m.content,
      }));
    }

    // Ensure a thread exists.
    let tid = threadId;
    if (!tid) {
      const { data: t } = await ctx.admin.from("ai_threads")
        .insert({ user_id: ctx.userId, surface: "coach", career_id: profile?.active_career_id })
        .select("id").single();
      tid = t?.id;
    }

    const messages: ChatMessage[] = [
      { role: "system", content: SYSTEM },
      { role: "system", content: learnerCard },
      ...history,
      { role: "user", content: message },
    ];

    // Persist the user turn immediately.
    await ctx.admin.from("ai_messages").insert({
      thread_id: tid, user_id: ctx.userId, role: "user", content: message,
    });

    const promptTokens = Math.ceil(
      messages.reduce((n, m) => n + m.content.length, 0) / 4,
    );

    return streamCompletion(messages, async (full) => {
      await ctx.admin.from("ai_messages").insert({
        thread_id: tid, user_id: ctx.userId, role: "assistant", content: full,
      });
      await ctx.admin.from("ai_threads")
        .update({ updated_at: new Date().toISOString() }).eq("id", tid);
      await meter(ctx, "coach", promptTokens, Math.ceil(full.length / 4));
    });
  } catch (e) {
    if (e instanceof Response) return e;
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
