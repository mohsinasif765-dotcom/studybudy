import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { OpenAI } from "https://esm.sh/openai@4.28.0"; 

// -----------------------------------------------------------------------------
// 🧮 COST CALCULATOR
// -----------------------------------------------------------------------------
function calculateCost(action: string, options: any, contentLength: number, isImage: boolean): number {
  console.log(`💰 [CALC] Calculating cost for Action: ${action}, Length: ${contentLength}, Image: ${isImage}`);
  let cost = 0;
  
  // 🔥 Action match karein (UPDATED: Added 'questionset')
  if (action === 'generate_quiz' || action === 'generate_question_set' || action === 'questionset') {
    const count = options.count || 10;
    cost = 5 + (count * 2);
  } else if (action === 'summary') {
    cost = 5 + Math.ceil(contentLength / 1000); 
  } else if (action === 'translate') {
    cost = 3 + Math.ceil(contentLength / 500); 
  } else if (action === 'chat') {
    cost = 2; 
  }

  if (isImage) cost += 3;
  
  console.log(`💰 [CALC] Final Cost determined: ${cost}`);
  return cost;
}

// -----------------------------------------------------------------------------
// 🚀 MAIN HANDLER
// -----------------------------------------------------------------------------
serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let historyIdRef = '';
  let filePathRef = '';

  console.log("----------------------------------------------------------------");
  console.log("🚀 [START] New Request Received!");
  console.log(`📡 [HTTP] Method: ${req.method}`);

  try {
    const authHeader = req.headers.get('Authorization')!;
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Auth Check
    console.log("🔒 [AUTH] Verifying user...");
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
        console.error("❌ [AUTH] Authorization Failed!");
        throw new Error("Unauthorized User");
    }
    
    console.log(`👤 [AUTH] Success! User: ${user.email} (${user.id})`);

    // 2. Parse Input
    const reqBody = await req.json();
    const { action, content, options, file_path, history_id } = reqBody;
    
    historyIdRef = history_id;
    filePathRef = file_path;

    console.log(`📥 [INPUT] Action: "${action}"`);
    console.log(`📥 [INPUT] File Path: ${file_path ? file_path : 'N/A'}`);
    console.log(`📥 [INPUT] History ID: ${history_id}`);
    console.log(`📥 [INPUT] Options:`, JSON.stringify(options));

    // =================================================================
    // ⚙️ STEP 0: FETCH AI CONFIG
    // =================================================================
    console.log("⚙️ [CONFIG] Fetching AI Provider settings from DB...");
    let provider = Deno.env.get('ACTIVE_AI_PROVIDER') || 'gemini'; 
    let modelName = ''; 

    const { data: config } = await supabaseAdmin
      .from('app_config')
      .select('key, value')
      .in('key', ['active_ai_provider', 'active_ai_model']);

    if (config && config.length > 0) {
       const dbProvider = config.find(c => c.key === 'active_ai_provider')?.value;
       const dbModel = config.find(c => c.key === 'active_ai_model')?.value;
       if (dbProvider) provider = dbProvider;
       if (dbModel) modelName = dbModel;
    }

    console.log(`🤖 [CONFIG] Active Provider: ${provider}`);
    console.log(`🤖 [CONFIG] Active Model: ${modelName || 'Default (Auto)'}`);

    // =================================================================
    // 📂 STEP 1: IDENTIFY SOURCE & PREPARE
    // =================================================================
    let finalContextText = "";
    let imageFileBuffer: ArrayBuffer | null = null;
    let mimeType = "";
    let isImage = false;

    if (content) {
        console.log("📝 [CONTENT] Using direct text input.");
        finalContextText = content;
    } 
    else if (file_path) {
        console.log(`💾 [STORAGE] Downloading file from bucket: documents/${file_path}`);
        
        const { data: fileData, error: dlError } = await supabaseAdmin.storage.from('documents').download(file_path);
        if (dlError) {
            console.error(`❌ [STORAGE] Download Failed: ${dlError.message}`);
            throw new Error(`Download Failed: ${dlError.message}`);
        }
        console.log("✅ [STORAGE] File downloaded successfully.");
        
        // Check File Type
        const lowerPath = file_path.toLowerCase();
        isImage = lowerPath.endsWith('.png') || lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.webp');

        if (isImage) {
            console.log("🖼️ [TYPE] Image detected. Preparing buffer for Vision API.");
            imageFileBuffer = await fileData.arrayBuffer();
            mimeType = lowerPath.endsWith('.png') ? 'image/png' : 'image/jpeg';
        } else {
            console.log("📄 [TYPE] Document detected. Sending to Hugging Face OCR...");
            const hfBaseUrl = Deno.env.get('HF_API_URL') ?? 'https://almohsin3-studybudy.hf.space';
            const hfUrl = `${hfBaseUrl}/extract_text`; 
            const formData = new FormData();
            formData.append('file', fileData, 'document.pdf');
        
            const hfResponse = await fetch(hfUrl, { method: 'POST', body: formData });
            console.log(`👁️ [OCR] HF Response Status: ${hfResponse.status}`);
            
            if (!hfResponse.ok) {
              const errText = await hfResponse.text();
              console.error(`❌ [OCR] Failed: ${errText}`);
              throw new Error(`Hugging Face Error: ${errText}`);
            }
            const hfResult = await hfResponse.json();
            finalContextText = hfResult.text || "";
            console.log(`✅ [OCR] Text extracted. Length: ${finalContextText.length} chars`);
        }
    } else {
        console.log("❓ [INPUT] Using user_question from options.");
        finalContextText = options?.user_question || '';
    }

    if (!finalContextText && !isImage && action !== 'generate_quiz' && action !== 'generate_question_set' && action !== 'questionset') { 
        console.error("❌ [ERROR] No content found to process.");
        throw new Error("No content available for processing.");
    }

    // =================================================================
    // 💰 STEP 2: COST & CREDIT CHECK
    // =================================================================
    const cost = calculateCost(action, options, finalContextText.length, isImage);
    
    console.log("💳 [PROFILE] Checking user profile and credits...");
    let { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('credits_remaining, credits_used, plan_id') 
      .eq('id', user.id)
      .single();

    if (!profile) throw new Error("Profile not found");
    console.log(`💳 [PROFILE] Plan: ${profile.plan_id} | Balance: ${profile.credits_remaining}`);

    const isVip = ['pro', 'premium', 'vip', 'pro_monthly', 'pro_yearly'].some(p => profile.plan_id.includes(p));
    
    // --- DISABLED CREDIT CHECK (Handled by App) ---
    // if (!isVip) {
    //   const balance = profile.credits_remaining || 0;
    //   if (balance < cost) {
    //     console.error(`❌ [CREDITS] Insufficient! Need ${cost}, Have ${balance}`);
    //     throw new Error(`LOW_CREDITS: Need ${cost}, you have ${balance}.`);
    //   }
    //   console.log("✅ [CREDITS] Balance sufficient.");
    // } else {
    //     console.log("✨ [VIP] User is VIP. Skipping credit check.");
    // }
    console.log("⚠️ [CREDITS] Logic skipped on server (handled by client app).");

    // =================================================================
    // 🤖 STEP 3: AI GENERATION
    // =================================================================
    let result;
    const prompt = generateSystemPrompt(action, options);
    console.log(`📝 [PROMPT] Generated system prompt for action: ${action}`);

    try {
        if (isImage && imageFileBuffer) {
            console.log(`🚀 [VISION] Sending Image Request to Provider: ${provider}`);
            
            if (provider === 'openai') {
                console.log("👉 Calling OpenAI Vision...");
                result = await callOpenAIVision(prompt, imageFileBuffer, mimeType, modelName || 'gpt-4o-mini');
            } 
            else if (provider === 'gemini') {
                console.log("👉 Calling Gemini Vision...");
                result = await callGeminiVision(prompt, imageFileBuffer, mimeType, modelName);
            }
            else {
                console.warn(`⚠️ [VISION] Provider '${provider}' not supported for images. Fallback to Gemini.`);
                result = await callGeminiVision(prompt, imageFileBuffer, mimeType, null);
            }
        } 
        else {
            console.log(`🚀 [LLM] Sending Text Request to Provider: ${provider}`);
            if (provider === 'gemini') {
                result = await callGemini(action, finalContextText, options, modelName);
            }
            else if (provider === 'openai') {
                result = await callOpenAI(action, finalContextText, options, 'https://api.openai.com/v1', modelName);
            }
            else if (provider === 'deepseek') {
                console.log("👉 Calling DeepSeek API...");
                result = await callOpenAI(action, finalContextText, options, 'https://api.deepseek.com/v1', modelName || 'deepseek-chat');
            }
            else {
                throw new Error("Unknown AI Provider");
            }
        }
    } catch (e: any) {
        console.error(`❌ [AI ERROR] ${e.message}`);
        throw new Error(`AI Generation Failed: ${e.message}`);
    }

    if (!result) throw new Error("AI returned empty result.");
    console.log("✅ [AI] Response received successfully.");

    // Safety check log
    if (typeof result === 'string' && result.length > 100 && (result.includes("Intro") || result.includes("Summary"))) {
       if (action !== 'chat' && action !== 'translate') {
           console.warn("⚠️ [AI] WARNING: Response looks like raw text but JSON was expected.");
       }
    }

    // =================================================================
    // ✂️ STEP 4: DEDUCT CREDITS
    // =================================================================
    // --- DISABLED CREDIT DEDUCTION (Handled by App) ---
    // if (!isVip) {
    //    const newRemaining = (profile.credits_remaining || 0) - cost;
    //    const newUsed = (profile.credits_used || 0) + cost;
    //
    //    console.log(`💸 [DB] Deducting ${cost} credits...`);
    //    await supabaseAdmin.from('profiles').update({
    //        credits_remaining: newRemaining,
    //        credits_used: newUsed
    //    }).eq('id', user.id);
    //    
    //    console.log(`✅ [DB] Credits Updated. New Balance: ${newRemaining}`);
    // }
    console.log("⚠️ [DB] Credit deduction skipped (handled by client app).");

    // =================================================================
    // 🛠️ STEP 5: FORMAT DATA & SAVE
    // =================================================================
    console.log("🛠️ [FORMAT] Formatting response data...");
    const isPlainText = (action === 'translate' || action === 'chat');
    
    // Quiz Formatting Logic (UPDATED: Added 'questionset')
    if (action === 'generate_quiz' || action === 'generate_question_set' || action === 'questionset') {
      if (!Array.isArray(result) && typeof result === 'object') {
        const val = Object.values(result).find(v => Array.isArray(v));
        if(val) result = val;
      }
      if (!Array.isArray(result)) {
          console.error("❌ [FORMAT] Invalid Quiz Format received from AI.");
          // Don't throw error immediately, try to log raw result for debug
          console.error("RAW AI RESULT:", JSON.stringify(result).substring(0, 200));
          throw new Error("AI generated invalid quiz format.");
      }
    }

    // Summary Formatting Logic
    if (action === 'summary' && typeof result === 'object') {
       const intro = result.introduction || "Summary:";
       const conclusion = result.conclusion || "";
       let cleanPoints: string[] = [];
       if (Array.isArray(result.key_points)) cleanPoints = result.key_points;
       else if (typeof result.key_points === 'string') cleanPoints = result.key_points.split(/\n|•|-/).map((s:string)=>s.trim()).filter((s:string)=>s.length>0);
       
       result.key_points = cleanPoints;
       const pointsMarkdown = cleanPoints.map((p: string) => `- ${p}`).join('\n'); 
       result.summary_markdown = `## 📌 Introduction\n${intro}\n\n## 🔑 Key Points\n${pointsMarkdown}\n\n## 💡 Conclusion\n${conclusion}`;
    }

    const finalBody = Array.isArray(result) 
        ? { data: result, _meta: { cost } } 
        : { ...(isPlainText ? { text: result } : result), _meta: { cost } };

    // Update DB
    if (historyIdRef) {
        console.log(`💾 [DB] Updating 'study_history' table (ID: ${historyIdRef})...`);
        const { error: updateError } = await supabaseAdmin
            .from('study_history')
            .update({ content: finalBody, status: 'completed' })
            .eq('id', historyIdRef);

        if (updateError) console.error("❌ [DB] Update Failed:", updateError);
        else console.log("✅ [DB] Database updated successfully.");
    }

    // =================================================================
    // 🧹 STEP 6: CLEANUP
    // =================================================================
    if (filePathRef) {
        console.log(`🧹 [CLEANUP] Removing file from bucket: ${filePathRef}`);
        const { error: rmError } = await supabaseAdmin.storage.from('documents').remove([filePathRef]);
        if(rmError) console.error("❌ [CLEANUP] Remove failed:", rmError);
        else console.log("✅ [CLEANUP] Bucket cleaned successfully.");
    }

    console.log("🏁 [DONE] Sending Final Response to Client.");
    return new Response(JSON.stringify(finalBody), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error("🚨 [CRITICAL ERROR]:", error.message);

    if (historyIdRef) {
        console.log("🛑 [DB] Marking History as FAILED.");
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );
        await supabaseAdmin.from('study_history')
           .update({ status: 'failed', content: { error: error.message } })
           .eq('id', historyIdRef);
    }

    if (filePathRef) {
        console.log("🧹 [CLEANUP] Force removing file due to error...");
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );
        await supabaseAdmin.storage.from('documents').remove([filePathRef]);
    }

    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: corsHeaders });
  }
});

