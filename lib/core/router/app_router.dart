import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_gateway.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/courses/screens/courses_screen.dart';
import '../../features/courses/screens/course_detail_screen.dart';
import '../../features/learn/screens/learn_screen.dart';
import '../../features/instructor/screens/instructor_dashboard_screen.dart';
import '../../features/btob/screens/btob_dashboard_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/certificates/screens/certificates_screen.dart';
import '../../features/progress/screens/course_progress_screen.dart';
import '../../shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isAuth = ref.read(authGatewayProvider).isSignedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/courses', builder: (_, _) => const CoursesScreen()),
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
          GoRoute(path: '/instructor', builder: (_, _) => const InstructorDashboardScreen()),
          GoRoute(path: '/btob', builder: (_, _) => const BtobDashboardScreen()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: '/certificates', builder: (_, _) => const CertificatesScreen()),
          GoRoute(
            path: '/courses/:courseId/progress',
            builder: (_, state) => CourseProgressScreen(courseId: state.pathParameters['courseId']!),
          ),
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
