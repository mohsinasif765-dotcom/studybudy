import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ... (Cost Calculator same rahega) ...
function calculateCost(action: string, options: any, content: string): number {
  let cost = 0;
  if (action === 'generate_quiz') {
    const count = options.count || 10;
    const baseFee = 5;
    cost = baseFee + (count * 2);
  } else if (action === 'summary') {
    const length = content.length || 0;
    const baseFee = 5;
    const lengthCost = Math.ceil(length / 1000); 
    cost = baseFee + lengthCost;
  } else if (action === 'translate') {
    const length = content.length || 0;
    const baseFee = 3;
    const lengthCost = Math.ceil(length / 500); 
    cost = baseFee + lengthCost;
  } else if (action === 'chat') {
    cost = 2; 
  }
  return cost;
}

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization')!;
    
    // Clients
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Verify User
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error("Unauthorized User");

    const { action, content, options } = await req.json();

    // 💰 COST CHECK (Same as before)
    const cost = calculateCost(action, options, content || options.user_question || '');
    const { data: profile } = await supabaseAdmin.from('profiles').select('credits_total, credits_used').eq('id', user.id).single();

    if (!profile || profile.credits_total < cost) {
      throw new Error(`Insufficient credits. Need ${cost}, Have ${profile?.credits_total || 0}.`);
    }

    // 🤖 DYNAMIC AI SELECTION (Yahan Magic Hoga) 🎩
    // 1. Pehle Admin ki setting check karo (Database)
    let provider = Deno.env.get('ACTIVE_AI_PROVIDER') || 'gemini'; // Default fallback
    let modelName = '';

    const { data: config } = await supabaseAdmin
      .from('app_config')
      .select('key, value')
      .in('key', ['active_ai_provider', 'active_ai_model']);

    if (config) {
      const dbProvider = config.find(c => c.key === 'active_ai_provider')?.value;
      const dbModel = config.find(c => c.key === 'active_ai_model')?.value;
      
      if (dbProvider) provider = dbProvider; // Admin Override!
      if (dbModel) modelName = dbModel;
    }

    console.log(`🧠 Using Brain: ${provider} (${modelName || 'Default'})`);

    // AI EXECUTION
    let result;
    if (provider === 'gemini') {
      result = await callGemini(action, content, options, modelName);
    } else if (provider === 'openai') {
      result = await callOpenAI(action, content, options, 'https://api.openai.com/v1', modelName);
    } else if (provider === 'deepseek') {
      result = await callOpenAI(
        action, 
        content, 
        options, 
        'https://api.deepseek.com/v1', 
        modelName || Deno.env.get('DEEPSEEK_MODEL') || 'deepseek-chat'
      );
    } else {
      throw new Error("Unknown AI Provider Configured");
    }

    // 📉 DEDUCT CREDITS
    await supabaseAdmin.from('profiles').update({
      credits_total: profile.credits_total - cost,
      credits_used: (profile.credits_used || 0) + cost
    }).eq('id', user.id);

    // RESPONSE
    const isPlainText = (action === 'translate' || action === 'chat');
    const finalBody = {
      ...(isPlainText ? { text: result } : result),
      _meta: { cost_deducted: cost, remaining: profile.credits_total - cost, powered_by: provider }
    };

    return new Response(JSON.stringify(finalBody), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

// 🤖 GEMINI (Updated to accept dynamic model)
async function callGemini(action: string, content: string, options: any, modelOverride?: string) {
  const apiKey = Deno.env.get('GEMINI_API_KEY');
  const model = modelOverride || Deno.env.get('GEMINI_MODEL') || 'gemini-1.5-flash'; // Priority: Admin DB > Env > Default
  
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const prompt = generateSystemPrompt(action, options);
  const isPlainText = (action === 'translate' || action === 'chat');

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [{ text: prompt }, { text: `Context:\n${content || options.document_context || options.user_question || ''}` }]
      }],
      generationConfig: { responseMimeType: isPlainText ? "text/plain" : "application/json" }
    })
  });

  const data = await response.json();
  if (!data.candidates) throw new Error(`Gemini Error (${model}): ${JSON.stringify(data)}`);
  
  const rawText = data.candidates[0].content.parts[0].text;
  return isPlainText ? rawText : JSON.parse(rawText);
}

// 🤖 OPENAI / DEEPSEEK (Updated to accept dynamic model)
async function callOpenAI(action: string, content: string, options: any, baseUrl: string, modelOverride?: string) {
  const isDeepSeek = baseUrl.includes('deepseek');
  const apiKey = isDeepSeek ? Deno.env.get('DEEPSEEK_API_KEY') : Deno.env.get('OPENAI_API_KEY');
  
  // Priority: Admin DB > Function Arg > Env > Default
  let model = modelOverride;
  if (!model) {
     model = isDeepSeek 
        ? (Deno.env.get('DEEPSEEK_MODEL') || 'deepseek-chat') 
        : (Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini');
  }

  const prompt = generateSystemPrompt(action, options);
  const isPlainText = (action === 'translate' || action === 'chat');

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: model,
      messages: [
        { role: "system", content: prompt + (!isPlainText ? "\nRETURN JSON ONLY." : "") },
        { role: "user", content: content || options.user_question || '' }
      ],
      response_format: (isPlainText || isDeepSeek) ? undefined : { type: "json_object" } 
      // Note: DeepSeek doesn't always support response_format: json_object in all models
    })
  });

  const data = await response.json();
  if (!data.choices) throw new Error(`${isDeepSeek ? 'DeepSeek' : 'OpenAI'} Error: ${JSON.stringify(data)}`);

  const rawText = data.choices[0].message.content;
  // Cleanup JSON formatting if model returns markdown ticks
  const cleanText = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
  
  return isPlainText ? rawText : JSON.parse(cleanText);
}

// ... (GenerateSystemPrompt function same as before) ...
function generateSystemPrompt(action: string, options: any) {
  if (action === 'generate_quiz') {
    return `You are a strict teacher. Create a ${options.difficulty} level quiz about "${options.topic}".
    Target Quantity: ${options.count}.
    STRICT JSON SCHEMA: [{"question": "...", "options": ["..."], "correctAnswerIndex": 0, "explanation": "..."}]`;
  }
  if (action === 'summary') {
    return `Summarize document. STRICT JSON SCHEMA: {"title": "...", "emoji": "...", "reading_time": "...", "key_points": ["..."], "summary_markdown": "..."}`;
  }
  if (action === 'translate') {
    return `Translate to "${options.target_language}". Keep Markdown formatting. Return ONLY translated text.`;
  }
  if (action === 'chat') {
    return `Answer based on context: ${options.document_context}. Be concise. Return text only.`;
  }
  return "Analyze.";
}