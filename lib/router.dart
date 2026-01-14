import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// 1️⃣ SCREEN IMPORTS (Sab mehfooz hain)
// =============================================================================

// Auth & Onboarding
import 'package:prepvault_ai/features/auth/screens/splash_screen.dart';
import 'package:prepvault_ai/features/onboarding/screens/onboarding_screen.dart';
import 'package:prepvault_ai/features/auth/screens/login_screen.dart';
import 'package:prepvault_ai/features/auth/screens/signup_screen.dart';
import 'package:prepvault_ai/features/auth/screens/forgot_password_screen.dart';

// Dashboard & Core
import 'package:prepvault_ai/features/dashboard/screens/dashboard_screen.dart';
import 'package:prepvault_ai/features/dashboard/screens/contact_view.dart';
import 'package:prepvault_ai/features/dashboard/screens/settings_view.dart';
import 'package:prepvault_ai/features/history/screens/history_view_screen.dart';
import 'package:prepvault_ai/features/summary/screens/summary_view_screen.dart'; 

// Official Exam Store
import 'package:prepvault_ai/features/store/screens/official_store_screen.dart';

// Quiz Feature
import 'package:prepvault_ai/features/quiz/screens/quiz_setup_screen.dart';
import 'package:prepvault_ai/features/quiz/screens/quiz_dashboard_screen.dart';
import 'package:prepvault_ai/features/quiz/screens/quiz_play_screen.dart';
import 'package:prepvault_ai/features/quiz/screens/quiz_read_screen.dart';
import 'package:prepvault_ai/features/quiz/screens/quiz_result_screen.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart'; 

// Question Set Feature
import 'package:prepvault_ai/features/questionset/screens/question_set_setup_screen.dart';
import 'package:prepvault_ai/features/questionset/screens/question_set_dashboard.dart';
import 'package:prepvault_ai/features/questionset/screens/question_set_read_screen.dart';

// Misc & Subscription
import 'package:prepvault_ai/features/subscription/screens/payment_success_screen.dart';
import 'package:prepvault_ai/features/subscription/widgets/pricing_modal.dart';

import 'package:prepvault_ai/features/legal/screens/privacy_policy_screen.dart';
import 'package:prepvault_ai/features/legal/screens/terms_conditions_screen.dart';

// =============================================================================
// 2️⃣ ROUTER CONFIGURATION
// =============================================================================

