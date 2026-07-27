import 'package:ai_demy_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'user-1';

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('ユーザー名・ストリーク・受講中コースが表示される', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 12},
        'enrollments': (_) => [
          {
            'course_id': 'course-1',
            'courses': {'title': 'AI入門', 'thumbnail_url': null},
          },
        ],
      },
    );

    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('こんにちは、里村 さん'), findsOneWidget);
    expect(find.text('12日連続'), findsOneWidget);
    expect(find.text('AI入門'), findsOneWidget);
    expect(find.text('コースをまだ受講していません'), findsNothing);
  });

  testWidgets('受講中コースが0件なら空状態を表示する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 0},
        'enrollments': (_) => [],
      },
    );

    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('コースをまだ受講していません'), findsOneWidget);
    expect(find.text('0日連続'), findsOneWidget);
  });

  testWidgets('プロフィール未作成でもゲスト表示で落ちない', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => null, // maybeSingle が null を返すケース
        'enrollments': (_) => [],
      },
    );

    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('こんにちは、ゲスト さん'), findsOneWidget);
    expect(find.text('0日連続'), findsOneWidget);
  });

  testWidgets('ログイン中ユーザーのデータだけを取得している', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 1},
        'enrollments': (_) => [],
      },
    );

    await pumpScreen(tester, const DashboardScreen());

    expect(SupabaseHarness.queryTo('/users'), contains('id=eq.$_userId'));

    final enrollmentsQuery = SupabaseHarness.queryTo('/enrollments');
    expect(enrollmentsQuery, contains('user_id=eq.$_userId'));
    expect(enrollmentsQuery, contains('status=eq.active'));
  });

  testWidgets('コース一覧ボタンで /courses へ遷移する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 1},
        'enrollments': (_) => [],
      },
    );

    final router = await pumpScreen(
      tester,
      const DashboardScreen(),
      otherRoutes: {'/courses': 'コース一覧ダミー'},
    );

    await tester.tap(find.text('コース一覧を見る'));
    await settle(tester);

    expect(currentLocation(router), '/courses');
  });

  testWidgets('ログアウトすると /login へ遷移する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 1},
        'enrollments': (_) => [],
      },
    );

    final router = await pumpScreen(
      tester,
      const DashboardScreen(),
      otherRoutes: {'/login': 'ログインダミー'},
    );

    await tester.tap(find.byIcon(Icons.logout));
    await settle(tester);

    expect(currentLocation(router), '/login');
  });
}
