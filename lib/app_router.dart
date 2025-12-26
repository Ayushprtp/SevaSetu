import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_page.dart';
import 'main_screen.dart';
import 'admin/admin_page.dart';
import 'admin/admin_dashboard_page.dart';
import 'admin/role_based_dashboard.dart';
import 'admin/worker_dashboard_page.dart';
import 'issues/issue_detail_page.dart';
import 'profile/profile_page.dart';
import 'profile/my_reports_page.dart';
import 'profile/edit_profile_page.dart';
import 'notifications/notifications_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
    GoRoute(path: '/home', builder: (context, state) => const MainScreen()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const RoleBasedDashboard(),
    ),
    GoRoute(
      path: '/worker-dashboard',
      builder: (context, state) => const WorkerDashboardPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/issue/:issueId',
      builder: (context, state) =>
          IssueDetailPage(issueId: state.pathParameters['issueId']!),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) =>
          EditProfilePage(userData: state.extra as Map<String, dynamic>?),
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

    // If the user is not authenticated, redirect to the auth page
    if (!isAuthenticated) {
      return '/auth';
    }

    // If the user is authenticated and trying to access the auth page, redirect to home
    if (state.fullPath == '/auth' && isAuthenticated) {
      // No need to fetch role here, as we're just redirecting authenticated users from auth page
      return '/home';
    }

    // For all other cases, allow navigation to the requested path
    return null;
  },
  initialLocation:
      '/auth', // Keep initialLocation as /auth for unauthenticated users
);
