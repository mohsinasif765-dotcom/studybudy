import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // 👈 Added for navigation
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/auth/services/auth_service.dart';
import 'package:studybudy_ai/features/subscription/widgets/pricing_modal.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isDark = false;
  bool _notifications = true;

  void _handleLogout() async {
    await AuthService().signOut();
    if (mounted) context.go('/login');
  }

  void _showPricing() {
    showDialog(
      context: context,
      barrierDismissible: true,
      // Note: Ideal implementation would fetch the real currentPlanId
      builder: (context) => const PricingModal(currentPlanId: 'free'), 
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final email = user?.email ?? "student@example.com";
    final name = user?.userMetadata?['full_name'] ?? "StudyBuddy User";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PROFILE HEADER
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, size: 40, color: AppColors.primaryStart),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              child: const Icon(Icons.star, size: 16, color: Colors.white),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(email, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                      
                      const SizedBox(height: 20),
                      
                      // Plan Badge (Clickable)
                      GestureDetector(
                        onTap: _showPricing,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.diamond_outlined, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text("Free Plan - Upgrade", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. SETTINGS LIST
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("Account"),
                      _buildSettingTile(
                        icon: Icons.person_outline,
                        title: "Edit Profile",
                        subtitle: "Change name and details",
                        onTap: () {},
                      ),
                      _buildSettingTile(
                        icon: Icons.credit_card,
                        title: "Subscription",
                        subtitle: "Manage plan & billing",
                        onTap: _showPricing,
                      ),
                      _buildSettingTile(
                        icon: Icons.notifications_outlined,
                        title: "Notifications",
                        subtitle: "Manage app alerts",
                        trailing: Switch(
                          value: _notifications,
                          activeColor: AppColors.primaryStart,
                          onChanged: (val) => setState(() => _notifications = val),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildSectionHeader("Appearance"),
                      _buildSettingTile(
                        icon: Icons.dark_mode_outlined,
                        title: "Dark Mode",
                        subtitle: "Easier on eyes",
                        trailing: Switch(
                          value: _isDark,
                          activeColor: AppColors.primaryStart,
                          onChanged: (val) => setState(() => _isDark = val),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildSectionHeader("Support & Legal"),
                      
                      // 🔗 HELP & SUPPORT TILE
                      _buildSettingTile(
                        icon: Icons.help_outline,
                        title: "Help & Support",
                        subtitle: "FAQ and Contact Us",
                        onTap: () => context.push('/contact'), // 👈 Connects to ContactView
                      ),
                      
                      // 🔗 PRIVACY POLICY TILE
                      _buildSettingTile(
                        icon: Icons.privacy_tip_outlined,
                        title: "Privacy Policy",
                        subtitle: "How we handle your data",
                        onTap: () => context.push('/legal/privacy'),
                      ),
                      
                      // 🔗 TERMS & CONDITIONS TILE
                      _buildSettingTile(
                        icon: Icons.balance_outlined,
                        title: "Terms & Conditions",
                        subtitle: "Usage rules and disclaimers",
                        onTap: () => context.push('/legal/terms'),
                      ),

                      const SizedBox(height: 30),
                      
                      // LOGOUT BUTTON
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
                      
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          "StudyBuddy AI v1.0.0\nMade with ❤️ by AlMohsin",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryStart.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryStart),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}