import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/summary_model.dart';

class SummaryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Generate Summary
  Future<SummaryModel> generateSummary(String fileContent) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'summary',
          'content': fileContent,
          'options': {} 
        },
      );

      // 🛑 CREDITS CHECK
      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        if (errorMsg.toString().contains('Insufficient credits')) {
          throw 'LOW_CREDITS'; // Special signal for UI
        }
      }

      if (response.status != 200) {
        throw Exception("AI Brain Failed: ${response.data}");
      }

      return SummaryModel.fromJson(response.data);
    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow; // UI ko bhejo
      print("Summary Error: $e");
      rethrow;
    }
  }

  // 2. Translate Summary
  Future<String> translateSummary(String content, String targetLanguage) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'translate',
          'content': content,
          'options': {
            'target_language': targetLanguage,
          }
        },
      );

      // 🛑 CREDITS CHECK
      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        if (errorMsg.toString().contains('Insufficient credits')) {
          throw 'LOW_CREDITS';
        }
      }

      if (response.status != 200) {
        throw Exception("Translation Failed");
      }
      
      return response.data['text'].toString();
    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow;
      print("Translation Error: $e");
      rethrow;
    }
  }

  // 3. Chat with Document
  Future<String> chatWithDocument(String context, String question) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'chat',
          'content': '', 
          'options': {
            'document_context': context,
            'user_question': question,
          }
        },
      );

      // 🛑 CREDITS CHECK
      if (response.status == 400) {
        final errorMsg = response.data['error'] ?? '';
        if (errorMsg.toString().contains('Insufficient credits')) {
          throw 'LOW_CREDITS';
        }
      }

      if (response.status != 200) {
        throw Exception("Chat Failed");
      }
      
      return response.data['text'].toString();
    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow;
      print("Chat Error: $e");
      rethrow;
    }
  }
}