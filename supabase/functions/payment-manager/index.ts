// ✅ FIX: Using 'npm:' import to avoid Deno/Node compatibility issues
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "npm:stripe@^14.21.0";

console.log("🚀 [SYSTEM] Payment Manager Function Initialized - FULL DEBUG MODE");

serve(async (req) => {
  // 1. CORS Headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
  };

  // Pre-flight Check
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Shared Admin Client (Service Role for DB Writes)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // ========================================================================
    // 🕵️ STRIPE WEBHOOK DETECTION
    // ========================================================================
    const signature = req.headers.get("Stripe-Signature");

    if (signature) {
      console.log(`\n🔔 [WEBHOOK START] Stripe Event Received.`);
      console.log(`🔐 [SECURITY] Verifying Signature...`);

      // ✅ FIX: Standard Stripe Init for NPM
      const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
        apiVersion: '2024-06-20',
      });

      const body = await req.text();
      let event;

      try {
        // Construct Event from Signature
        event = await stripe.webhooks.constructEventAsync(
          body,
          signature,
          Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET")!
        );
        console.log(`✅ [WEBHOOK VALID] Signature Verified. Event Type: ${event.type}`);
      } catch (err: any) {
        console.error(`❌ [WEBHOOK ERROR] Signature Verification Failed: ${err.message}`);
        return new Response(`Webhook Error: ${err.message}`, { status: 400 });
      }

      // --- 1. HANDLE SUCCESSFUL PAYMENT ---
      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const sessionId = session.id;

        console.log(`\n💰 [PAYMENT PROCESSING] Session ID: ${sessionId}`);
        
        console.log(`🔍 [DEBUG DATA] Raw Metadata from Stripe:`, JSON.stringify(session.metadata, null, 2));

        const userId = session.metadata?.user_id;
        const planId = session.metadata?.plan_id;

        if (!userId || !planId) {
            console.error("❌ [CRITICAL FAIL] UserID or PlanID is MISSING in Stripe Metadata.");
            return new Response("Missing Metadata", { status: 400 });
        }
        
        console.log(`👤 [USER IDENTIFIED] Target User ID: ${userId}`);
        console.log(`📦 [PLAN IDENTIFIED] Target Plan ID: ${planId}`);

        console.log(`🔍 [DB CHECK] Checking 'processed_payments' to avoid duplicates...`);
        const { data: existing } = await supabaseAdmin
          .from('processed_payments')
          .select('payment_id')
          .eq('payment_id', sessionId)
          .single();

        if (existing) {
          console.log(`✋ [DUPLICATE BLOCKED] Payment ID ${sessionId} already processed.`);
          return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" } });
        }

        console.log(`📥 [DB READ] Fetching Plan details from 'plans' table...`);
        const { data: planData, error: planError } = await supabaseAdmin.from('plans').select('*').eq('id', planId).single();
        
        if (planError || !planData) {
            console.error(`❌ [DB ERROR] Plan '${planId}' not found. Database Error: ${planError?.message}`);
            throw new Error("Plan not found");
        }
        console.log(`✅ [PLAN DATA] Name: ${planData.name} | Credits: ${planData.credits} | Interval: ${planData.interval}`);

        let expiryDate = null;
        const now = new Date();
        
        if (planData.interval === 'week') {
            console.log("📅 [EXPIRY LOGIC] Weekly Plan Detected. Adding 7 days.");
            now.setDate(now.getDate() + 7);
            expiryDate = now.toISOString().split('T')[0];
        } else if (planData.interval === 'month') {
            now.setMonth(now.getMonth() + 1);
            expiryDate = now.toISOString().split('T')[0];
        } else if (planData.interval === 'year') {
            now.setFullYear(now.getFullYear() + 1);
            expiryDate = now.toISOString().split('T')[0];
        }
        console.log(`🗓️ [DATE CALC] New Expiry Date Set To: ${expiryDate}`);

        const updateData: any = {
            credits_total: planData.credits,
            credits_remaining: planData.credits,
            credits_used: 0,
            plan_id: planId,
            is_vip: false, 
            credits_expiry: expiryDate,
            payment_provider: 'stripe'
        };

        if (session.subscription) {
            updateData.stripe_subscription_id = session.subscription;
            updateData.stripe_customer_id = session.customer;
            console.log(`🔗 [STRIPE SYNC] Linking Subscription ID: ${session.subscription}`);
        } else {
             if (session.customer) {
                 updateData.stripe_customer_id = session.customer;
             }
        }

        console.log(`🛠 [DB WRITE] Executing UPDATE on 'profiles' table for User: ${userId}`);
        
        const { data: updatedProfile, error: updateError } = await supabaseAdmin
            .from('profiles')
            .update(updateData)
            .eq('id', userId)
            .select(); 

        if (updateError) {
            console.error("❌ [DB FATAL ERROR] Profile Update Failed:", updateError.message);
            throw updateError;
        } 
        
        if (!updatedProfile || updatedProfile.length === 0) {
            console.error(`⚠️ [CRITICAL WARNING] Query ran successfully but NO ROW WAS UPDATED.`);
        } else {
            console.log("✅ [DB SUCCESS] Profile updated successfully!");
        }

        const alertData = {
            user_id: userId,
            title: "Payment Successful! 🎉",
            message: `Your ${planData.name} plan is now active. ${planData.credits} credits added.`,
            type: 'vip'
        };
        console.log(`🔔 [DB INSERT] Adding User Alert...`);
        await supabaseAdmin.from('user_alerts').insert(alertData);

        console.log(`🏁 [DB INSERT] Saving to 'processed_payments'...`);
        await supabaseAdmin.from('processed_payments').insert({
            payment_id: sessionId,
            user_id: userId
        });

        console.log(`✨ [COMPLETE] Payment Processing Finished for ${sessionId}`);
      }

      // --- 2. HANDLE SUBSCRIPTION DELETED ---
      if (event.type === 'customer.subscription.deleted') {
          const subscription = event.data.object;
          console.log(`📉 [WEBHOOK - CANCEL] Subscription Deleted Event: ${subscription.id}`);

          const { data: userProfile } = await supabaseAdmin
            .from('profiles')
            .select('id')
            .eq('stripe_subscription_id', subscription.id)
            .single();
          
          if (userProfile) {
              console.log(`👤 [USER FOUND] Downgrading User ID: ${userProfile.id}`);
              
              const resetData = {
                  plan_id: 'free',
                  is_vip: false,
                  credits_total: 20, // ✅ Fix: 50 -> 20
                  credits_remaining: 20, // ✅ Fix: 50 -> 20
                  credits_used: 0,
                  credits_expiry: null,
                  stripe_subscription_id: null
              };

              await supabaseAdmin.from('profiles').update(resetData).eq('id', userProfile.id);
              
              await supabaseAdmin.from('user_alerts').insert({
                  user_id: userProfile.id,
                  title: "Plan Expired",
                  message: "Your subscription has ended.",
                  type: "info"
              });
              console.log(`✅ [CANCEL COMPLETE] User reverted to Free tier.`);
          }
      }

      return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" } });
    }

    // ========================================================================
    // 🅱️ CLIENT LOGIC (App Request)
    // ========================================================================
    else {
      console.log("\n🚀 [CLIENT REQUEST] API Call Received");

      const authHeader = req.headers.get('Authorization');
      if (!authHeader) throw new Error("Missing Authorization Header");

      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: authHeader } } }
      );

      const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
      if (userError || !user) throw new Error("User not authenticated");
      
      console.log(`👤 [AUTH] User Authenticated: ${user.id} (${user.email})`);

      const body = await req.json();
      const { action, planId, platform, callback_url, is_mobile, purchaseToken, transactionId, method } = body;

      console.log(`📦 [ACTION] Processing action: "${action}"`);

      // --- ACTION: SYNC PROFILE (SMART VERSION) ---
      if (action === 'sync_profile') {
          console.log("🔄 [SYNC] Starting Profile Sync Logic...");
          const today = new Date().toISOString().split('T')[0];

          // 🆕 STEP 1: Using maybeSingle() to handle missing rows
          let { data: profile, error: fetchError } = await supabaseAdmin
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();
          
          // 🆕 STEP 2: If no profile exists (Anonymous User), create it now
          if (!profile) {
              console.log("🆕 [SYNC] No profile found. Creating new entry with 20 credits...");
              const { data: newProfile, error: insertError } = await supabaseAdmin
                .from('profiles')
                .insert({
                    id: user.id,
                    email: user.email || null,
                    plan_id: 'free',
                    credits_total: 20, // ✅ Fix: 20 Credits
                    credits_remaining: 20, 
                    credits_used: 0,
                    last_reset_date: today,
                    is_vip: false
                })
                .select()
                .single();

              if (insertError) throw insertError;
              console.log("✅ [SYNC] New profile created successfully.");
              return new Response(JSON.stringify({ status: 'created', data: newProfile }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
          }

          let updated = false;
          let updates: any = {};

          console.log(`📊 [SYNC STATE] Plan: ${profile.plan_id} | Expiry: ${profile.credits_expiry} | Last Reset: ${profile.last_reset_date}`);

          // Expiry Check
          if (profile.credits_expiry && profile.credits_expiry < today) {
              console.log("⚠️ [SYNC] Plan has EXPIRED. Downgrading to Free Plan...");
              updates = { 
                  plan_id: 'free', 
                  is_vip: false, 
                  credits_total: 20, // ✅ Fix: 50 -> 20
                  credits_remaining: 20, 
                  credits_used: 0, 
                  credits_expiry: null, 
                  last_reset_date: today 
              };
              updated = true;
          } 
          // Daily Reset (Free Plan)
          else if (profile.last_reset_date !== today) {
              console.log("☀️ [SYNC] New Day Detected. Checking daily reset...");
              updates.last_reset_date = today;
              if (profile.plan_id === 'free') { 
                  console.log("ℹ️ [SYNC] Free plan - Refilling 20 credits.");
                  updates.credits_total = 20; // ✅ Fix: 50 -> 20
                  updates.credits_remaining = 20; 
                  updates.credits_used = 0; 
              }
              updated = true;
          }
          
          if (updated) {
              console.log(`🛠 [SYNC] Applying updates to DB...`);
              await supabaseAdmin.from('profiles').update(updates).eq('id', user.id);
              const { data: newProfile } = await supabaseAdmin.from('profiles').select('*').eq('id', user.id).single();
              return new Response(JSON.stringify({ status: 'updated', data: newProfile }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
          }
          
          return new Response(JSON.stringify({ status: 'no_change', data: profile }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
      }

      // --- ACTION: CREATE STRIPE SESSION ---
      if (action === 'create_stripe_session') {
          console.log(`💳 [STRIPE] Initializing checkout for Plan ID: ${planId}`);
          const { data: plan } = await supabaseAdmin.from('plans').select('*').eq('id', planId).single();
          if (!plan) throw new Error("Plan not found");

          const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') as string, {
             apiVersion: '2024-06-20',
          });

          let successUrl = 'https://studybudy.ai/payment-success';
          let cancelUrl = 'https://studybudy.ai/dashboard';

          if (is_mobile === true || platform === 'android' || platform === 'ios') {
              successUrl = 'studybudy://payment-success';
              cancelUrl = 'studybudy://dashboard';
          } else if (callback_url) {
              successUrl = `${callback_url}/payment-success`;
              cancelUrl = `${callback_url}/dashboard`;
          }

          const sessionMode = plan.interval === 'week' ? 'payment' : 'subscription';
          const session = await stripe.checkout.sessions.create({
              payment_method_types: ['card'],
              line_items: [{ price: plan.stripe_price_id, quantity: 1 }],
              mode: sessionMode, 
              success_url: successUrl,
              cancel_url: cancelUrl,
              customer_email: user.email,
              client_reference_id: user.id,
              metadata: { 
                  user_id: user.id, 
                  plan_id: planId, 
                  interval: plan.interval 
              }
          });

          return new Response(JSON.stringify({ url: session.url }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
      }

      // --- ACTION: CANCEL SUBSCRIPTION ---
      if (action === 'cancel_subscription') {
          console.log("🛑 [CANCEL] Processing cancellation request...");
          const { data: profile } = await supabaseAdmin.from('profiles').select('stripe_customer_id').eq('id', user.id).single();
          
          if (profile?.stripe_customer_id) {
              try {
                  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') as string, { apiVersion: '2024-06-20' });
                  const subs = await stripe.subscriptions.list({ customer: profile.stripe_customer_id, status: 'active' });
                  for (const sub of subs.data) { 
                      await stripe.subscriptions.cancel(sub.id); 
                  }
              } catch (e: any) { console.log(`⚠️ [CANCEL WARN] Stripe Error: ${e.message}`); }
          }
          
          const downgradeData = { 
              plan_id: 'free', 
              is_vip: false, 
              credits_total: 20, // ✅ Fix: 50 -> 20
              credits_remaining: 20, 
              credits_used: 0, 
              credits_expiry: null, 
              payment_provider: null 
          };
          
          await supabaseAdmin.from('profiles').update(downgradeData).eq('id', user.id);
          return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
      }

      // --- ACTION: VERIFY MOBILE RECEIPT ---
      if (action === 'verify_mobile_receipt_native') {
          console.log("📲 [MOBILE] Verifying native purchase...");
          let query = supabaseAdmin.from('plans').select('*');
          if (planId) query = query.eq('id', planId);
          else query = query.eq(platform === 'huawei' ? 'huawei_product_id' : 'google_product_id', body.productId);
          
          const { data: plan } = await query.maybeSingle();
          if (!plan) throw new Error("Plan not found");

          let expiryDate = null;
          const now = new Date();
          if (plan.interval === 'week') { now.setDate(now.getDate() + 7); expiryDate = now.toISOString().split('T')[0]; }
          else if (plan.interval === 'month') { now.setMonth(now.getMonth() + 1); expiryDate = now.toISOString().split('T')[0]; }
          else if (plan.interval === 'year') { now.setFullYear(now.getFullYear() + 1); expiryDate = now.toISOString().split('T')[0]; }

          const mobileUpdate = { 
              plan_id: plan.id, 
              credits_total: plan.credits, 
              credits_remaining: plan.credits, 
              is_vip: false, 
              credits_expiry: expiryDate, 
              payment_provider: platform 
          };

          await supabaseAdmin.from('profiles').update(mobileUpdate).eq('id', user.id);
          return new Response(JSON.stringify({ success: true, plan: plan.name }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
      }

      // --- ACTION: SUBMIT MANUAL PAYMENT ---
      if (action === 'submit_manual_payment') {
          console.log("📝 [MANUAL] Submitting manual payment request...");
          const { data: planData } = await supabaseAdmin.from('plans').select('price').eq('id', planId).single();
          const manualData = { 
              user_id: user.id, 
              plan_id: planId, 
              transaction_id: transactionId, 
              status: 'pending', 
              payment_provider: `manual_${method}`, 
              amount: planData?.price || 0 
          };

          await supabaseAdmin.from('payment_requests').insert(manualData);
          return new Response(JSON.stringify({ status: 'success' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }});
      }

      throw new Error(`Invalid Action: ${action}`);
    }

  } catch (error: any) {
    console.error("🔥 [FATAL ERROR]:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: corsHeaders });
  }
});