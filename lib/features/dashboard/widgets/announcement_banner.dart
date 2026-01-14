import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  String? _message;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncement();
  }

  Future<void> _fetchAnnouncement() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    try {
      // 1. Check for Specific Message first (Priority)
      final specificMsg = await supabase
          .from('announcements')
          .select('message')
          .eq('is_active', true)
          .eq('target_user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (specificMsg != null) {
        if (mounted) setState(() { _message = specificMsg['message']; _isVisible = true; });
        return;
      }

      // 2. If no specific, check Global Message
      final globalMsg = await supabase
          .from('announcements')
          .select('message')
          .eq('is_active', true)
          // 🛑 FIX: .is_() ki jagah .filter() use karein
          .filter('target_user_id', 'is', null) 
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (globalMsg != null) {
        if (mounted) setState(() { _message = globalMsg['message']; _isVisible = true; });
      }

    } catch (e) {
      debugPrint("Announcement Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message!,
              style: GoogleFonts.outfit(
                color: Colors.brown.shade800, 
                fontSize: 13, 
                fontWeight: FontWeight.w600
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isVisible = false),
            child: const Icon(Icons.close, size: 16, color: Colors.brown),
          )
        ],
      ),
    );
  }
}