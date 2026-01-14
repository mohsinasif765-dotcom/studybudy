import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class NotificationDrawer extends StatefulWidget {
  const NotificationDrawer({super.key});

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    return _supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.where((item) {
              final target = item['target_user_id'];
              final isActive = item['is_active'] == true;
              return isActive && (target == null || target == userId);
            }).toList());
  }

  String _formatTime(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Notifications",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // 🔥 CHANGED: Explicit Black
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black), // 🔥 Icon Black
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.shade200),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.black12), // Darker Divider
          
          // List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading notifications"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final msgs = snapshot.data!;
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          "No new notifications",
                          style: GoogleFonts.outfit(
                            color: Colors.black54, // 🔥 CHANGED: Grey se Dark Grey
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: msgs.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isGlobal = msg['target_user_id'] == null;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isGlobal ? Colors.blue.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isGlobal ? Colors.blue.shade200 : Colors.amber.shade200, // Thora dark border
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isGlobal ? Icons.campaign : Icons.star, 
                                size: 18, 
                                // Icons colors are already good (Blue/Amber)
                                color: isGlobal ? Colors.blue.shade700 : Colors.amber.shade800
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isGlobal ? "Announcement" : "Personal Message",
                                style: GoogleFonts.outfit(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.black87, // 🔥 CHANGED: Grey se Black
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTime(msg['created_at']), 
                                style: const TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54 // 🔥 CHANGED: Grey se Darker color
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            msg['message'], 
                            style: GoogleFonts.outfit(
                              fontSize: 15, 
                              height: 1.4,
                              color: Colors.black, // 🔥 CHANGED: Pure Black for message
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}