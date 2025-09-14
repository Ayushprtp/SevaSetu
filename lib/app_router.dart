import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'home_page.dart';
import 'admin_page.dart';
import 'issue_detail_page.dart';
import 'profile_page.dart';
import 'my_reports_page.dart';
import 'edit_profile_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPage(),
    ),
    GoRoute(
      path: '/issue/:issueId',
      builder: (context, state) => IssueDetailPage(
        issueId: state.pathParameters['issueId']!,
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => EditProfilePage(userData: state.extra as Map<String, dynamic>?),
    ),
    GoRoute(
      path: '/my-reports',
      builder: (context, state) => const MyReportsPage(),
    ),
  ],
  redirect: (context, state) async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final isAuthenticated = session != null;

    if (!isAuthenticated) {
      return '/auth';
    }

    // If authenticated, check user role and redirect
    if (state.fullPath == '/auth' && isAuthenticated) {
      final user = supabase.auth.currentUser;
      if (user != null) {
        try {
          final response = await supabase
              .from('users')
              .select('id')
              .eq('id', user.id)
              .single();

          // Since there's no role column in the users table, we'll navigate to home for all users
          // and to admin only if the user has admin privileges (which would be checked separately)
          return '/home';
        } catch (e) {
          debugPrint('Error fetching role during redirect: $e');
          return '/auth'; // Fallback to auth on error
        }
      }
    }
    return null;
  },
  initialLocation: '/auth',
);