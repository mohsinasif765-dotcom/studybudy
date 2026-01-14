import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno&no-check";

serve(async (req) => {
  console.log("----------------------------------------------------------------");
  console.log(`🚀 [WEBHOOK] Stripe Event Received`);

  // 1. Signature Check
  const signature = req.headers.get("Stripe-Signature");
  if (!signature) {
    console.error("❌ [WEBHOOK] Missing Stripe Signature");
    return new Response("No Signature", { status: 400 });
  }

  try {
    // Init Clients
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
      apiVersion: '2024-06-20',
      httpClient: Stripe.createFetchHttpClient(),
    });

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.text();
    let event;

    // 2. Verify Webhook Signature
    try {
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET")!
      );
      console.log(`✅ [WEBHOOK] Signature Verified. Event: ${event.type}`);
    } catch (err: any) {
      console.error(`⚠️ [WEBHOOK] Signature Error: ${err.message}`);
      return new Response(err.message, { status: 400 });
    }

    // 3. ✅ HANDLE CHECKOUT SUCCESS
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      const sessionId = session.id; 
      
      console.log(`💳 [PAYMENT] Processing Session: ${sessionId}`);

      // 🛑 IDEMPOTENCY CHECK
      const { data: existing } = await supabaseAdmin
        .from('processed_payments')
        .select('payment_id')
        .eq('payment_id', sessionId)
        .single();

      if (existing) {
        console.log(`✋ [PAYMENT] Already processed. Skipping.`);
        return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" }});
      }

      // --- PROCESS NEW PAYMENT ---
      const userId = session.metadata?.user_id; 
      const planId = session.metadata?.plan_id; 
      const interval = session.metadata?.interval;

      console.log(`🔔 [PAYMENT] User: ${userId}, Plan: ${planId}, Interval: ${interval}`);

      if (userId && planId) {
        
        // A. Fetch Plan details DIRECTLY from DB
        console.log(`📥 [DB] Fetching plan details for: ${planId}`);
        const { data: planData } = await supabaseAdmin
          .from('plans')
          .select('*') // Get everything
          .eq('id', planId)
          .single();

        if (!planData) {
            console.error(`❌ Plan ${planId} not found in DB.`);
            throw new Error("Plan not found");
        }

        // ✅ NO MATH NEEDED: Credits are already correct in DB for yearly plans
        const creditsToAdd = planData.credits; 
        
        const isVip = planId.includes('pro') || planId.includes('vip');
        console.log(`💎 [PLAN] Credits to add: ${creditsToAdd}, VIP: ${isVip}`);

        // B. Expiry Logic (Only for Mini Pack)
        let expiryDate = null;
        if (planData.interval === 'week') {
           const date = new Date();
           date.setDate(date.getDate() + 7); 
           expiryDate = date.toISOString().split('T')[0];
           console.log(`🗓️ [EXPIRY] Weekly Plan detected. Expires: ${expiryDate}`);
        }

        // C. Get Current Profile
        // const { data: profile } = await supabaseAdmin
        //   .from('profiles')
        //   .select('credits_total')
        //   .eq('id', userId)
        //   .single();

        // D. Calculate New Total (Actually, for subscription start/upgrade, usually we reset/set limits)
        // For simplicity and alignment with payment manager, we set the total limit to the plan limit.
        // If you want cumulative, you'd add. But typically upgrades replace limits.
        // Assuming replacement logic as per payment manager:
        
        // 👇 MAIN UPDATE (Updated for credits_remaining)
        const updateData: any = {
          credits_total: creditsToAdd,      // Set Total Limit
          credits_remaining: creditsToAdd,  // Set Full Balance
          credits_used: 0,                  // Reset Usage
          plan_id: planId,
          is_vip: isVip,
          credits_expiry: expiryDate,
          payment_provider: 'stripe'
        };

        if (session.subscription) {
            updateData.stripe_subscription_id = session.subscription;
            updateData.google_purchase_token = null;
            updateData.huawei_subscription_id = null;
            console.log(`🆔 [SUB] Linked Subscription ID: ${session.subscription}`);
        }

        const { error: updateError } = await supabaseAdmin
            .from('profiles')
            .update(updateData)
            .eq('id', userId);

        if (updateError) {
            console.error("❌ [DB] Update Error:", updateError);
            throw new Error("Failed to update profile");
        }

        // E. Send Alert
        await supabaseAdmin.from('user_alerts').insert({
          user_id: userId,
          title: "Payment Successful! 💎",
          message: `Activated ${planData.name}. ${creditsToAdd} credits added.`,
          type: isVip ? 'vip' : 'credits'
        });

        // 🛑 F. MARK AS PROCESSED
        await supabaseAdmin.from('processed_payments').insert({
          payment_id: sessionId,
          user_id: userId
        });
        
        console.log("✅ [SUCCESS] Payment processed completely.");
      } else {
          console.warn("⚠️ [PAYMENT] Missing metadata (userId or planId).");
      }
    }

    // 4. ✅ HANDLE SUBSCRIPTION DELETED
    if (event.type === 'customer.subscription.deleted') {
        const subscription = event.data.object;
        console.log(`📉 [CANCEL] Subscription Deleted: ${subscription.id}`);
        
        const { data: userProfile } = await supabaseAdmin
            .from('profiles')
            .select('id')
            .eq('stripe_subscription_id', subscription.id)
            .single();

        if (userProfile) {
            console.log(`👤 [CANCEL] Found user: ${userProfile.id}. Resetting...`);
            
            // 👇 Updated to reset credits_remaining as well
            await supabaseAdmin.from('profiles').update({
                plan_id: 'free',
                is_vip: false,
                credits_total: 50,      // Reset Limit
                credits_remaining: 50,  // Reset Balance
                credits_used: 0,
                credits_expiry: null,
                stripe_subscription_id: null,
                payment_provider: null
            }).eq('id', userProfile.id);
            
            await supabaseAdmin.from('user_alerts').insert({
              user_id: userProfile.id,
              title: "Subscription Ended",
              message: "Your plan has expired and you are now on the Free plan.",
              type: "info"
            });

            console.log(`✅ [CANCEL] User reset to Free.`);
        } else {
            console.log(`⚠️ [CANCEL] No user found for this subscription.`);
        }
    }

    return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" }});

  } catch (error: any) {
    console.error("🔥 [ERROR] Webhook Failed:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 200, headers: { "Content-Type": "application/json" }});
  }
});