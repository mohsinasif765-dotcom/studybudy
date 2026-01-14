import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert'; // For jsonEncode
import '../../quiz/models/quiz_model.dart'; 

class QuestionSetService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<QuizQuestion>> generateQuestionSet(QuizConfig config) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // =========================================================================
    // 1️⃣ CREATE DB ENTRY (Processing State)
    // =========================================================================
    final insertRes = await _supabase.from('study_history').insert({
      'user_id': user.id,
      'type': 'questionset', // 👈 Unique Identifier
      'title': "Drafting Theory Questions...", // 👈 Better Initial Title
      'original_file_name': "Local File", 
      'status': 'processing',
      'content': {}, 
    }).select().single();

    final historyId = insertRes['id'];

    try {
      // =======================================================================
      // 2️⃣ CALL AI BRAIN
      // =======================================================================
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'generate_question_set', // 👈 Triggers "Senior Examiner" Mode
          'history_id': historyId, // 👈 ADDED: Server needs this for safety logs
          'content': config.fileContent,
          'options': {
            'difficulty': config.difficulty,
            'topic': config.topic,
            'count': config.count,
          }
        },
      );

      // =======================================================================
      // 3️⃣ ERROR HANDLING
      // =======================================================================
      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        if (errorMsg.toString().contains('LOW_CREDITS')) {
          // Client side fail update (Optional, as server usually does it)
          await _supabase.from('study_history').update({
            'status': 'failed',
            'content': {'error': 'Insufficient credits'}
          }).eq('id', historyId);
          throw 'LOW_CREDITS'; 
        }
        throw Exception(errorMsg);
      }

      if (response.status != 200) throw Exception("AI Brain Failed");

      final dynamic responseData = response.data;
      List<dynamic> listData = [];

      // =======================================================================
      // 4️⃣ PARSE RESPONSE
      // =======================================================================
      if (responseData is Map && responseData.containsKey('data')) {
        listData = responseData['data'];
      } else if (responseData is List) {
        listData = responseData;
      }

      // =======================================================================
      // 5️⃣ UPDATE DB (Completed State)
      // =======================================================================
      await _supabase.from('study_history').update({
        'status': 'completed',
        // 🏷️ Title ab "Quiz" nahi "Theory Q/A" show hoga
        'title': config.topic.isNotEmpty 
            ? "Theory Q/A: ${config.topic}" 
            : "Theory Set (${config.count} Qs)",
        'content': {'data': listData} 
      }).eq('id', historyId);

      // =======================================================================
      // 6️⃣ STRICT MAPPING (Crucial Fix)
      // =======================================================================
      // 🔥 Yahan 'fromTheoryJson' use kar rahe hain taake
      // MCQs (options) dhoondne ki ghalti na ho aur crash na ho.
      return listData.map((e) => QuizQuestion.fromTheoryJson(e)).toList();
      
    } catch (e) {
      // ❌ Fallback Error Handler
      if (e != 'LOW_CREDITS') {
        await _supabase.from('study_history').update({
          'status': 'failed',
          'content': {'error': e.toString()}
        }).eq('id', historyId);
      }
      rethrow;
    }
  }
}