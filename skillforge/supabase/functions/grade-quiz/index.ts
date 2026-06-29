// grade-quiz — server-authoritative quiz/exam grading.
//
// Answer keys (quiz_questions.correct_option) are RLS-hidden from learners, so
// grading MUST happen here with the service role. We score the submission,
// record a quiz_attempt, and — on a pass — award XP via the SECURITY DEFINER
// award_xp function (which the client can never call to forge XP).

import { authenticate, cors } from "../_shared/ai.ts";

interface Submission {
  quizId: string;
  answers: { question_id: string; chosen: number }[];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    const { quizId, answers } = (await req.json()) as Submission;

    if (!quizId || !Array.isArray(answers)) {
      return json({ error: "quizId and answers required" }, 400);
    }

    // Load quiz + its answer key (service role bypasses RLS).
    const { data: quiz } = await ctx.admin
      .from("quizzes")
      .select("id, lesson_id, module_id, pass_score, xp_reward, is_exam")
      .eq("id", quizId).single();
    if (!quiz) return json({ error: "quiz not found" }, 404);

    const { data: questions } = await ctx.admin
      .from("quiz_questions")
      .select("id, correct_option, explanation")
      .eq("quiz_id", quizId);

    const key = new Map(
      (questions ?? []).map((q) => [q.id, q]),
    );
    const total = key.size;
    if (total === 0) return json({ error: "quiz has no questions" }, 422);

    // Grade.
    let correct = 0;
    const graded = answers.map((a) => {
      const q = key.get(a.question_id);
      const isCorrect = q ? q.correct_option === a.chosen : false;
      if (isCorrect) correct++;
      return {
        question_id: a.question_id,
        chosen: a.chosen,
        correct: isCorrect,
        explanation: q?.explanation ?? null,
      };
    });

    const score = Math.round((correct / total) * 10000) / 100; // 2dp
    const passed = score >= Number(quiz.pass_score);

    // Record the attempt.
    await ctx.admin.from("quiz_attempts").insert({
      user_id: ctx.userId, quiz_id: quizId, score, passed, answers: graded,
    });

    // Award XP only on a first pass for this quiz (avoid farming).
    let awardedXp = 0;
    if (passed) {
      const { count } = await ctx.admin
        .from("quiz_attempts")
        .select("id", { count: "exact", head: true })
        .eq("user_id", ctx.userId).eq("quiz_id", quizId).eq("passed", true);

      if ((count ?? 0) <= 1) {
        awardedXp = quiz.xp_reward;
        await ctx.admin.rpc("award_xp", {
          p_user: ctx.userId,
          p_amount: quiz.xp_reward,
          p_reason: quiz.is_exam ? "exam_pass" : "quiz_pass",
          p_ref: quizId,
          p_coins: 0,
        });
      }
    }

    return json({ score, passed, correct, total, awardedXp, answers: graded });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
