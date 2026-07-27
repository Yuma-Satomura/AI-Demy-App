import 'package:ai_demy_app/features/courses/screens/courses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

Map<String, dynamic> _course({
  String id = 'course-1',
  String title = 'AI入門',
  String instructor = '山田先生',
  String priceType = 'one_time',
  Object? priceOneTime = 9800,
  Object? priceMonthly,
}) => {
  'id': id,
  'title': title,
  'description': '説明',
  'thumbnail_url': null,
  'price_type': priceType,
  'price_one_time': priceOneTime,
  'price_monthly': priceMonthly,
  'users': {'display_name': instructor},
};

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('取得したコースが一覧に表示される', (tester) async {
    await initSupabaseForTest(
      tables: {
        'courses': (_) => [
          _course(title: 'AI入門', instructor: '山田先生'),
          _course(
            id: 'course-2',
            title: '機械学習実践',
            instructor: '佐藤先生',
            priceType: 'subscription',
            priceOneTime: null,
            priceMonthly: 2980,
          ),
        ],
      },
    );

    await pumpScreen(tester, const CoursesScreen());

    expect(find.text('AI入門'), findsOneWidget);
    expect(find.text('山田先生'), findsOneWidget);
    expect(find.text('¥9800'), findsOneWidget);

    expect(find.text('機械学習実践'), findsOneWidget);
    expect(find.text('¥2980/月'), findsOneWidget);

    // ロードが終わればスピナーは消えている
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('0件なら空状態のメッセージを出す', (tester) async {
    await initSupabaseForTest(tables: {'courses': (_) => []});

    await pumpScreen(tester, const CoursesScreen());

    expect(find.text('コースが見つかりません'), findsOneWidget);
  });

  testWidgets('公開済みコースだけを問い合わせている', (tester) async {
    await initSupabaseForTest(tables: {'courses': (_) => []});

    await pumpScreen(tester, const CoursesScreen());

    expect(
      SupabaseHarness.queryTo('/courses'),
      contains('is_published=eq.true'),
    );
  });

  testWidgets('検索文字を入力すると title の部分一致で再取得する', (tester) async {
    await initSupabaseForTest(tables: {'courses': (_) => []});

    await pumpScreen(tester, const CoursesScreen());
    SupabaseHarness.requests.clear();

    await tester.enterText(find.byType(TextField), '機械学習');
    await settle(tester);

    expect(SupabaseHarness.queryTo('/courses'), contains('title=ilike.%機械学習%'));
  });

  testWidgets('コースカードをタップすると詳細へ遷移する', (tester) async {
    await initSupabaseForTest(
      tables: {
        'courses': (_) => [_course(id: 'course-42', title: 'AI入門')],
      },
    );

    final router = await pumpScreen(
      tester,
      const CoursesScreen(),
      otherRoutes: {'/courses/:courseId': 'コース詳細ダミー'},
    );

    await tester.tap(find.text('AI入門'));
    await settle(tester);

    expect(currentLocation(router), '/courses/course-42');
    expect(find.text('コース詳細ダミー'), findsOneWidget);
  });
}
