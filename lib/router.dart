import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth Screens
import 'package:studybudy_ai/features/auth/screens/login_screen.dart';
import 'package:studybudy_ai/features/auth/screens/signup_screen.dart';
import 'package:studybudy_ai/features/auth/screens/forgot_password_screen.dart';
import 'package:studybudy_ai/features/auth/screens/splash_screen.dart';

// Feature Screens
import 'package:studybudy_ai/features/dashboard/screens/dashboard_screen.dart';
import 'package:studybudy_ai/features/quiz/screens/quiz_setup_screen.dart';
import 'package:studybudy_ai/features/summary/screens/summary_view_screen.dart';
import 'package:studybudy_ai/features/dashboard/screens/contact_view.dart';

// Admin Screens & Service
import 'package:studybudy_ai/features/admin/screens/admin_layout.dart';
import 'package:studybudy_ai/features/admin/services/admin_service.dart';

// 👇 NEW: Legal Screens Imports (Make sure path is correct)
import 'package:studybudy_ai/features/legal/screens/privacy_policy_screen.dart';
import 'package:studybudy_ai/features/legal/screens/terms_conditions_screen.dart';

final router = GoRouter(
  initialLocation: '/', 
  routes: [
    // 1. Splash Screen
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // 2. Auth Routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // 3. Main Dashboard & Admin
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminLayout(),
    ),

    // 4. Features & Support
    GoRoute(
      path: '/summary',
      builder: (context, state) {
        final content = state.extra as String? ?? '';
        return SummaryViewScreen(fileContent: content);
      },
    ),
    GoRoute(
      path: '/quiz-setup',
      builder: (context, state) {
        final fileContent = state.extra as String? ?? ''; 
        return QuizSetupScreen(fileContent: fileContent);
      },
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) => const ContactView(),
    ),

    // 5. Legal Routes (👇 UPDATED HERE)
    GoRoute(
      path: '/legal/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (context, state) => const TermsConditionsScreen(),
    ),
  ],

  // 🛡️ SECURITY GUARD
  redirect: (context, state) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      
      // Define Paths
      final path = state.uri.toString();
      final isPublicRoute = path == '/' || 
                            path == '/login' || 
                            path == '/signup' || 
                            path == '/forgot-password';
                            
      final isAdminRoute = path.startsWith('/admin');

      // 1. Agar User Logged OUT hai, aur Private Route par jane ki koshish kar raha hai
      if (session == null && !isPublicRoute) {
        return '/login';
      }

      // 2. Agar User Logged IN hai, aur Public Route (Login/Signup) par hai
      if (session != null && isPublicRoute && path != '/') {
        return '/dashboard';
      }

      // 3. 🛡️ ADMIN SECURITY CHECK
      if (session != null && isAdminRoute) {
        final isAdmin = AdminService().isAdmin;
        if (!isAdmin) {
          return '/dashboard';
        }
      }

      return null; 
      
    } catch (e) {
      return null;
    }
  },
);