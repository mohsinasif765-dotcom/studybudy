import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  // 👑 Master Admin Check
  bool get isAdmin {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    // 1. Hardcoded Master Email
    if (user.email == 'mohsinasif765@gmail.com') return true;
    
    // 2. Metadata check (Optional if you want other admins)
    // return user.userMetadata?['is_admin'] == true;
    return false;
  }

  // Fetch Users via Edge Function
  Future<List<dynamic>> getAllUsers() async {
    final response = await _supabase.functions.invoke(
      'admin-actions', // Make sure your function name matches in Supabase
      body: {'action': 'get_all_users'},
    );
    return response.data['users'];
  }

  // Gift Credits via Edge Function
  Future<void> giftCredits(String userId, int amount) async {
    await _supabase.functions.invoke(
      'admin-actions',
      body: {
        'action': 'gift_credits',
        'target_user_id': userId,
        'amount': amount
      },
    );
  }

  // 👇 NEW: Direct DB Update (Allowed by RLS Policy we created)
  Future<void> updateUserPlan(String userId, {required String planId, required bool isVip}) async {
    await _supabase.from('profiles').update({
      'plan_id': planId,
      'is_vip': isVip,
      // 'updated_at': DateTime.now().toIso8601String(), // Optional
    }).eq('id', userId);
  }

  // Payment Requests
  Future<List<dynamic>> getPendingPayments() async {
    final response = await _supabase
        .from('payment_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return response as List<dynamic>;
  }

  Future<void> processPayment(String requestId, String status) async {
    await _supabase.functions.invoke(
      'admin-actions',
      body: {
        'action': 'process_payment',
        'request_id': requestId,
        'status': status
      },
    );
  }
}