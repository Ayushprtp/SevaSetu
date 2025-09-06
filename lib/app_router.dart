import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'home_page.dart';
import 'admin_page.dart';

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
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .single();
          final role = response['role'] as String?;

          if (role == 'admin') {
            return '/admin';
          } else if (role == 'user') {
            return '/home';
          }
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