GoRouter createRouter() {
  debugPrint("🛠️ [ROUTER] Creating Router Instance...");
  
  return GoRouter(
    initialLocation: '/', 
    
    debugLogDiagnostics: true, 

    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),

    errorBuilder: (context, state) {
      debugPrint("❌ [ROUTER ERROR]: ${state.error}");
      return const DashboardScreen();
    },

    routes: [
      
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
      // 🔥 FIX 1: /auth route add kiya hai jo LoginScreen kholay ga
      GoRoute(path: '/auth', builder: (context, state) => const LoginScreen()),

      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()), 
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsView()),
      GoRoute(path: '/history', builder: (context, state) => const HistoryViewScreen()),
      GoRoute(path: '/contact', builder: (context, state) => const ContactView()),
      
      GoRoute(path: '/exam-store', builder: (context, state) => const OfficialStoreScreen()),
      
      GoRoute(
        path: '/summary/:id',
        builder: (context, state) {
          final String summaryId = state.pathParameters['id'] ?? '';
          return SummaryViewScreen(summaryId: summaryId); 
        }
      ),

      GoRoute(path: '/quiz-setup', builder: (context, state) {
        final fileContent = state.extra as String?; 
        return QuizSetupScreen(fileContent: fileContent);
      }),

      GoRoute(
        path: '/quiz-dashboard/:id',
        builder: (context, state) {
          final String quizId = state.pathParameters['id'] ?? '';
          return QuizDashboardScreen(quizId: quizId);
        }
      ),

      GoRoute(
        path: '/quiz-player', 
        builder: (context, state) {
          final extra = state.extra;
          if (extra is List) {
            try {
              final questions = extra.cast<QuizQuestion>();
              return QuizPlayScreen(questions: questions);
            } catch (e) { return const DashboardScreen(); }
          }
          if (extra is Map<String, dynamic>) {
            try {
               final quizData = extra['quizData'];
               List<QuizQuestion> questions = [];
               if (quizData is List) {
                 questions = quizData.map((e) => QuizQuestion.fromJson(e)).toList();
               } 
               else if (quizData is Map<String, dynamic>) {
                 if (quizData.containsKey('data') && quizData['data'] is List) {
                   questions = (quizData['data'] as List).map((e) => QuizQuestion.fromJson(e)).toList();
                 } else if (quizData.containsKey('questions') && quizData['questions'] is List) {
                   questions = (quizData['questions'] as List).map((e) => QuizQuestion.fromJson(e)).toList();
                 }
               }
               if (questions.isNotEmpty) {
                 return QuizPlayScreen(questions: questions);
               }
            } catch (e) { debugPrint("❌ Parse Error: $e"); }
          }
          return const DashboardScreen();
        }
      ),

      GoRoute(
        path: '/quiz-result',
        builder: (context, state) {
          final data = state.extra;
          if (data is! Map<String, dynamic>) return const DashboardScreen();
          return QuizResultScreen(
            score: data['score'] ?? 0,
            totalQuestions: data['totalQuestions'] ?? 0,
            questions: (data['questions'] as List?)?.cast<QuizQuestion>() ?? [],
          );
        },
      ),

      GoRoute(path: '/quiz-read', builder: (context, state) {
        final extra = state.extra;
        if (extra is List) {
          try {
            final questions = extra.cast<QuizQuestion>();
            return QuizReadScreen(questions: questions);
          } catch (e) { return const DashboardScreen(); }
        }
        return const DashboardScreen();
      }),

      GoRoute(path: '/questionset-setup', builder: (context, state) {
        final fileContent = state.extra as String?; 
        return QuestionSetSetupScreen(fileContent: fileContent);
      }),

      GoRoute(
        path: '/questionset-dashboard/:id',
        builder: (context, state) {
          final String id = state.pathParameters['id'] ?? '';
          return QuestionSetDashboard(questionSetId: id); 
        }
      ),

      GoRoute(
        path: '/questionset-read', 
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?; 
          if (extra != null) {
            try {
              final questions = (extra['questions'] as List).cast<QuizQuestion>();
              final title = extra['title'] as String? ?? 'Theory Read';
              return QuestionSetReadScreen(questions: questions, title: title);
            } catch (e) { return const DashboardScreen(); }
          }
          return const DashboardScreen(); 
        }
      ),
      
      GoRoute(
        path: '/subscription',
        builder: (context, state) {
           final planId = state.extra as String? ?? 'free';
           return PricingModal(
             currentPlanId: planId,
             isFullScreen: true, 
             onContinueFree: () async {
               final session = Supabase.instance.client.auth.currentSession;
               if (session == null) {
                  try {
                    await Supabase.instance.client.auth.signInAnonymously();
                  } catch (e) {
                    debugPrint("⚠️ Guest Sign-in Failed: $e");
                  }
               }
               if (context.mounted) {
                 context.go('/dashboard'); 
               }
             },
           ); 
        },
      ),
      
      GoRoute(path: '/payment-success', builder: (context, state) => const PaymentSuccessScreen()),
      GoRoute(path: '/legal/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/legal/terms', builder: (context, state) => const TermsConditionsScreen()),
      
    ],

    // =========================================================================
    // 3️⃣ AUTH GUARD & REDIRECT LOGIC
    // =========================================================================
    redirect: (context, state) {
      final String path = state.uri.path;
      
      if (path == '/payment-success' || 
          path == '/subscription' || 
          path.startsWith('/legal')) {
        return null; 
      }

      try {
        final session = Supabase.instance.client.auth.currentSession;
        final bool isGuest = session?.user.isAnonymous ?? false;
        
        // 🔥 FIX 2: /auth ko bhi is list mein shamil kiya
        final isAuthRoute = path == '/login' || 
                           path == '/signup' || 
                           path == '/auth' ||  
                           path == '/forgot-password';

        final isPublicEntryRoute = path == '/' || path == '/onboarding';

        // A. Agar session bilkul nahi hai (Naya User)
        if (session == null) {
          if (!isAuthRoute && !isPublicEntryRoute) {
              return '/onboarding'; 
          }
          return null; 
        }

        // B. Agar User Guest (Anonymous) hai
        if (isGuest) {
          if (isAuthRoute) {
            debugPrint("🟢 [ROUTER] Allowing Guest to visit $path");
            return null; 
          }
          return null;
        }

        // C. Agar User REAL (Permanent) hai
        if (!isGuest) {
          if (isAuthRoute || path == '/onboarding') {
             final fromPage = state.uri.queryParameters['from'];
             if (fromPage == 'subscription') return '/subscription';
             
             return '/dashboard';
          }
        }

        return null; 
        
      } catch (e) {
        debugPrint("⚠️ [ROUTER] Redirect Warning: $e");
        return null;
      }
    },
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((AuthState event) {
      debugPrint("🔔 [AUTH STATE CHANGED]: $event");
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}