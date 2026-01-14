import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert'; // For jsonEncode
import '../models/quiz_model.dart';

class QuizService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<QuizQuestion>> generateQuiz(QuizConfig config) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. 📝 CREATE DB ENTRY (Processing)
    // Is se foran "Recent Activity" mein entry aa jayegi
    final insertRes = await _supabase.from('study_history').insert({
      'user_id': user.id,
      'type': 'quiz',
      'title': "Generating Quiz...", // Temporary title
      'original_file_name': "Local File", // Ya config se filename pass karein agar available ho
      'status': 'processing',
      'content': {}, 
    }).select().single();

    final historyId = insertRes['id'];

    try {
      // 2. 🧠 CALL AI
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'generate_quiz',
          'content': config.fileContent,
          'options': {
            'difficulty': config.difficulty,
            'topic': config.topic,
            'count': config.count,
          }
        },
      );

      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        if (errorMsg.toString().contains('Insufficient credits')) {
          // Fail status update karo
          await _supabase.from('study_history').update({
            'status': 'failed',
            'content': {'error': 'Insufficient credits'}
          }).eq('id', historyId);
          throw 'LOW_CREDITS'; 
        }
      }

      if (response.status != 200) throw Exception("AI Brain Failed");

      final dynamic responseData = response.data;
      List<dynamic> listData = [];

      // 3. PARSE RESPONSE
      if (responseData is Map && responseData.containsKey('data')) {
        listData = responseData['data'];
      } else if (responseData is List) {
        listData = responseData;
      }

      // 4. ✅ UPDATE DB (Completed)
      // Ab result save ho gaya, History mein show hoga
      await _supabase.from('study_history').update({
        'status': 'completed',
        'title': "Quiz: ${config.topic}", // Title update
        'content': {'data': listData} // Save Quiz Data
      }).eq('id', historyId);

      return listData.map((e) => QuizQuestion.fromJson(e)).toList();
      
    } catch (e) {
      // ❌ Agar fail ho jaye to DB update karo
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