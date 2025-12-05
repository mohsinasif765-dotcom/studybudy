import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_model.dart';

class QuizService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<QuizQuestion>> generateQuiz(QuizConfig config) async {
    try {
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

      // 🛑 1. LOW BALANCE CHECK ADDED
      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        
        // Backend se agar ye message aaye, to special error throw karo
        if (errorMsg.toString().contains('Insufficient credits')) {
          throw 'LOW_CREDITS'; 
        }
      }

      // 2. Other API Errors
      if (response.status != 200) {
        throw Exception("AI Brain Failed (${response.status}): ${response.data}");
      }

      // 3. Success Parsing
      final List<dynamic> data = response.data; 
      return data.map((e) => QuizQuestion.fromJson(e)).toList();
      
    } catch (e) {
      // 🛑 4. Rethrow Low Credits error so UI can catch it
      if (e == 'LOW_CREDITS') rethrow;
      
      print("Quiz Generation Error: $e");
      rethrow;
    }
  }
}