import 'package:ai_demy_app/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

Future<void> _fillForm(WidgetTester tester, {String name = '里村'}) async {
  await tester.enterText(find.byType(TextField).at(0), name);
  await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
  await tester.enterText(find.byType(TextField).at(2), 'password123');
}

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('表示名・メール・パスワードの入力欄がある', (tester) async {
    await initSupabaseForTest();
    await pumpScreen(tester, const RegisterScreen());

    expect(find.text('新規登録'), findsOneWidget);
    expect(find.widgetWithText(TextField, '表示名'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'メールアドレス'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'パスワード'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'アカウント作成'), findsOneWidget);
  });

  testWidgets('登録に成功すると /dashboard へ遷移する', (tester) async {
    await initSupabaseForTest(
      auth: (req) => signInSuccessResponse(req, userId: 'user-1'),
    );

    final router = await pumpScreen(
      tester,
      const RegisterScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await _fillForm(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'アカウント作成'));
    await settle(tester);

    expect(currentLocation(router), '/dashboard');
  });

  testWidgets('表示名は user_metadata として送信される', (tester) async {
    await initSupabaseForTest(
      auth: (req) => signInSuccessResponse(req, userId: 'user-1'),
    );

    await pumpScreen(
      tester,
      const RegisterScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await _fillForm(tester, name: '  里村  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'アカウント作成'));
    await settle(tester);

    final body = SupabaseHarness.requestTo('/signup').body;
    expect(body, contains('"display_name":"里村"')); // 前後の空白は落ちる
    expect(body, contains('"test@example.com"'));
  });

  testWidgets('登録に失敗するとエラーメッセージを表示し、画面に留まる', (tester) async {
    await initSupabaseForTest(
      auth: (req) => invalidCredentialsResponse(
        req,
        message: 'User already registered',
      ),
    );

    final router = await pumpScreen(
      tester,
      const RegisterScreen(),
      otherRoutes: {'/dashboard': 'ダッシュボードダミー'},
    );

    await _fillForm(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'アカウント作成'));
    await settle(tester);

    expect(find.text('User already registered'), findsOneWidget);
    expect(currentLocation(router), '/');
  });

  testWidgets('ログインリンクで /login へ遷移する', (tester) async {
    await initSupabaseForTest();

    final router = await pumpScreen(
      tester,
      const RegisterScreen(),
      otherRoutes: {'/login': 'ログインダミー'},
    );

    await tester.tap(find.text('ログインはこちら'));
    await settle(tester);

    expect(currentLocation(router), '/login');
  });
}
