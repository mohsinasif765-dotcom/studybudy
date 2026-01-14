import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HiveLocalStorage extends LocalStorage {
  const HiveLocalStorage();

  @override
  Future<void> initialize() async {
    // Hive ko start karo
    await Hive.initFlutter();
  }

  @override
  Future<String?> accessToken() async {
    // Token uthao
    final box = await Hive.openBox('supabase_auth');
    return box.get('access_token') as String?;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    // Token save karo
    final box = await Hive.openBox('supabase_auth');
    return box.put('access_token', persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    // Token delete karo (Logout par)
    final box = await Hive.openBox('supabase_auth');
    return box.delete('access_token');
  }

  @override
  Future<bool> hasAccessToken() async {
    final box = await Hive.openBox('supabase_auth');
    return box.containsKey('access_token');
  }
}