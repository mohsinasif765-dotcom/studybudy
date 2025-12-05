import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 💎 PLAN CONFIGURATION (Credits Logic)
// Agar plan change ho to credits yahan se uthaye jayenge
const PLAN_CREDITS: Record<string, number> = {
  'mini': 300,
  'basic': 2000,
  'pro': 10000,
};

serve(async (req) => {
  // 1. CORS Headers (Flutter app se baat karne k liye zaroori)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Preflight check
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 2. Initialize Clients
    // A. User Client (Jo request bhej raha hai - Admin check karne k liye)
    const authHeader = req.headers.get('Authorization')!;
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    // B. Admin Client (Database edit karne k liye - Service Role)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 3. Verify Admin (Security Check) 🛡️
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    
    if (userError || !user) {
      throw new Error("Unauthorized: User not found");
    }

    // Check Profile for is_admin flag
    const { data: adminProfile } = await supabaseAdmin
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    // Master Email Backdoor (Optional)
    const isMasterAdmin = user.email === 'mohsinasif765@gmail.com';

    if (!isMasterAdmin && (!adminProfile || !adminProfile.is_admin)) {
      throw new Error("Forbidden: You are not an Admin!");
    }

    // 4. Parse Request
    const { action, ...payload } = await req.json();
    console.log(`🚀 Admin Action: ${action}`);

    let result;

    // ==================================================
    // ⚡ ACTION 1: GET ALL USERS
    // ==================================================
    if (action === 'get_all_users') {
      // Profiles table se data lo (Users ka data profiles mein sync hona chahiye)
      const { data: users, error } = await supabaseAdmin
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      result = { users };
    }

    // ==================================================
    // ⚡ ACTION 2: GIFT CREDITS
    // ==================================================
    else if (action === 'gift_credits') {
      const { target_user_id, amount } = payload;

      // 1. Get current credits
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('credits_total')
        .eq('id', target_user_id)
        .single();

      if (!profile) throw new Error("Target user not found");

      // 2. Update credits
      const newTotal = (profile.credits_total || 0) + amount;
      
      const { error: updateError } = await supabaseAdmin
        .from('profiles')
        .update({ credits_total: newTotal })
        .eq('id', target_user_id);

      if (updateError) throw updateError;
      result = { message: `Successfully added ${amount} credits. New Total: ${newTotal}` };
    }

    // ==================================================
    // ⚡ ACTION 3: PROCESS PAYMENT (Approve/Reject)
    // ==================================================
    else if (action === 'process_payment') {
      const { request_id, status } = payload; // status: 'approved' | 'rejected'

      // 1. Get Request Details
      const { data: request } = await supabaseAdmin
        .from('payment_requests')
        .select('*')
        .eq('id', request_id)
        .single();

      if (!request) throw new Error("Payment request not found");

      // 2. If Approved -> Update User Profile
      if (status === 'approved') {
        const planId = request.plan_id;
        const creditsToAdd = PLAN_CREDITS[planId] || 0;

        // Get current user credits
        const { data: userProfile } = await supabaseAdmin
          .from('profiles')
          .select('credits_total')
          .eq('id', request.user_id)
          .single();

        const currentCredits = userProfile?.credits_total || 0;

        // Update Profile (Plan + Credits)
        const { error: profileError } = await supabaseAdmin
          .from('profiles')
          .update({
            plan_id: planId,
            credits_total: currentCredits + creditsToAdd,
            // Agar pro plan hai to VIP bhi bana do (Optional logic)
            is_vip: planId === 'pro'
          })
          .eq('id', request.user_id);

        if (profileError) throw profileError;
      }

      // 3. Update Request Status
      const { error: reqError } = await supabaseAdmin
        .from('payment_requests')
        .update({ status: status })
        .eq('id', request_id);

      if (reqError) throw reqError;

      result = { message: `Payment ${status} successfully` };
    } 
    
    else {
      throw new Error(`Unknown action: ${action}`);
    }

    // ✅ Return Success Response
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    // ❌ Return Error Response
    console.error("Admin Action Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});