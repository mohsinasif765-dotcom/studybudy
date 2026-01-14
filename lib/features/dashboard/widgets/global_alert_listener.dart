import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'dart:math';

class GlobalAlertListener extends StatefulWidget {
  final Widget? child;
  const GlobalAlertListener({super.key, this.child});

  @override
  State<GlobalAlertListener> createState() => _GlobalAlertListenerState();
}

class _GlobalAlertListenerState extends State<GlobalAlertListener> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final AnimationController _controller;
  
  // ⚡ NEW: Local list to hide alerts immediately when clicked
  final Set<String> _dismissedLocally = {}; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ IMPROVED DELETE LOGIC
  Future<void> _dismissAlert(String id) async {
    // 1. Pehle Screen se foran hatao (Optimistic UI)
    setState(() {
      _dismissedLocally.add(id);
    });

    debugPrint("🗑️ Deleting Alert ID from DB: $id");
    
    // 2. Phir Database se delete karo
    try {
      await _supabase.from('user_alerts').delete().eq('id', id);
    } catch (e) {
      debugPrint("❌ DB Delete Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return widget.child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (widget.child != null) widget.child!,

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase
              .from('user_alerts')
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            // Find the first alert that hasn't been dismissed locally
            final activeAlerts = snapshot.data!.where((a) => !_dismissedLocally.contains(a['id'].toString())).toList();

            if (activeAlerts.isEmpty) return const SizedBox.shrink();

            final alert = activeAlerts.first;
            final String id = alert['id'].toString(); // Ensure String
            final String title = alert['title'] ?? "Notification";
            final String message = alert['message'] ?? "";
            final String type = alert['type'] ?? 'info';

            // 🎨 DYNAMIC UI SETTINGS
            String btnText = "Awesome!";
            Color btnColor = AppColors.primaryStart;
            bool showConfetti = false;

            if (type == 'vip' || type == 'plan' || title.contains('Success')) {
               btnText = "Awesome!";
               btnColor = Colors.amber;
               showConfetti = true;
            } else if (title.contains('Cancel') || type == 'info') {
               btnText = "Got it";
               // 🔥 CHANGED: Grey button ko Dark Black kiya taake saaf dikhe
               btnColor = Colors.black87; 
               showConfetti = false;
            }

            return Stack(
              children: [
                // 1. Dim Background
                Container(
                  color: const Color.fromRGBO(0, 0, 0, 0.6), 
                  width: double.infinity,
                  height: double.infinity,
                ),

                // 2. Confetti (Only for Success)
                if (showConfetti)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: ConfettiPainter(_controller),
                      size: Size.infinite,
                    ),
                  ),

                // 3. Popup Card
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.2), blurRadius: 20, spreadRadius: 5) 
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIcon(type, title),
                          const SizedBox(height: 20),
                          
                          // Title (Already Black, keeping it sharp)
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // 🔥 Pure Black
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // Message Text
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 16, 
                              // 🔥 CHANGED: Grey se Black87 (Darker for readability)
                              color: Colors.black87, 
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _dismissAlert(id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: btnColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 4,
                              ),
                              child: Text(
                                btnText,
                                style: GoogleFonts.outfit(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildIcon(String type, String title) {
    if (title.contains('Cancel')) {
       return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        // 🔥 CHANGED: Icon Color Dark Black
        child: Icon(Icons.info_outline, size: 40, color: Colors.black87),
      );
    }
    if (type == 'vip') {
      return const CircleAvatar(
        radius: 40,
        backgroundColor: Colors.amber,
        child: Icon(Icons.diamond, size: 40, color: Colors.white),
      );
    } 
    // Default Success
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.green.shade400,
      child: const Icon(Icons.check_circle_outline, size: 45, color: Colors.white),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final Random _random = Random();

  ConfettiPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 50; i++) {
      paint.color = [Colors.red, Colors.blue, Colors.green, Colors.amber, Colors.purple][_random.nextInt(5)];
      final double x = _random.nextDouble() * size.width;
      final double startY = _random.nextDouble() * size.height;
      final double y = (startY + (animation.value * size.height)) % size.height;
      canvas.drawCircle(Offset(x, y), 3 + _random.nextDouble() * 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}