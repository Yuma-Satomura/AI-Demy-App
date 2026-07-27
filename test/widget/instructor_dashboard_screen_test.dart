import 'package:ai_demy_app/features/instructor/screens/instructor_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'instructor-1';

Map<String, dynamic> _course({
  String id = 'course-1',
  String title = 'AI入門',
  bool published = true,
  String priceType = 'one_time',
  Object? priceOneTime = 9800,
  Object? priceMonthly,
}) => {
  'id': id,
  'title': title,
  'is_published': published,
  'price_type': priceType,
  'price_one_time': priceOneTime,
  'price_monthly': priceMonthly,
};

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('自分のコース一覧と公開状態が表示される', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'courses': (_) => [
          _course(title: 'AI入門', published: true),
          _course(id: 'course-2', title: '下書きコース', published: false),
        ],
      },
    );

    await pumpScreen(tester, const InstructorDashboardScreen());

    expect(find.text('講師ダッシュボード'), findsOneWidget);
    expect(find.text('AI入門'), findsOneWidget);
    expect(find.text('下書きコース'), findsOneWidget);
    expect(find.text('公開中'), findsNWidgets(2)); // 統計ラベル + バッジ
    expect(find.text('非公開'), findsOneWidget);
  });

  testWidgets('統計にコース数と公開中の件数を出す', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'courses': (_) => [
          _course(published: true),
          _course(id: 'c2', published: true),
          _course(id: 'c3', published: false),
        ],
      },
    );

    await pumpScreen(tester, const InstructorDashboardScreen());

    expect(find.text('コース数'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 全体
    expect(find.text('2'), findsOneWidget); // 公開中
  });

  testWidgets('コースが0件なら空状態を表示する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {'courses': (_) => []},
    );

    await pumpScreen(tester, const InstructorDashboardScreen());

    expect(find.text('まだコースがありません'), findsOneWidget);
  });

  testWidgets('自分が講師のコースだけを新しい順に取得している', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {'courses': (_) => []},
    );

    await pumpScreen(tester, const InstructorDashboardScreen());

    final query = SupabaseHarness.queryTo('/courses');
    expect(query, contains('instructor_id=eq.$_userId'));
    expect(query, contains('created_at.desc'));
  });

  testWidgets('無料コースは ¥null ではなく無料と表示する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'courses': (_) => [_course(priceType: 'free', priceOneTime: null)],
      },
    );

    await pumpScreen(tester, const InstructorDashboardScreen());

    expect(find.text('無料'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('未ログインならコースを取得せずローディングのまま', (tester) async {
    await initSupabaseForTest(tables: {'courses': (_) => []});

    await pumpScreen(tester, const InstructorDashboardScreen());

    expect(
      SupabaseHarness.requests.any((r) => r.url.path.endsWith('/courses')),
      isFalse,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
