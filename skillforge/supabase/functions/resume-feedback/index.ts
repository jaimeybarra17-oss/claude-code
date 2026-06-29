// resume-feedback — AI review of a learner's structured resume. Returns a
// scored, sectioned critique and persists it to resumes.ai_feedback.

import { authenticate, cors, enforceRateLimit, meter, OPENAI_MODEL } from "../_shared/ai.ts";

interface Body { resumeId: string }

const SYSTEM = `You are a senior recruiter for skilled-trades and tech roles.
Review the resume JSON and return ONLY JSON of the form:
{"score":0-100,"strengths":["..."],"improvements":["..."],
 "missing_keywords":["..."],"rewrite_suggestions":[{"section":"...","before":"...","after":"..."}]}.
Be specific and actionable; tailor to the target career.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    await enforceRateLimit(ctx);
    const { resumeId } = (await req.json()) as Body;
    if (!resumeId) return json({ error: "resumeId required" }, 400);

    const { data: resume } = await ctx.admin
      .from("resumes").select("id, content")
      .eq("id", resumeId).eq("user_id", ctx.userId).maybeSingle();
    if (!resume) return json({ error: "resume not found" }, 404);

    const prompt = `Resume JSON:\n${JSON.stringify(resume.content).slice(0, 6000)}`;

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        messages: [
          { role: "system", content: SYSTEM },
          { role: "user", content: prompt },
        ],
        response_format: { type: "json_object" },
        temperature: 0.4,
      }),
    });
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content ?? "{}";
    const feedback = JSON.parse(text);

    await ctx.admin.from("resumes")
      .update({ ai_feedback: feedback, updated_at: new Date().toISOString() })
      .eq("id", resumeId);
    await meter(ctx, "coach", Math.ceil(prompt.length / 4), Math.ceil(text.length / 4));

    return json({ feedback });
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
