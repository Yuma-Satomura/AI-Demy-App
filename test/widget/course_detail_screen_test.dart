import 'package:ai_demy_app/features/courses/screens/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _courseId = 'course-1';

Map<String, dynamic> _course({
  String priceType = 'one_time',
  Object? priceOneTime = 9800,
  Object? priceMonthly,
}) => {
  'id': _courseId,
  'title': 'AI入門',
  'description': 'AIの基礎を学ぶコース',
  'price_type': priceType,
  'price_one_time': priceOneTime,
  'price_monthly': priceMonthly,
  'users': {'display_name': '山田先生', 'avatar_url': null},
};

List<Map<String, dynamic>> _units() => [
  {'id': 'unit-1', 'title': '第1章 AIとは', 'order_index': 1, 'difficulty': 'beginner'},
  {'id': 'unit-2', 'title': '第2章 機械学習', 'order_index': 2, 'difficulty': 'beginner'},
];

Future<void> _init({
  bool signedIn = true,
  bool enrolled = false,
  Map<String, dynamic>? course,
  List<Map<String, dynamic>>? units,
}) => initSupabaseForTest(
  signedInUserId: signedIn ? 'user-1' : null,
  tables: {
    'courses': (_) => [course ?? _course()],
    'curriculum_units': (_) => units ?? _units(),
    'enrollments': (_) => enrolled ? [
        {'id': 'enr-1'},
      ] : [],
  },
);

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('コース情報・講師名・カリキュラムが表示される', (tester) async {
    await _init();

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.text('AI入門'), findsNWidgets(2)); // AppBar と本文見出し
    expect(find.text('山田先生'), findsOneWidget);
    expect(find.text('AIの基礎を学ぶコース'), findsOneWidget);
    expect(find.text('カリキュラム'), findsOneWidget);
    expect(find.text('第1章 AIとは'), findsOneWidget);
    expect(find.text('第2章 機械学習'), findsOneWidget);
  });

  testWidgets('未受講なら価格と受講ボタン、ユニットは鍵アイコン', (tester) async {
    await _init(enrolled: false);

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.text('¥9800'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '受講する'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('受講済みなら「学習を続ける」と再生ボタンが出る', (tester) async {
    await _init(enrolled: true);

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.widgetWithText(ElevatedButton, '学習を続ける'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('「学習を続ける」で最初のユニットの学習画面へ遷移する', (tester) async {
    await _init(enrolled: true);

    final router = await pumpScreen(
      tester,
      const CourseDetailScreen(courseId: _courseId),
      otherRoutes: {'/courses/:courseId/learn/:unitId': '学習画面ダミー'},
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '学習を続ける'));
    await settle(tester);

    expect(currentLocation(router), '/courses/$_courseId/learn/unit-1');
  });

  testWidgets('ユニットの再生ボタンでそのユニットへ遷移する', (tester) async {
    useTallScreen(tester); // 2つ目のユニットが下部バーに隠れないようにする
    await _init(enrolled: true);

    final router = await pumpScreen(
      tester,
      const CourseDetailScreen(courseId: _courseId),
      otherRoutes: {'/courses/:courseId/learn/:unitId': '学習画面ダミー'},
    );

    final unit2Play = find.descendant(
      of: find.widgetWithText(ListTile, '第2章 機械学習'),
      matching: find.byIcon(Icons.play_arrow),
    );
    await tester.tap(unit2Play);
    await settle(tester);

    expect(currentLocation(router), '/courses/$_courseId/learn/unit-2');
  });

  testWidgets('サブスクコースは月額表示になる', (tester) async {
    await _init(
      course: _course(
        priceType: 'subscription',
        priceOneTime: null,
        priceMonthly: 2980,
      ),
    );

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.text('¥2980/月'), findsOneWidget);
  });

  testWidgets('無料コースは ¥null ではなく無料と表示する', (tester) async {
    await _init(
      course: _course(priceType: 'free', priceOneTime: null),
    );

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.text('無料'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('ユニットが0件ならカリキュラム見出しを出さない', (tester) async {
    await _init(units: []);

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(find.text('カリキュラム'), findsNothing);
  });

  testWidgets('未ログインなら受講状態の問い合わせをしない', (tester) async {
    await _init(signedIn: false);

    await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));

    expect(
      SupabaseHarness.requests.any((r) => r.url.path.endsWith('/enrollments')),
      isFalse,
    );
    expect(find.widgetWithText(ElevatedButton, '受講する'), findsOneWidget);
  });
}