// =================================================================
// 🛠️ HELPER FUNCTIONS (API DRIVERS)
// =================================================================

// 1. GEMINI TEXT
async function callGemini(action: string, content: string, options: any, modelOverride?: string) {
  const apiKey = Deno.env.get('GEMINI_API_KEY');
  const model = modelOverride || 'gemini-1.5-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  
  console.log(`🔗 [GEMINI] POST Request -> ${model}`);

  const prompt = generateSystemPrompt(action, options);
  const isPlainText = (action === 'translate' || action === 'chat');

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ 
          parts: [
              { text: prompt }, 
              { text: `\n\nCONTEXT:\n${content.substring(0, 30000)}` }
          ] 
      }],
      generationConfig: { 
          responseMimeType: isPlainText ? "text/plain" : "application/json" 
      }
    })
  });

  const data = await response.json();
  
  if (data.error) {
      console.error("❌ [GEMINI] API Error:", JSON.stringify(data.error));
      throw new Error(`Gemini Error: ${data.error.message}`);
  }
  
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error("Gemini returned empty response");

  console.log("✅ [GEMINI] Got response.");
  if (isPlainText) return rawText;
  
  try {
    const cleanText = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    return JSON.parse(cleanText);
  } catch (e) { 
      console.error("❌ [GEMINI] JSON Parse Error");
      throw new Error("AI returned invalid JSON"); 
  }
}

