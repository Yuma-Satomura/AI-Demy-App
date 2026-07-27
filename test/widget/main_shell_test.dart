import 'package:ai_demy_app/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump_app.dart';

/// MainShell だけを検証するため、配下の画面はダミーに差し替える。
GoRouter _shellRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        for (final route in navRoutes)
          GoRoute(
            path: route,
            builder: (_, _) =>
                Scaffold(body: Center(child: Text('$route の中身'))),
          ),
        GoRoute(
          path: '/courses/:courseId',
          builder: (_, state) => Scaffold(
            body: Center(child: Text('詳細 ${state.pathParameters['courseId']}')),
          ),
        ),
      ],
    ),
  ],
);

BottomNavigationBar _bottomNav(WidgetTester tester) =>
    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

void main() {
  testWidgets('4つのタブが並び、子ウィジェットが表示される', (tester) async {
    await pumpRouter(tester, _shellRouter(initialLocation: '/dashboard'));

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('コース'), findsOneWidget);
    expect(find.text('講師'), findsOneWidget);
    expect(find.text('BtoB'), findsOneWidget);
    expect(find.text('/dashboard の中身'), findsOneWidget);
  });

  testWidgets('現在地に対応するタブがハイライトされる', (tester) async {
    await pumpRouter(tester, _shellRouter(initialLocation: '/instructor'));

    expect(_bottomNav(tester).currentIndex, 2);
  });

  testWidgets('コース詳細のようなネストしたパスでもコースタブが選択されたまま', (tester) async {
    await pumpRouter(tester, _shellRouter(initialLocation: '/courses/abc'));

    expect(_bottomNav(tester).currentIndex, 1);
    expect(find.text('詳細 abc'), findsOneWidget);
  });

  testWidgets('タブをタップすると対応するルートへ遷移する', (tester) async {
    final router = _shellRouter(initialLocation: '/dashboard');
    await pumpRouter(tester, router);

    await tester.tap(find.text('コース'));
    await settle(tester);
    expect(currentLocation(router), '/courses');
    expect(_bottomNav(tester).currentIndex, 1);

    await tester.tap(find.text('BtoB'));
    await settle(tester);
    expect(currentLocation(router), '/btob');
    expect(_bottomNav(tester).currentIndex, 3);

    await tester.tap(find.text('ホーム'));
    await settle(tester);
    expect(currentLocation(router), '/dashboard');
    expect(_bottomNav(tester).currentIndex, 0);
  });
}
