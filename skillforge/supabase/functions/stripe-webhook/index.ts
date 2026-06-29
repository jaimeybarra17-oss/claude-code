// stripe-webhook — the ONLY writer of subscription/entitlement state.
//
// Verifies the Stripe signature, de-duplicates via the stripe_events table,
// and syncs subscriptions + profiles.plan. No JWT here: the trust comes from
// the signature, not a user session.

import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  const raw = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(raw, sig!, webhookSecret);
  } catch (err) {
    return new Response(`Webhook signature verification failed: ${err}`, { status: 400 });
  }

  // Idempotency: skip events we've already processed.
  const { error: dupeErr } = await admin
    .from("stripe_events").insert({ id: event.id, type: event.type });
  if (dupeErr) {
    // Unique violation => already handled; ack so Stripe stops retrying.
    return new Response(JSON.stringify({ received: true, deduped: true }), { status: 200 });
  }

  try {
    switch (event.type) {
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        const userId = sub.metadata.user_id ??
          await userIdFromCustomer(sub.customer as string);
        if (!userId) break;

        const active = sub.status === "active" || sub.status === "trialing";
        const plan = active ? "premium" : "free";

        await admin.from("subscriptions").upsert({
          user_id: userId,
          stripe_customer_id: sub.customer as string,
          stripe_subscription_id: sub.id,
          plan,
          status: sub.status as string,
          current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
          cancel_at_period_end: sub.cancel_at_period_end,
          updated_at: new Date().toISOString(),
        }, { onConflict: "user_id" });

        // Entitlement mirror on the profile (drives UI gating).
        await admin.from("profiles").update({ plan }).eq("id", userId);
        break;
      }
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.user_id;
        if (userId && session.customer) {
          await admin.from("subscriptions").upsert({
            user_id: userId,
            stripe_customer_id: session.customer as string,
          }, { onConflict: "user_id" });
        }
        break;
      }
    }
    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (e) {
    return new Response(`Handler error: ${e}`, { status: 500 });
  }
});

async function userIdFromCustomer(customerId: string): Promise<string | null> {
  const { data } = await admin
    .from("subscriptions").select("user_id")
    .eq("stripe_customer_id", customerId).maybeSingle();
  return data?.user_id ?? null;
}
