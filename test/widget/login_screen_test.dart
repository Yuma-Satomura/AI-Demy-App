import 'package:ai_demy_app/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

Future<void> _fillCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
  await tester.enterText(find.byType(TextField).at(1), 'password123');
}

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('メール・パスワード入力欄とログインボタンが表示される', (tester) async {
    await initSupabaseForTest();
    await pumpScreen(tester, const LoginScreen());

    expect(find.text('AI-Demy'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'メールアドレス'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'パスワード'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'ログイン'), findsOneWidget);
  });

  testWidgets('認証に失敗するとエラーメッセージを表示し、画面に留まる', (tester) async {
    await initSupabaseForTest(); // 既定の auth 応答は 400 invalid credentials

    final router = await pumpScreen(
      tester,
      const LoginScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await _fillCredentials(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'ログイン'));
    await settle(tester);

    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(currentLocation(router), '/');
  });

  testWidgets('ログインに成功すると /dashboard へ遷移する', (tester) async {
    await initSupabaseForTest(
      auth: (req) => req.url.path.endsWith('/token')
          ? signInSuccessResponse(req, userId: 'user-1')
          : invalidCredentialsResponse(req),
    );

    final router = await pumpScreen(
      tester,
      const LoginScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await _fillCredentials(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'ログイン'));
    await settle(tester);

    expect(currentLocation(router), '/dashboard');
    expect(find.text('ダッシュボードダミー'), findsOneWidget);
  });

  testWidgets('メールアドレスは前後の空白を落として送信する', (tester) async {
    await initSupabaseForTest(
      auth: (req) => signInSuccessResponse(req, userId: 'user-1'),
    );

    await pumpScreen(
      tester,
      const LoginScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      '  test@example.com  ',
    );
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'ログイン'));
    await settle(tester);

    expect(
      SupabaseHarness.requestTo('/token').body,
      contains('"test@example.com"'),
    );
  });

  testWidgets('アカウント作成リンクで /register へ遷移する', (tester) async {
    await initSupabaseForTest();

    final router = await pumpScreen(
      tester,
      const LoginScreen(),
      otherRoutes: {'/register': '新規登録ダミー'},
    );

    await tester.tap(find.text('アカウントを作成する'));
    await settle(tester);

    expect(currentLocation(router), '/register');
  });
}
