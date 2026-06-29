// _shared/ai.ts
// Shared helpers for SkillForge AI Edge Functions: CORS, authenticated Supabase
// clients, per-plan rate limiting, OpenAI streaming, and usage metering.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

// Per-day AI message caps by plan. Free is intentionally limited; premium and
// enterprise are effectively unlimited. Enforced against ai_usage.
export const DAILY_LIMITS: Record<string, number> = {
  free: 20,
  premium: 100000,
  enterprise: 1000000,
};

export interface AuthContext {
  userId: string;
  plan: string;
  // Service-role client: bypasses RLS to read answer keys / write metering.
  admin: SupabaseClient;
}

/** Validate the caller's JWT and load their plan. Throws Response on failure. */
export async function authenticate(req: Request): Promise<AuthContext> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) {
    throw new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const admin = createClient(url, service);
  const { data: profile } = await admin
    .from("profiles").select("plan").eq("id", user.id).single();

  return { userId: user.id, plan: profile?.plan ?? "free", admin };
}

/** Enforce the per-day message cap for the caller's plan. */
export async function enforceRateLimit(ctx: AuthContext): Promise<void> {
  const limit = DAILY_LIMITS[ctx.plan] ?? DAILY_LIMITS.free;
  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);

  const { count } = await ctx.admin
    .from("ai_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", ctx.userId)
    .gte("created_at", since.toISOString());

  if ((count ?? 0) >= limit) {
    throw new Response(
      JSON.stringify({ error: "rate_limited", message: "Daily AI limit reached. Upgrade to Premium for unlimited mentoring." }),
      { status: 429, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
}

/** Record an AI call for metering + admin analytics. */
export async function meter(
  ctx: AuthContext, surface: string, promptTokens: number, outputTokens: number,
): Promise<void> {
  // gpt-4o-mini approx pricing; adjust per model.
  const cost = (promptTokens * 0.15 + outputTokens * 0.6) / 1_000_000;
  await ctx.admin.from("ai_usage").insert({
    user_id: ctx.userId, surface, model: OPENAI_MODEL,
    prompt_tokens: promptTokens, output_tokens: outputTokens, cost_usd: cost,
  });
}

export interface ChatMessage { role: "system" | "user" | "assistant"; content: string; }

/**
 * Stream a chat completion from OpenAI as Server-Sent text deltas.
 * Returns a Response whose body streams plain text chunks to the client and,
 * on completion, invokes onDone with the full text for persistence.
 */
export function streamCompletion(
  messages: ChatMessage[],
  onDone: (fullText: string) => Promise<void>,
): Response {
  const apiKey = Deno.env.get("OPENAI_API_KEY")!;
  const stream = new ReadableStream({
    async start(controller) {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: OPENAI_MODEL, messages, stream: true, temperature: 0.5,
        }),
      });

      const reader = res.body!.getReader();
      const decoder = new TextDecoder();
      const encoder = new TextEncoder();
      let full = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        for (const line of decoder.decode(value).split("\n")) {
          const trimmed = line.replace(/^data: /, "").trim();
          if (!trimmed || trimmed === "[DONE]") continue;
          try {
            const delta = JSON.parse(trimmed).choices?.[0]?.delta?.content;
            if (delta) { full += delta; controller.enqueue(encoder.encode(delta)); }
          } catch { /* keep-alive / partial frame */ }
        }
      }
      await onDone(full);
      controller.close();
    },
  });

  return new Response(stream, {
    headers: { ...cors, "Content-Type": "text/plain; charset=utf-8" },
  });
}
