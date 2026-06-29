// generate-roadmap — turn a learner's onboarding answers into an ordered,
// time-boxed study plan across a career's modules, persisted to `roadmaps`.
//
// Uses OpenAI to pace + rationalize the plan, but ALWAYS falls back to a
// deterministic plan so onboarding never blocks on the model.

import { authenticate, cors, meter, OPENAI_MODEL } from "../_shared/ai.ts";

interface Body { careerId: string }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    const { careerId } = (await req.json()) as Body;
    if (!careerId) return json({ error: "careerId required" }, 400);

    const { data: onboarding } = await ctx.admin
      .from("onboarding_responses")
      .select("experience, weekly_minutes, learning_style, income_goal, career_goal")
      .eq("user_id", ctx.userId).maybeSingle();

    const { data: modules } = await ctx.admin
      .from("modules")
      .select("id, level, title, summary")
      .eq("career_id", careerId).eq("status", "published")
      .order("level");

    if (!modules?.length) return json({ error: "career has no modules" }, 422);

    const weekly = onboarding?.weekly_minutes ?? 150;
    // Deterministic baseline: ~2 levels/week scaled by available time.
    const perWeek = Math.max(1, Math.round(weekly / 120));
    const fallback = modules.map((m, i) => ({
      module_id: m.id,
      target_week: Math.floor(i / perWeek) + 1,
      rationale: `Level ${m.level}: ${m.title}`,
    }));

    let plan = fallback;
    let generatedBy = "default";

    // Try to enrich with AI rationales/pacing; fall back silently on any error.
    try {
      const prompt = [
        `Build a study plan for a ${onboarding?.experience ?? "beginner"} learner`,
        `with ${weekly} minutes/week. Goal: ${onboarding?.career_goal ?? "get hired"}.`,
        `Modules in order: ${modules.map((m) => `${m.level}. ${m.title}`).join("; ")}.`,
        `Return ONLY JSON: [{"level":N,"target_week":N,"rationale":"..."}].`,
      ].join(" ");

      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: OPENAI_MODEL,
          messages: [{ role: "user", content: prompt }],
          response_format: { type: "json_object" },
          temperature: 0.3,
        }),
      });
      const data = await res.json();
      const text = data.choices?.[0]?.message?.content ?? "[]";
      const parsed = JSON.parse(text);
      const items: { level: number; target_week: number; rationale: string }[] =
        Array.isArray(parsed) ? parsed : parsed.plan ?? [];

      if (items.length) {
        const byLevel = new Map(modules.map((m) => [m.level, m.id]));
        plan = items
          .filter((it) => byLevel.has(it.level))
          .map((it) => ({
            module_id: byLevel.get(it.level)!,
            target_week: it.target_week,
            rationale: it.rationale,
          }));
        generatedBy = "ai";
        await meter(ctx, "coach", Math.ceil(prompt.length / 4),
          Math.ceil(text.length / 4));
      }
    } catch (_) { /* keep deterministic fallback */ }

    await ctx.admin.from("roadmaps").upsert({
      user_id: ctx.userId, career_id: careerId, plan, generated_by: generatedBy,
    }, { onConflict: "user_id,career_id" });

    // Ensure an enrollment exists + set it active.
    await ctx.admin.from("enrollments").upsert({
      user_id: ctx.userId, career_id: careerId,
      current_module_id: modules[0].id,
    }, { onConflict: "user_id,career_id" });
    await ctx.admin.from("profiles")
      .update({ active_career_id: careerId }).eq("id", ctx.userId);

    return json({ plan, generatedBy });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}
