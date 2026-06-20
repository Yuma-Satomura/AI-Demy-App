import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/courses/screens/courses_screen.dart';
import '../../features/courses/screens/course_detail_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/instructor/screens/instructor_dashboard_screen.dart';
import '../../features/btob/screens/btob_dashboard_screen.dart';
import '../../shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isAuth = user != null;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
          GoRoute(
            path: '/courses/:courseId',
            builder: (_, state) => CourseDetailScreen(courseId: state.pathParameters['courseId']!),
            routes: [
              GoRoute(
                path: 'learn/:unitId',
                builder: (_, state) => LearnScreen(
                  courseId: state.pathParameters['courseId']!,
                  unitId: state.pathParameters['unitId']!,
                ),
              ),
            ],
          ),
          GoRoute(path: '/instructor', builder: (_, __) => const InstructorDashboardScreen()),
          GoRoute(path: '/btob', builder: (_, __) => const BtobDashboardScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
