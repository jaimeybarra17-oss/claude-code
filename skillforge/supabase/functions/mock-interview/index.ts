// mock-interview — the AI runs a realistic mock interview for a career and,
// on request, scores the session and stores feedback in mock_interviews.
//
// Actions:
//   "turn"     -> stream the next interviewer message (uses the interview thread)
//   "finalize" -> grade the transcript, persist score + structured feedback

import {
  authenticate, cors, enforceRateLimit, meter, OPENAI_MODEL,
  streamCompletion, type ChatMessage,
} from "../_shared/ai.ts";

interface Body {
  action: "turn" | "finalize";
  careerId: string;
  threadId?: string;
  message?: string;
}

const INTERVIEWER = `You are a hiring manager conducting a realistic but fair
mock interview for the candidate's chosen career. Ask one question at a time,
follow up on weak answers, and stay in character. Keep questions practical and
role-specific.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    await enforceRateLimit(ctx);
    const body = (await req.json()) as Body;
    if (!body.careerId) return json({ error: "careerId required" }, 400);

    const { data: career } = await ctx.admin
      .from("careers").select("name").eq("id", body.careerId).single();

    // Ensure an interview thread + mock_interviews row exist.
    let tid = body.threadId;
    if (!tid) {
      const { data: t } = await ctx.admin.from("ai_threads")
        .insert({ user_id: ctx.userId, surface: "interview", career_id: body.careerId })
        .select("id").single();
      tid = t?.id;
      await ctx.admin.from("mock_interviews")
        .insert({ user_id: ctx.userId, career_id: body.careerId, thread_id: tid });
    }

    // Load the running transcript.
    const { data: msgs } = await ctx.admin
      .from("ai_messages").select("role, content")
      .eq("thread_id", tid).order("created_at", { ascending: true });
    const history: ChatMessage[] = (msgs ?? []).map((m) => ({
      role: m.role as ChatMessage["role"], content: m.content,
    }));

    // ---- FINALIZE: grade the session -------------------------------------
    if (body.action === "finalize") {
      const transcript = history.map((m) => `${m.role}: ${m.content}`).join("\n");
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: OPENAI_MODEL,
          messages: [
            { role: "system", content: `Grade this ${career?.name} mock interview. Return ONLY JSON: {"score":0-100,"strengths":["..."],"weaknesses":["..."],"next_steps":["..."]}.` },
            { role: "user", content: transcript.slice(0, 8000) },
          ],
          response_format: { type: "json_object" },
          temperature: 0.3,
        }),
      });
      const data = await res.json();
      const feedback = JSON.parse(data.choices?.[0]?.message?.content ?? "{}");

      await ctx.admin.from("mock_interviews")
        .update({ score: feedback.score ?? null, feedback })
        .eq("thread_id", tid);
      await meter(ctx, "interview", Math.ceil(transcript.length / 4), 200);

      return json({ threadId: tid, feedback });
    }

    // ---- TURN: stream the next interviewer message -----------------------
    const messages: ChatMessage[] = [
      { role: "system", content: `${INTERVIEWER}\nCareer: ${career?.name}.` },
      ...history,
    ];
    if (body.message) {
      messages.push({ role: "user", content: body.message });
      await ctx.admin.from("ai_messages").insert({
        thread_id: tid, user_id: ctx.userId, role: "user", content: body.message,
      });
    }

    const promptTokens = Math.ceil(
      messages.reduce((n, m) => n + m.content.length, 0) / 4,
    );
    return streamCompletion(messages, async (full) => {
      await ctx.admin.from("ai_messages").insert({
        thread_id: tid, user_id: ctx.userId, role: "assistant", content: full,
      });
      await meter(ctx, "interview", promptTokens, Math.ceil(full.length / 4));
    });
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
