import 'package:ai_demy_app/core/router/app_router.dart';
import 'package:ai_demy_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 単一の画面を、アプリのテーマ + GoRouter 付きでマウントする。
///
/// 画面が `context.go()` を呼ぶため最小限のルーターが必要になる。
/// 遷移先を検証したい場合は [otherRoutes] にダミー画面を登録する。
/// 戻り値の [GoRouter] を [currentLocation] に渡すと遷移先を検証できる。
Future<GoRouter> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String path = '/',
  Map<String, String> otherRoutes = const {},
  List<Override> overrides = const [],
}) async {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (_, _) => screen),
      for (final entry in otherRoutes.entries)
        GoRoute(
          path: entry.key,
          builder: (_, _) => Scaffold(body: Center(child: Text(entry.value))),
        ),
    ],
  );

  await pumpRouter(tester, router, overrides: overrides);
  return router;
}

/// 任意の [GoRouter] をアプリのテーマ付きでマウントする。
Future<void> pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await settle(tester);
}

/// アプリ本体のルーター（[routerProvider]）でマウントする。
Future<GoRouter> pumpAppRouter(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await settle(tester);
  return router;
}

/// 画面が今どのパスにいるかを返す。
String currentLocation(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// 非同期ロードの完了を待つ。
///
/// `pumpAndSettle` は CircularProgressIndicator が回り続けるとタイムアウトするため、
/// 固定回数だけフレームを進める。
Future<void> settle(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
