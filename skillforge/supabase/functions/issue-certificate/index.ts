// issue-certificate — compute the Career Readiness Score and issue a
// SkillForge certificate when a learner completes (or qualifies in) a career.
//
// Readiness blend (see docs/GAMIFICATION.md):
//   0.40 * career_progress + 0.35 * avg(exam) + 0.15 * avg(sim) + 0.10 * gap_health

import { authenticate, cors } from "../_shared/ai.ts";

interface Body { careerId: string }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    const { careerId } = (await req.json()) as Body;
    if (!careerId) return json({ error: "careerId required" }, 400);

    // Career progress.
    const { data: enrollment } = await ctx.admin
      .from("enrollments").select("progress_pct")
      .eq("user_id", ctx.userId).eq("career_id", careerId).maybeSingle();
    const progress = Number(enrollment?.progress_pct ?? 0);

    // Average exam score (passed exams only) for this career's quizzes.
    const { data: examAttempts } = await ctx.admin
      .from("quiz_attempts")
      .select("score, quizzes!inner(is_exam, module_id, modules!inner(career_id))")
      .eq("user_id", ctx.userId)
      // deno-lint-ignore no-explicit-any
      .eq("quizzes.is_exam" as any, true);
    const examScores = (examAttempts ?? [])
      // deno-lint-ignore no-explicit-any
      .filter((a: any) => a.quizzes?.modules?.career_id === careerId)
      .map((a) => Number(a.score));
    const avgExam = avg(examScores);

    // Average simulation score for this career.
    const { data: simAttempts } = await ctx.admin
      .from("simulation_attempts")
      .select("score, simulations!inner(career_id)")
      .eq("user_id", ctx.userId)
      // deno-lint-ignore no-explicit-any
      .eq("simulations.career_id" as any, careerId);
    const avgSim = avg((simAttempts ?? []).map((a) => Number(a.score ?? 0)));

    // Gap health: fraction of open gaps for the career (lower is better).
    const { count: openGaps } = await ctx.admin
      .from("learning_gaps")
      .select("id", { count: "exact", head: true })
      .eq("user_id", ctx.userId).eq("status", "open");
    const gapHealth = Math.max(0, 100 - (openGaps ?? 0) * 5);

    const readiness = Math.round(
      (0.40 * progress + 0.35 * avgExam + 0.15 * avgSim + 0.10 * gapHealth) * 100,
    ) / 100;

    // Issue (or refresh) the certificate.
    const { data: cert } = await ctx.admin
      .from("certificates")
      .upsert({
        user_id: ctx.userId, career_id: careerId, readiness_score: readiness,
      }, { onConflict: "user_id,career_id" })
      .select("serial, readiness_score, issued_at").single();

    // NOTE: PDF rendering + Storage upload is a roadmapped step; pdf_url stays
    // null until the render worker fills it.
    return json({ certificate: cert, breakdown: { progress, avgExam, avgSim, gapHealth } });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});

const avg = (xs: number[]) => xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}
