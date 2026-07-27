import 'package:ai_demy_app/core/auth/auth_gateway.dart';
import 'package:ai_demy_app/features/auth/screens/login_screen.dart';
import 'package:ai_demy_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_gateway.dart';
import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

/// ルーターは配下の画面を実際にビルドするため、
/// 画面が叩くテーブルをひと通り用意しておく。
Future<void> _initBackend({String? signedInUserId}) => initSupabaseForTest(
  signedInUserId: signedInUserId,
  tables: {
    'users': (_) => {'display_name': '里村', 'streak_count': 3},
    'enrollments': (_) => [],
    // 1件のリストは単一行クエリ（.single()）にもリストクエリにも使える
    'courses': (_) => [
      {
        'id': 'course-1',
        'title': 'AI入門',
        'description': '説明',
        'thumbnail_url': null,
        'price_type': 'free',
        'price_monthly': null,
        'price_one_time': null,
        'is_published': true,
        'users': {'display_name': '山田先生', 'avatar_url': null},
      },
    ],
    'curriculum_units': (_) => [
      {
        'id': 'unit-9',
        'title': 'ユニット1',
        'order_index': 1,
        'difficulty': 'beginner',
      },
    ],
    'chat_messages': (_) => [],
  },
);

void main() {
  tearDown(disposeSupabaseForTest);

  group('未ログイン', () {
    testWidgets('保護されたページを開くと /login にリダイレクトされる', (tester) async {
      await _initBackend();

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: false),
          ),
        ],
      );

      // initialLocation は /dashboard
      expect(currentLocation(router), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('コース一覧へ遷移しようとしても /login に戻される', (tester) async {
      await _initBackend();

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: false),
          ),
        ],
      );

      router.go('/courses');
      await settle(tester);

      expect(currentLocation(router), '/login');
    });

    testWidgets('/register はリダイレクトされない', (tester) async {
      await _initBackend();

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: false),
          ),
        ],
      );

      router.go('/register');
      await settle(tester);

      expect(currentLocation(router), '/register');
    });
  });

  group('ログイン済み', () {
    testWidgets('初期表示はダッシュボード', (tester) async {
      await _initBackend(signedInUserId: 'user-1');

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: true),
          ),
        ],
      );

      expect(currentLocation(router), '/dashboard');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('/login を開くと /dashboard に戻される', (tester) async {
      await _initBackend(signedInUserId: 'user-1');

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: true),
          ),
        ],
      );

      router.go('/login');
      await settle(tester);

      expect(currentLocation(router), '/dashboard');
    });

    testWidgets('コース詳細の学習画面までパスパラメータが渡る', (tester) async {
      await _initBackend(signedInUserId: 'user-1');

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: true),
          ),
        ],
      );

      router.go('/courses/course-1/learn/unit-9');
      await settle(tester);

      expect(currentLocation(router), '/courses/course-1/learn/unit-9');
    });

    testWidgets('存在しないパスはエラーページを表示する', (tester) async {
      await _initBackend(signedInUserId: 'user-1');

      final router = await pumpAppRouter(
        tester,
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: true),
          ),
        ],
      );

      router.go('/no-such-page');
      await settle(tester);

      expect(find.textContaining('ページが見つかりません'), findsOneWidget);
    });
  });

  testWidgets('SupabaseAuthGateway は Supabase のセッション有無を反映する', (tester) async {
    await _initBackend(signedInUserId: 'user-1');
    expect(const SupabaseAuthGateway().isSignedIn, isTrue);

    await disposeSupabaseForTest();

    await _initBackend();
    expect(const SupabaseAuthGateway().isSignedIn, isFalse);
  });
}
