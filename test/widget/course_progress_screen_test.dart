import 'package:ai_demy_app/features/progress/screens/course_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'user-1';
const _courseId = 'course-1';

Future<void> _init({
  int unitCount = 3,
  List<String> completed = const [],
  bool signedIn = true,
}) => initSupabaseForTest(
  signedInUserId: signedIn ? _userId : null,
  tables: {
    'courses': (_) => [
      {'id': _courseId, 'title': 'AI入門'},
    ],
    'curriculum_units': (_) => List.generate(
      unitCount,
      (i) => {'id': 'unit-${i + 1}', 'title': '第${i + 1}章', 'order_index': i + 1},
    ),
    'unit_progress': (_) => completed.map((id) => {'unit_id': id}).toList(),
  },
);

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('進捗率とユニット一覧が表示される', (tester) async {
    await _init(unitCount: 4, completed: ['unit-1', 'unit-2']);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(find.text('AI入門'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('50% 完了'), findsOneWidget);
    expect(find.text('第1章'), findsOneWidget);
    expect(find.text('第4章'), findsOneWidget);
  });

  testWidgets('完了ユニットはチェック、未完了は再生ボタン', (tester) async {
    await _init(unitCount: 3, completed: ['unit-1']);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
  });

  testWidgets('全ユニット完了なら修了バッジを出す', (tester) async {
    await _init(unitCount: 2, completed: ['unit-1', 'unit-2']);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(find.text('100% 完了'), findsOneWidget);
    expect(find.text('修了'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('1つも完了していなければ修了バッジは出ない', (tester) async {
    await _init(unitCount: 2);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(find.text('0% 完了'), findsOneWidget);
    expect(find.text('修了'), findsNothing);
  });

  testWidgets('ユニットが0件でもゼロ除算せずに表示できる', (tester) async {
    await _init(unitCount: 0);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.text('0% 完了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未完了ユニットの再生ボタンで学習画面へ遷移する', (tester) async {
    useTallScreen(tester);
    await _init(unitCount: 2, completed: ['unit-1']);

    final router = await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
      otherRoutes: {'/courses/:courseId/learn/:unitId': '学習画面ダミー'},
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);

    expect(currentLocation(router), '/courses/$_courseId/learn/unit-2');
  });

  testWidgets('自分のこのコースの完了実績だけを取得している', (tester) async {
    await _init();

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    final query = SupabaseHarness.queryTo('/unit_progress');
    expect(query, contains('user_id=eq.$_userId'));
    expect(query, contains('course_id=eq.$_courseId'));
    expect(query, contains('status=eq.completed'));
  });

  testWidgets('未ログインなら取得せずローディングのまま', (tester) async {
    await _init(signedIn: false);

    await pumpScreen(
      tester,
      const CourseProgressScreen(courseId: _courseId),
    );

    expect(SupabaseHarness.requests, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
