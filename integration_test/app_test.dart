// 実機 / エミュレータ上で走らせる統合テスト。
//
// `flutter test`（widget テスト）は fake-async で動くため、Stripe など
// ネイティブプラグインのメソッドチャネルが完了せず検証できない。
// ここではそれらを実際に動かして確認する。
//
// 実行:
//   flutter test integration_test/app_test.dart -d <device>
//
// ネットワークには出ない。Supabase / 自社API はいずれもフェイクに差し替える。

import 'dart:convert';

import 'package:ai_demy_app/core/auth/auth_gateway.dart';
import 'package:ai_demy_app/core/network/app_http_client.dart';
import 'package:ai_demy_app/features/courses/screens/course_detail_screen.dart';
import 'package:ai_demy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_auth_gateway.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/supabase_harness.dart';

const _courseId = 'course-1';
const _unitId = 'unit-1';

/// 実機では実 I/O の完了を待つ必要があるため、条件が満たされるまで待つ。
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('${timeout.inSeconds}秒待っても見つかりませんでした: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(disposeSupabaseForTest);

  group('Stripe ネイティブ決済', () {
    Future<void> initCourse() => initSupabaseForTest(
      signedInUserId: 'user-1',
      tables: {
        'courses': (_) => [
          {
            'id': _courseId,
            'title': 'AI入門',
            'description': '説明',
            'price_type': 'one_time',
            'price_one_time': 9800,
            'price_monthly': null,
            'users': {'display_name': '山田先生', 'avatar_url': null},
          },
        ],
        'curriculum_units': (_) => [
          {
            'id': _unitId,
            'title': '第1章',
            'order_index': 1,
            'difficulty': 'beginner',
          },
        ],
        'enrollments': (_) => [],
      },
    );

    void fakeApi(Object? body, {int status = 200}) {
      appHttpClient = MockClient(
        (req) async => http.Response(
          jsonEncode(body),
          status,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      addTearDown(resetAppHttpClient);
    }

    // Stripe の publishable key は設定していないため、決済シートの起動は
    // 必ず失敗する。ここで確認したいのは「ネイティブ呼び出しに到達し、
    // 失敗してもアプリが落ちずエラー通知で終わる」こと。
    // 決済成功まで通すには pk_test_ キーとテスト用 clientSecret が必要。
    testWidgets('一括払いはネイティブ決済に進み、失敗しても落ちない', (tester) async {
      await initCourse();
      fakeApi({
        'type': 'one_time',
        'clientSecret': 'pi_test_123_secret_abc',
        'ephemeralKey': 'ek_test_123',
        'customerId': 'cus_test_123',
      });

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await waitFor(tester, find.widgetWithText(ElevatedButton, '受講する'));

      await tester.tap(find.widgetWithText(ElevatedButton, '受講する'));

      await waitFor(tester, find.byType(SnackBar));
      expect(tester.takeException(), isNull);

      // 決済が完了していない以上、受講済みにはならない
      expect(find.widgetWithText(ElevatedButton, '学習を続ける'), findsNothing);
    });

    testWidgets('無料コースはネイティブ決済を経ずに受講済みになる', (tester) async {
      await initCourse();
      fakeApi({'type': 'free'});

      await pumpScreen(tester, const CourseDetailScreen(courseId: _courseId));
      await waitFor(tester, find.widgetWithText(ElevatedButton, '受講する'));

      await tester.tap(find.widgetWithText(ElevatedButton, '受講する'));

      await waitFor(tester, find.widgetWithText(ElevatedButton, '学習を続ける'));
    });
  });

  group('アプリ起動', () {
    testWidgets('実機でアプリ全体が描画される', (tester) async {
      await initSupabaseForTest(
        signedInUserId: 'user-1',
        tables: {
          'users': (_) => {'display_name': '里村', 'streak_count': 5},
          'enrollments': (_) => [],
          'notifications': (_) => [],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authGatewayProvider.overrideWithValue(
              FakeAuthGateway(isSignedIn: true),
            ),
          ],
          child: const AiDemyApp(),
        ),
      );

      await waitFor(tester, find.text('こんにちは、里村 さん'));
      expect(tester.takeException(), isNull);
    });
  });
}
