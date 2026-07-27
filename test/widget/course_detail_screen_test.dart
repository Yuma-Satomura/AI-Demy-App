import 'dart:convert';

import 'package:ai_demy_app/core/network/app_http_client.dart';
import 'package:ai_demy_app/features/courses/screens/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

/// 自社 Web API（/api/mobile/...）のフェイク。
/// [responses] はパス末尾 → 返す JSON（と HTTP ステータス）。
void fakeApi(
  Map<String, ({int status, Object? body})> responses, {
  List<http.Request>? recorder,
}) {
  appHttpClient = MockClient((request) async {
    recorder?.add(request);
    final key = responses.keys.firstWhere(
      (k) => request.url.path.endsWith(k),
      orElse: () => '',
    );
    final res = responses[key];
    if (res == null) {
      return http.Response('{"error":"未登録: ${request.url.path}"}', 500);
    }
    return http.Response(
      jsonEncode(res.body),
      res.status,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  addTearDown(resetAppHttpClient);
}

/// url_launcher を差し替え、開かれた URL を記録する。
List<String> fakeUrlLauncher() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <String>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'canLaunch':
            return true;
          case 'launch':
            launched.add(call.arguments['url'] as String);
            return true;
        }
        return null;
      });

  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return launched;
}

Future<void> _tapPurchase(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, '受講する'));
  await settle(tester);
}

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

  group('受講手続き', () {
    testWidgets('無料コースは即座に受講済みになる', (tester) async {
      await _init(enrolled: false);
      fakeApi({
        '/api/mobile/payment-intent': (status: 200, body: {'type': 'free'}),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(find.widgetWithText(ElevatedButton, '学習を続ける'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '受講する'), findsNothing);
    });

    testWidgets('すでに登録済みの応答でも受講済みになる', (tester) async {
      await _init(enrolled: false);
      fakeApi({
        '/api/mobile/payment-intent': (status: 200, body: {'type': 'enrolled'}),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(find.widgetWithText(ElevatedButton, '学習を続ける'), findsOneWidget);
    });

    testWidgets('コースIDと認証トークンを付けて決済APIを呼ぶ', (tester) async {
      await _init(enrolled: false);
      final requests = <http.Request>[];
      fakeApi({
        '/api/mobile/payment-intent': (status: 200, body: {'type': 'free'}),
      }, recorder: requests);

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.body, contains('"courseId":"$_courseId"'));
      expect(req.headers['Authorization'], startsWith('Bearer '));
    });

    testWidgets('サブスクは Checkout の URL を外部ブラウザで開く', (tester) async {
      await _init(enrolled: false);
      final launched = fakeUrlLauncher();
      fakeApi({
        '/api/mobile/payment-intent': (
          status: 200,
          body: {
            'type': 'subscription',
            'url': 'https://checkout.stripe.com/c/pay/test',
          },
        ),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(launched, ['https://checkout.stripe.com/c/pay/test']);
      // 決済はブラウザ側で続くので、この時点では受講済みにしない
      expect(find.widgetWithText(ElevatedButton, '受講する'), findsOneWidget);
    });

    testWidgets('サブスクの URL が不正なら何も開かない', (tester) async {
      await _init(enrolled: false);
      final launched = fakeUrlLauncher();
      fakeApi({
        '/api/mobile/payment-intent': (
          status: 200,
          body: {'type': 'subscription', 'url': null},
        ),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(launched, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('APIがエラーを返すとエラーを通知して受講済みにしない', (tester) async {
      await _init(enrolled: false);
      fakeApi({
        '/api/mobile/payment-intent': (status: 500, body: {'error': 'boom'}),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(find.text('受講登録に失敗しました (500)'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '受講する'), findsOneWidget);
    });

    testWidgets('通信自体が失敗してもエラー通知だけで落ちない', (tester) async {
      await _init(enrolled: false);
      appHttpClient = MockClient(
        (_) => throw http.ClientException('接続できません'),
      );
      addTearDown(resetAppHttpClient);

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(find.text('エラーが発生しました'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('処理が終われば購入ボタンは操作可能に戻る', (tester) async {
      await _init(enrolled: false);
      fakeApi({
        '/api/mobile/payment-intent': (status: 500, body: {'error': 'boom'}),
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '受講する'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('未ログインなら決済APIを呼ばない', (tester) async {
      await _init(signedIn: false);
      final requests = <http.Request>[];
      fakeApi({
        '/api/mobile/payment-intent': (status: 200, body: {'type': 'free'}),
      }, recorder: requests);

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await _tapPurchase(tester);

      expect(requests, isEmpty);
    });
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
