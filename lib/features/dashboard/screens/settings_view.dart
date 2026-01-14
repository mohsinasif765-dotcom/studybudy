import 'dart:async'; // 🔥 Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';
import 'package:prepvault_ai/features/auth/services/auth_service.dart';
import 'package:prepvault_ai/features/subscription/widgets/pricing_modal.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:shimmer/shimmer.dart'; 

// 👇 IMPORT THE CHART & ADS
import 'package:prepvault_ai/features/dashboard/widgets/progress_chart_card.dart'; 
import 'package:prepvault_ai/core/widgets/smart_banner_ad.dart'; 
import 'package:prepvault_ai/core/services/ad_service.dart'; 

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // ===========================================================================
  // 1️⃣ VARIABLES & INIT
  // ===========================================================================
  final _supabase = Supabase.instance.client;
  late Stream<Map<String, dynamic>> _profileStream;
  
  late final StreamSubscription _authSubscription; 

  bool _isProcessing = false;
  bool _isGuest = true; 

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 [SETTINGS] Initializing Settings View...");
    
    _checkCurrentUser();
    _initStream();
    _syncProfileWithServer();

    // 🔥 Listen for Login/Logout Events
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut || event == AuthChangeEvent.initialSession) {
          debugPrint("🔔 [SETTINGS] Auth State Changed: $event");
          _checkCurrentUser(); 
          _initStream(); 
          if(mounted) setState(() {}); 
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel(); 
    super.dispose();
  }

  void _checkCurrentUser() {
    final user = _supabase.auth.currentUser;
    setState(() {
      _isGuest = user == null || user.isAnonymous;
    });
  }

  // ===========================================================================
  // 2️⃣ SERVER SYNC & STREAM
  // ===========================================================================
  Future<void> _syncProfileWithServer() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      debugPrint("🔄 [SETTINGS] Syncing profile for: ${user.id}");
      await _supabase.functions.invoke('payment-manager', body: {'action': 'sync_profile'});
    } catch (e) {
      debugPrint("⚠️ [SETTINGS] Sync Failed: $e");
    }
  }

  void _initStream() {
    final user = _supabase.auth.currentUser;
    
    if (user != null) {
      debugPrint("📡 [SETTINGS] Listening to profile updates for: ${user.id}");
      _profileStream = _supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .map((event) => event.isNotEmpty ? event.first : {});
    } else {
      _profileStream = const Stream.empty();
    }
  }

  // ===========================================================================
  // 3️⃣ ACTIONS
  // ===========================================================================
  void _handleLogout() async {
    try {
      await AuthService().signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

  void _showPricing() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PricingModal(currentPlanId: 'free'), 
    );
  }

  // ⚠️ Cancel function abhi bhi code mein hai taake logic break na ho, 
  // lekin UI se button hata diya gaya hai jesa aapne kaha.
  Future<void> _handleSmartCancel(String provider) async {
    if (provider == 'google_play') {
      _showStoreRedirectDialog(
        title: "Cancel on Play Store",
        message: "Google does not allow apps to cancel subscriptions directly. Please go to Play Store settings to cancel.",
        url: "https://play.google.com/store/account/subscriptions",
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Cancel Subscription?"),
        content: const Text("Your plan will revert to Free immediately. You will lose premium benefits."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Keep Plan")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirm Cancel", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _supabase.functions.invoke(
        'payment-manager',
        body: {'action': 'cancel_subscription'},
      );
      if (res.status != 200) throw "Server Error";
      
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subscription Cancelled Successfully."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cancel failed: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showStoreRedirectDialog({required String title, required String message, required String url}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStart, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(c);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            }, 
            child: const Text("Go to Settings")
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4️⃣ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Column( 
      children: [
        Expanded(
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Colors.grey.shade50,
                body: StreamBuilder<Map<String, dynamic>>(
                  stream: _profileStream,
                  builder: (context, snapshot) {
                    
                    final bool hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
                    final data = snapshot.data ?? {};
                    
                    final String planId = (data['plan_id'] ?? 'free').toString().toLowerCase();
                    final String provider = (data['payment_provider'] ?? 'stripe').toString().toLowerCase();

                    final int totalLimit = data['credits_total'] ?? 0;
                    final int used = data['credits_used'] ?? 0;
                    final int remaining = data['credits_remaining'] ?? 0; 
                    
                    final bool isVip = planId.contains('vip'); 
                    final bool isYearly = planId.contains('yearly') || planId.contains('year'); // ✅ Stronger Check
                    final bool isPro = planId.contains('pro') || planId.contains('scholar');
                    final bool isFree = planId == 'free';
                    final bool isBasic = planId.contains('basic') || planId.contains('student');
                    
                    final double progress = (totalLimit > 0) ? (used / totalLimit) : 0.0;

                    // 🔥 NEW LOGIC: Dynamic Badge Text & Colors
                    String badgeText = "FREE PLAN";
                    Color badgeColor = Colors.grey;
                    IconData badgeIcon = Icons.person_outline;

                    if (planId.contains('mini')) { 
                        badgeText = "MINI PACK"; 
                        badgeColor = Colors.teal; 
                        badgeIcon = Icons.flash_on; 
                    }
                    else if (isBasic) {
                        // ✅ Monthly aur Yearly ka farq
                        if (isYearly) {
                            badgeText = "BASIC YEARLY";
                            badgeColor = const Color(0xFF1565C0); // Darker Blue
                        } else {
                            badgeText = "BASIC MONTHLY";
                            badgeColor = Colors.blue; 
                        }
                        badgeIcon = Icons.star_outline;
                    }
                    else if (isPro) { 
                        // ✅ Monthly aur Yearly ka farq for Pro
                        if (isYearly) {
                            badgeText = "PRO YEARLY";
                            badgeColor = Colors.deepPurple.shade700;
                        } else {
                            badgeText = "PRO MONTHLY";
                            badgeColor = Colors.purple;
                        }
                        badgeIcon = Icons.verified; 
                    }
                    else if (isVip) { 
                        badgeText = "VIP LIFETIME"; 
                        badgeColor = Colors.amber; 
                        badgeIcon = Icons.workspace_premium; 
                    }

                    final user = _supabase.auth.currentUser;
                    final email = _isGuest ? "Not Logged In" : (user?.email ?? "student@example.com");
                    final name = _isGuest ? "Guest User" : (user?.userMetadata?['full_name'] ?? "StudyBuddy User");

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // HEADER SECTION
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primaryStart, AppColors.primaryEnd],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                                ),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 40,
                                      backgroundColor: Colors.white,
                                      child: (_isGuest)
                                        ? const Icon(Icons.account_circle, size: 40, color: Colors.grey)
                                        : (isVip
                                          ? const Icon(Icons.workspace_premium, size: 40, color: Colors.amber)
                                          : Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primaryStart))),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Text(name, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                    
                                    if(!_isGuest)
                                      Text(email, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                                    
                                    const SizedBox(height: 20),
                                    
                                    if (_isGuest) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => context.push('/login'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: AppColors.primaryStart,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                            ),
                                            child: const Text("Log In", style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 15),
                                          OutlinedButton(
                                            onPressed: () => context.push('/signup'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(color: Colors.white, width: 1.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                            ),
                                            child: const Text("Sign Up"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text("Sign up to save progress", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),

                                    ] else ...[
                                      // Logged In UI - Badge Display
                                      GestureDetector(
                                        onTap: (!hasData || isVip) ? null : _showPricing, // VIP ke ilawa sab click kar sakte hain
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white30),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(badgeIcon, color: Colors.white, size: 16),
                                              const SizedBox(width: 8),
                                              _buildShimmerOrText(
                                                isLoading: !hasData, 
                                                text: badgeText,
                                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                                                width: 80,
                                                baseColor: Colors.white24,
                                                highlightColor: Colors.white54,
                                              ),
                                              if (!isVip && hasData) ...[ 
                                                const SizedBox(width: 5),
                                                const Icon(Icons.arrow_forward, color: Colors.white70, size: 14)
                                              ]
                                            ],
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),

                              // PERFORMANCE CHART
                              const SizedBox(height: 20),
                              const UserProgressChart(),
                              const SizedBox(height: 10),

                              // CREDITS & USAGE SECTION
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                                    border: (!isFree && !_isGuest) ? Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5) : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Credits Usage", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                          _buildShimmerOrText(
                                            isLoading: !hasData,
                                            text: isFree ? "Resets Daily" : (isYearly ? "Resets Yearly" : "Resets Monthly"),
                                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                                            width: 100,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // SHIMMER PROGRESS
                                      !hasData 
                                        ? Shimmer.fromColors(
                                          baseColor: Colors.grey.shade200,
                                          highlightColor: Colors.grey.shade100,
                                          child: Container(height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                                        )
                                        : ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: isVip ? 1.0 : progress,
                                            minHeight: 10,
                                            backgroundColor: Colors.grey.shade100,
                                            color: isVip ? Colors.amber : (progress > 0.9 ? Colors.red : AppColors.primaryStart),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildStatItem("Used", "$used", Colors.grey.shade700, !hasData),
                                          Container(height: 30, width: 1, color: Colors.grey.shade200),
                                          _buildStatItem("Remaining", isVip ? "∞" : "$remaining", AppColors.primaryStart, !hasData),
                                          Container(height: 30, width: 1, color: Colors.grey.shade200),
                                          _buildStatItem("Total Limit", isVip ? "∞" : "$totalLimit", isVip ? Colors.amber : Colors.blue, !hasData),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // SETTINGS LIST SECTION
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    
                                    if (!_isGuest)
                                      _buildSettingTile(icon: Icons.person_outline, title: "Edit Profile", onTap: () {}),
                                    
                                    // 🔥 UPDATED UPGRADE BUTTON LOGIC
                                    // Yeh button ab sirf VIP users ke liye gayab hoga. 
                                    // Yearly/Monthly users ke liye show hoga taake wo plan change kar sakein.
                                    if (hasData && !isVip)
                                      _buildSettingTile(
                                        icon: Icons.rocket_launch_outlined,
                                        title: isFree ? "Upgrade to Pro" : "Change / Upgrade Plan",
                                        subtitle: isFree ? "Unlock unlimited credits" : "Switch to Yearly or VIP",
                                        isHighlight: true,
                                        onTap: _showPricing,
                                      ),
                                    
                                    // ❌ Cancel Button removed from UI as requested

                                    const SizedBox(height: 20),
                                    _buildSectionHeader("Support"),
                                    _buildSettingTile(icon: Icons.contact_support_outlined, title: "Help & Support", onTap: () => context.push('/contact')),
                                    _buildSettingTile(icon: Icons.policy_outlined, title: "Privacy & Terms", onTap: () => context.push('/legal/privacy')),

                                    const SizedBox(height: 30),
                                    
                                    if (!_isGuest)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _handleLogout,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade50,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.all(16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.logout),
                                          label: const Text("Sign Out"),
                                        ),
                                      ),
                                    
                                    const SizedBox(height: 40),
                                    
                                    Column(
                                      children: [
                                        Text("Version 1.5.5", style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text("Powered by AlMohsin Dev for you with ", style: GoogleFonts.spaceGrotesk(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                            const Icon(Icons.favorite, color: Colors.red, size: 14),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primaryStart),
                          const SizedBox(height: 20),
                          Text("Processing Request...", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Please wait", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // BANNER AD (VIP LOGIC)
        ValueListenableBuilder<bool>(
          valueListenable: AdService().isFreeUserNotifier, 
          builder: (context, isFreeUser, child) {
            if (!isFreeUser) return const SizedBox.shrink(); 
            
            return const SafeArea(
              top: false,
              child: SmartBannerAd(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 5️⃣ HELPER WIDGETS
  // ===========================================================================
  
  Widget _buildShimmerOrText({
    required bool isLoading, 
    required String text, 
    required TextStyle style, 
    double width = 60,
    Color baseColor = const Color(0xFFE0E0E0), 
    Color highlightColor = const Color(0xFFF5F5F5), 
  }) {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: width,
          height: style.fontSize != null ? style.fontSize! + 4 : 14,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
        ),
      );
    }
    return Text(text, style: style);
  }

  Widget _buildStatItem(String label, String value, Color color, bool isLoading) {
    return Expanded(
      child: Column(
        children: [
          _buildShimmerOrText(
            isLoading: isLoading, 
            text: value, 
            style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            width: 40,
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)));
  }
  
  Widget _buildSettingTile({required IconData icon, required String title, String? subtitle, bool isHighlight = false, bool isDestructive = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primaryStart.withValues(alpha: 0.05) : (isDestructive ? Colors.red.shade50 : Colors.white), 
        borderRadius: BorderRadius.circular(16), 
        border: isHighlight ? Border.all(color: AppColors.primaryStart.withValues(alpha: 0.3)) : null, 
        boxShadow: [if (!isHighlight && !isDestructive) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isHighlight ? AppColors.primaryStart : (isDestructive ? Colors.red : Colors.grey.shade100), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isHighlight || isDestructive ? Colors.white : Colors.grey.shade600, size: 22)), title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: isDestructive ? Colors.red.shade900 : Colors.black87)), subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.outfit(color: isDestructive ? Colors.red.shade300 : Colors.grey, fontSize: 12)) : null, trailing: Icon(Icons.chevron_right, color: isDestructive ? Colors.red.shade200 : Colors.grey.shade400)),
    );
  }
}