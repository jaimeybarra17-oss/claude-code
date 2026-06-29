// ai-teacher — the in-lesson AI Instructor.
//
// Scoped to a specific lesson: it explains the current concept, answers
// questions about it, generates examples and practice questions, and adapts to
// the learner's pace. When it detects a misconception it records a learning_gap
// so the coach can reinforce it later.

import {
  authenticate, cors, enforceRateLimit, meter, streamCompletion, type ChatMessage,
} from "../_shared/ai.ts";

const SYSTEM = `You are the SkillForge AI Teacher embedded inside a specific
lesson. Teach the CURRENT lesson clearly and step by step.
- Explain difficult ideas with simple language and a concrete example.
- If the learner asks for practice, generate 2-3 questions about THIS lesson.
- If the learner reveals a misconception, correct it kindly and precisely.
- Stay on the lesson topic; if asked something off-topic, briefly redirect.
At the very end of a correction, append a single line in the exact form
"GAP: <short_topic>" so the platform can remember it. Never show that line for
non-corrections.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const ctx = await authenticate(req);
    await enforceRateLimit(ctx);

    const { threadId, lessonId, message } = await req.json();
    if (!message || !lessonId) {
      return new Response(JSON.stringify({ error: "lessonId and message required" }), {
        status: 400, headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // Load the lesson + its career so the teacher has the material in context.
    const { data: lesson } = await ctx.admin
      .from("lessons")
      .select("title, body, modules:module_id(title, careers:career_id(id, name, slug))")
      .eq("id", lessonId).single();

    // deno-lint-ignore no-explicit-any
    const mod = (lesson as any)?.modules;
    const careerName = mod?.careers?.name ?? "this career";
    const careerSlug = mod?.careers?.slug ?? null;
    const careerId = mod?.careers?.id ?? null;

    const lessonCard = [
      `Career: ${careerName}. Module: ${mod?.title}. Lesson: ${lesson?.title}.`,
      `Lesson material (JSON): ${JSON.stringify(lesson?.body).slice(0, 4000)}`,
    ].join("\n");

    let tid = threadId;
    if (!tid) {
      const { data: t } = await ctx.admin.from("ai_threads")
        .insert({ user_id: ctx.userId, surface: "teacher", lesson_id: lessonId })
        .select("id").single();
      tid = t?.id;
    }

    let history: ChatMessage[] = [];
    const { data: msgs } = await ctx.admin
      .from("ai_messages").select("role, content")
      .eq("thread_id", tid).order("created_at", { ascending: false }).limit(10);
    history = (msgs ?? []).reverse().map((m) => ({
      role: m.role as ChatMessage["role"], content: m.content,
    }));

    const messages: ChatMessage[] = [
      { role: "system", content: SYSTEM },
      { role: "system", content: lessonCard },
      ...history,
      { role: "user", content: message },
    ];

    await ctx.admin.from("ai_messages").insert({
      thread_id: tid, user_id: ctx.userId, role: "user", content: message,
    });

    const promptTokens = Math.ceil(
      messages.reduce((n, m) => n + m.content.length, 0) / 4,
    );

    return streamCompletion(messages, async (full) => {
      // Extract + persist any detected learning gap, then strip the marker.
      const gapMatch = full.match(/GAP:\s*([a-z0-9_\- ]+)/i);
      const visible = full.replace(/\n?GAP:\s*[a-z0-9_\- ]+/i, "").trim();

      await ctx.admin.from("ai_messages").insert({
        thread_id: tid, user_id: ctx.userId, role: "assistant", content: visible,
      });

      if (gapMatch && careerSlug) {
        const topic = gapMatch[1].trim().toLowerCase().replace(/\s+/g, "_");
        await ctx.admin.from("learning_gaps").upsert({
          user_id: ctx.userId, topic,
          career_id: careerId, // lets the exam-pass trigger reinforce this gap
          detail: `Detected in lesson "${lesson?.title}"`,
          status: "open",
        }, { onConflict: "user_id,topic", ignoreDuplicates: false });
      }

      await meter(ctx, "teacher", promptTokens, Math.ceil(full.length / 4));
    });
  } catch (e) {
    if (e instanceof Response) return e;
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