// 2. GEMINI VISION
async function callGeminiVision(prompt: string, arrayBuffer: ArrayBuffer, mimeType: string, modelOverride?: string) {
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    const model = modelOverride || 'gemini-1.5-flash';
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    
    console.log(`🔗 [GEMINI VISION] POST Request -> ${model} (Mime: ${mimeType})`);

    const base64Data = encode(new Uint8Array(arrayBuffer));

    const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{
                parts: [
                    { text: prompt + "\nRETURN STRICT JSON ONLY." },
                    { inline_data: { mime_type: mimeType, data: base64Data } }
                ]
            }],
            generationConfig: { responseMimeType: "application/json" }
        })
    });

    const data = await response.json();
    if (data.error) {
        console.error("❌ [GEMINI VISION] Error:", data.error.message);
        throw new Error(`Gemini Vision Error: ${data.error.message}`);
    }
    
    console.log("✅ [GEMINI VISION] Got response.");
    try {
        const rawText = data.candidates[0].content.parts[0].text;
        const cleanText = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
        return JSON.parse(cleanText);
    } catch(e) {
        console.error("❌ [GEMINI VISION] JSON Parse Error");
        throw new Error("Failed to parse Gemini Vision JSON.");
    }
}

// 3. OPENAI VISION
async function callOpenAIVision(prompt: string, arrayBuffer: ArrayBuffer, mimeType: string, modelOverride: string) {
    const apiKey = Deno.env.get('OPENAI_API_KEY');
    const model = modelOverride.includes('gpt') ? modelOverride : 'gpt-4o-mini'; 
    
    console.log(`🔗 [OPENAI VISION] POST Request -> ${model}`);
    const base64Data = encode(new Uint8Array(arrayBuffer));
    const dataUrl = `data:${mimeType};base64,${base64Data}`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}` 
        },
        body: JSON.stringify({
            model: model,
            messages: [
                { 
                    role: "user", 
                    content: [
                        { type: "text", text: prompt + "\nRETURN JSON ONLY." },
                        { type: "image_url", image_url: { url: dataUrl } }
                    ]
                }
            ],
            response_format: { type: "json_object" }
        })
    });

    const data = await response.json();
    if (data.error) {
        console.error("❌ [OPENAI VISION] Error:", data.error.message);
        throw new Error(`OpenAI Vision Error: ${data.error.message}`);
    }

    console.log("✅ [OPENAI VISION] Got response.");
    try {
        return JSON.parse(data.choices[0].message.content);
    } catch(e) {
        throw new Error("Failed to parse OpenAI Vision JSON response.");
    }
}

// 4. OPENAI / DEEPSEEK
async function callOpenAI(action: string, content: string, options: any, baseUrl: string, modelOverride?: string) {
  const isDeepSeek = baseUrl.includes('deepseek');
  const apiKey = isDeepSeek ? Deno.env.get('DEEPSEEK_API_KEY') : Deno.env.get('OPENAI_API_KEY');
  let model = modelOverride || (isDeepSeek ? 'deepseek-chat' : 'gpt-4o-mini');
  
  console.log(`🔗 [${isDeepSeek ? 'DEEPSEEK' : 'OPENAI'}] POST Request -> ${model}`);

  const prompt = generateSystemPrompt(action, options);
  const isPlainText = (action === 'translate' || action === 'chat');

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: model,
      messages: [
        { role: "system", content: prompt + (!isPlainText ? "\nRETURN JSON ONLY." : "") },
        { role: "user", content: content }
      ],
      response_format: (isPlainText || isDeepSeek) ? undefined : { type: "json_object" } 
    })
  });

  const data = await response.json();
  if (data.error) {
      console.error(`❌ [API ERROR]`, data.error.message);
      throw new Error(`AI API Error: ${data.error.message}`);
  }
  
  console.log(`✅ [${isDeepSeek ? 'DEEPSEEK' : 'OPENAI'}] Got response.`);
  const rawText = data.choices[0].message.content;
  if (isPlainText) return rawText;

  try {
    return JSON.parse(rawText.replace(/```json/g, '').replace(/```/g, '').trim());
  } catch (e) { throw new Error("JSON Parse Error from AI"); }
}

// =================================================================
// 🧠 SYSTEM PROMPTS (UPDATED to match Action: 'questionset')
// =================================================================
function generateSystemPrompt(action: string, options: any) {
  
  // 1️⃣ SIMPLE QUIZ
  if (action === 'generate_quiz') {
    return `You are a strict JSON generator. 
    Task: Create a ${options.difficulty} quiz on "${options.topic}". 
    Target: ${options.count} questions.
    
    🚨 RULES:
    1. Output MUST be a JSON Object: { "data": [ ... ] }
    2. No markdown, just raw JSON.
    3. Questions should be fun but educational.
    
    REQUIRED ITEM FORMAT:
    {
      "question": "Question text?",
      "options": ["A", "B", "C", "D"],
      "correctAnswerIndex": 0, 
      "explanation": "Short reason why."
    }`;
  }

  // 2️⃣ 📝 QUESTION SET (🔥 COMPLETELY CHANGED TO THEORY)
  if (action === 'generate_question_set' || action === 'questionset') {
    return `You are a Senior Academic Examiner known for creating high-quality examination papers.
    
    🚨 TASK: Analyze the content and generate ${options.count} Subjective/Theory Questions with Detailed Model Answers.
    
    ⛔ NEGATIVE CONSTRAINTS (STRICTLY FORBIDDEN):
    - NO Multiple Choice Questions (MCQs).
    - NO Options (A, B, C, D).
    - NO simple/one-word answers.
    
    🎯 DIFFICULTY RULES (${options.difficulty}):
    - If "Easy": Focus on Definitions, Recall, and basic 'What is' questions.
    - If "Medium": Focus on Explanations, Processes, and 'How/Why' questions.
    - If "Hard": Focus on Analysis, Comparison, Critical Thinking, and Application.
    
    📋 REQUIRED JSON OUTPUT FORMAT (Strictly follow this structure):
    {
      "data": [
        {
          "question": "The question text tailored to ${options.difficulty} level?",
          "answer": "A comprehensive, academic model answer. It should be detailed enough for a student to learn from.",
          "marks": 5,
          "type": "Theory" 
        },
        ... (repeat for ${options.count} items)
      ]
    }`;
  }
  
  if (action === 'summary') {
    return `You are an academic AI assistant.
    
    📝 **REQUIRED JSON OUTPUT FORMAT:**
    You must return a raw JSON object with these exact keys:
    {
      "title": "A professional and descriptive title",
      "emoji": "📄",
      "reading_time": "e.g., '5 min read'",
      "introduction": "A comprehensive overview (3-5 sentences) setting the context.",
      "key_points": [
        "Detailed bullet point 1",
        "Detailed bullet point 2"
      ],
      "conclusion": "A solid wrap-up summarizing the core message.",
      "summary_markdown": "Generate a beautiful, study-ready Markdown version here with headings and bullet points."
    }

    🚫 **NEGATIVE CONSTRAINTS:**
    - NEVER return a list of strings only.
    - Go straight to the facts.
    
    Process the provided content now.`;
  }
  
  if (action === 'translate') return `Translate to "${options.target_language}". Return translated text only.`;
  if (action === 'chat') return `Answer concisely. Return text only.`;
  
  return "Analyze";
}