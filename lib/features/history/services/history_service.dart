import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/history_model.dart';

class HistoryService {
  final _supabase = Supabase.instance.client;

  // 1. Get History List
  Future<List<HistoryItem>> getHistory() async {
    try {
      final response = await _supabase
          .from('study_history')
          .select()
          .order('created_at', ascending: false); // Newest first

      // JSON list ko Dart objects mein badalna
      return (response as List).map((e) => HistoryItem.fromJson(e)).toList();
    } catch (e) {
      print("Error fetching history: $e");
      return []; // Agar error aaye to khali list bhejo taake app crash na ho
    }
  }

  // 2. Delete Item
  Future<void> deleteItem(String id) async {
    try {
      await _supabase.from('study_history').delete().eq('id', id);
    } catch (e) {
      print("Error deleting item: $e");
    }
  }
}