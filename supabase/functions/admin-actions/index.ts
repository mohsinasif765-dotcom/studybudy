import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  console.log("🚀 [ADMIN] Function Triggered");

  try {
    const authHeader = req.headers.get('Authorization')!;
    
    // Init Clients
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 3. Verify Admin 🛡️
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error("Unauthorized: User not found");

    const { data: adminProfile } = await supabaseAdmin
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    // 👑 MASTER ADMIN CHECK
    const isMasterAdmin = user.email === 'mohsinasif765@gmail.com';
    if (!isMasterAdmin && (!adminProfile || !adminProfile.is_admin)) {
      console.error(`⛔ [ADMIN] Forbidden Access by: ${user.email}`);
      throw new Error("Forbidden: You are not an Admin!");
    }

    console.log(`👤 [ADMIN] Authenticated: ${user.email}`);

    // 4. Parse Payload
    const { action, ...payload } = await req.json();
    console.log(`📦 [ACTION] Type: ${action}`);

    let result;

    // ==================================================
    // ✏️ ACTION 1: UPDATE USER PLAN (Manual)
    // ==================================================
    if (action === 'update_user_plan') {
      const { target_user_id, plan_id, is_vip, expiry_date, merge_credits } = payload;
      
      if (!target_user_id) throw new Error("Target User ID is required");

      let creditsToApply = 0;
      let finalPlanId = plan_id;
      let finalIsVip = is_vip;

      // Determine Base Credits
      if (plan_id === 'vip' || is_vip === true) {
          finalPlanId = 'vip'; 
          finalIsVip = true;
          creditsToApply = 999999;
      } 
      else {
          const { data: planData } = await supabaseAdmin.from('plans').select('credits').eq('id', plan_id).single();
          if (!planData) {
              if (plan_id === 'free') creditsToApply = 50;
              else throw new Error(`Plan '${plan_id}' not found.`);
          } else {
              creditsToApply = planData.credits;
          }
      }

      // Calculate Final Total
      let finalTotal = creditsToApply;
      if (merge_credits === true) {
          const { data: currentProfile } = await supabaseAdmin
            .from('profiles')
            .select('credits_total')
            .eq('id', target_user_id)
            .single();
          
          const existing = currentProfile?.credits_total || 0;
          finalTotal = existing + creditsToApply;
      }

      // Expiry Logic
      let finalExpiry = expiry_date || null;
      if (!finalExpiry && finalPlanId === 'mini') {
          const date = new Date();
          date.setDate(date.getDate() + 7);
          finalExpiry = date.toISOString().split('T')[0];
      }
      if (finalExpiry) finalExpiry = new Date(finalExpiry).toISOString().split('T')[0];

      // Update DB (Including credits_remaining)
      await supabaseAdmin.from('profiles').update({
          plan_id: finalPlanId,
          is_vip: finalIsVip,
          credits_total: finalTotal, 
          credits_remaining: finalTotal, // 👈 FULL RESET (Like Payment Manager)
          credits_used: 0, 
          credits_expiry: finalExpiry,
          payment_provider: 'manual_admin'
        }).eq('id', target_user_id);

      // Alert
      await supabaseAdmin.from('user_alerts').insert({
        user_id: target_user_id,
        title: finalIsVip ? "VIP Unlocked! 🌟" : "Plan Updated 🛠️",
        message: `Your plan is now ${finalPlanId.toUpperCase()}. Total Credits: ${finalTotal}.`,
        type: finalIsVip ? 'vip' : 'plan'
      });

      result = { message: `User Updated: Plan=${finalPlanId}, Total=${finalTotal}` };
    }

    // ==================================================
    // 🎁 ACTION 2: GIFT CREDITS
    // ==================================================
    else if (action === 'gift_credits') {
      const { target_user_id, amount, expiry_date } = payload; 
      
      const { data: profile } = await supabaseAdmin.from('profiles').select('credits_total, credits_remaining').eq('id', target_user_id).single();
      if (!profile) throw new Error("Target user not found");

      const newTotal = (profile.credits_total || 0) + amount;
      const newRemaining = (profile.credits_remaining || 0) + amount; // 👈 Add to remaining too

      const updateData: any = { 
          credits_total: newTotal,
          credits_remaining: newRemaining
      };
      if (expiry_date) updateData.credits_expiry = expiry_date; 

      await supabaseAdmin.from('profiles').update(updateData).eq('id', target_user_id);

      await supabaseAdmin.from('user_alerts').insert({
        user_id: target_user_id,
        title: "Gift Received! 🎁",
        message: `You've received ${amount} free credits!`,
        type: 'credits'
      });

      result = { message: `Added ${amount} credits.` };
    }

    // ==================================================
    // 💳 ACTION 3: PROCESS PAYMENT (Manual Approval)
    // ==================================================
    else if (action === 'process_payment') {
      const { request_id, status } = payload; 
      const { data: request } = await supabaseAdmin.from('payment_requests').select('*').eq('id', request_id).single();
      if (!request) throw new Error("Request not found");

      if (status === 'approved') {
        const planId = request.plan_id;
        let creditsToAdd = 0;
        let finalPlanId = planId;
        let isVip = false;

        if (planId === 'vip') {
            creditsToAdd = 999999;
            isVip = true;
            finalPlanId = 'vip';
        } else {
            const { data: planData } = await supabaseAdmin.from('plans').select('credits').eq('id', planId).single();
            creditsToAdd = planData ? planData.credits : 0;
            isVip = planId === 'pro' || planId.includes('pro');
        }

        const { data: userProfile } = await supabaseAdmin.from('profiles').select('credits_total').eq('id', request.user_id).single();
        const newTotal = (userProfile?.credits_total || 0) + creditsToAdd;

        let expiryDate = null;
        if (planId === 'mini') {
            const date = new Date();
            date.setDate(date.getDate() + 7);
            expiryDate = date.toISOString().split('T')[0];
        }

        await supabaseAdmin.from('profiles').update({
            plan_id: finalPlanId,
            credits_total: newTotal,
            credits_remaining: newTotal, // 👈 FULL RESET
            credits_used: 0,
            is_vip: isVip,
            credits_expiry: expiryDate,
            payment_provider: 'manual_approval'
          }).eq('id', request.user_id);

        await supabaseAdmin.from('user_alerts').insert({
          user_id: request.user_id,
          title: "Payment Approved! ✅",
          message: `Activated ${finalPlanId.toUpperCase()}. Credits added.`,
          type: isVip ? 'vip' : 'plan'
        });
      }

      await supabaseAdmin.from('payment_requests').update({ status: status }).eq('id', request_id);
      result = { message: `Payment Request ${status}!` };
    } 

    // ==================================================
    // ⚙️ ACTION 4: UPDATE PLANS
    // ==================================================
    else if (action === 'update_plans') {
      console.log(`⚙️ Updating ${payload.plans.length} plans...`);
      for (const plan of payload.plans) {
        await supabaseAdmin.from('plans').update({
            name: plan.name,
            price_pkr: plan.price_pkr,
            price_usd: plan.price_usd,
            credits: plan.credits,
            is_popular: plan.is_popular,
            yearly_discount_percent: plan.yearly_discount_percent,
            stripe_price_id: plan.stripe_price_id,
          }).eq('id', plan.id);
      }
      result = { message: "Plans updated successfully" };
    }

    // ==================================================
    // 🤖 ACTION 5: UPDATE CONFIG
    // ==================================================
    else if (action === 'update_app_config') {
      await supabaseAdmin.from('app_config').upsert({ key: 'active_ai_provider', value: payload.provider }, { onConflict: 'key' });
      await supabaseAdmin.from('app_config').upsert({ key: 'active_ai_model', value: payload.model }, { onConflict: 'key' });
      result = { message: "AI Configuration updated" };
    }

    // ==================================================
    // 👥 ACTION 6: GET ALL USERS
    // ==================================================
    else if (action === 'get_all_users') {
      const { data: users } = await supabaseAdmin
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });
      result = { users };
    }

    // ==================================================
    // 🗑️ ACTION 7: DELETE ANNOUNCEMENT
    // ==================================================
    else if (action === 'delete_announcement') {
      const { id } = payload;
      if (!id) throw new Error("Announcement ID required");

      const { error } = await supabaseAdmin.from('announcements').delete().eq('id', id);
      if (error) throw error;
      result = { message: "Announcement deleted successfully" };
    }

    // ==================================================
    // ✏️ ACTION 8: EDIT ANNOUNCEMENT
    // ==================================================
    else if (action === 'edit_announcement') {
      const { id, new_message } = payload;
      if (!id || !new_message) throw new Error("ID and Message required");

      const { error } = await supabaseAdmin.from('announcements').update({ message: new_message }).eq('id', id);
      if (error) throw error;
      result = { message: "Announcement updated successfully" };
    }

    // ==================================================
    // 📢 ACTION 9: SEND ANNOUNCEMENT
    // ==================================================
    else if (action === 'send_announcement') {
       const { message, target_user_id, is_active } = payload;
       
       if (is_active) {
         if (target_user_id) await supabaseAdmin.from('announcements').update({ is_active: false }).eq('target_user_id', target_user_id);
         else await supabaseAdmin.from('announcements').update({ is_active: false }).is('target_user_id', null);
       }

       const { data } = await supabaseAdmin.from('announcements').insert({
         message, target_user_id: target_user_id || null, is_active: is_active ?? true
       }).select().single();
       
       result = { message: "Announcement Sent!", data };
    }
    
    else {
      console.error(`❌ [ERROR] Unknown Action: ${action}`);
      throw new Error(`Unknown action: ${action}`);
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("🔥 [FATAL ERROR]:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});