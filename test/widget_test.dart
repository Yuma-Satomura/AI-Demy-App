import 'package:ai_demy_app/core/auth/auth_gateway.dart';
import 'package:ai_demy_app/features/auth/screens/login_screen.dart';
import 'package:ai_demy_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ai_demy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_gateway.dart';
import 'helpers/pump_app.dart';
import 'helpers/supabase_harness.dart';

/// アプリ全体（AiDemyApp）が組み上がることを確認するスモークテスト。
void main() {
  tearDown(disposeSupabaseForTest);

  Future<void> pumpApp(WidgetTester tester, {required bool signedIn}) async {
    await initSupabaseForTest(
      signedInUserId: signedIn ? 'user-1' : null,
      tables: {
        'users': (_) => {'display_name': '里村', 'streak_count': 5},
        'enrollments': (_) => [],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authGatewayProvider.overrideWithValue(
            FakeAuthGateway(isSignedIn: signedIn),
          ),
        ],
        child: const AiDemyApp(),
      ),
    );
    await settle(tester);
  }

  testWidgets('未ログインで起動するとログイン画面が出る', (tester) async {
    await pumpApp(tester, signedIn: false);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ログイン済みで起動するとダッシュボードが出る', (tester) async {
    await pumpApp(tester, signedIn: true);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('こんにちは、里村 さん'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ダークテーマが適用されている', (tester) async {
    await pumpApp(tester, signedIn: false);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
