import 'dart:convert';

import 'package:ai_demy_app/core/network/app_http_client.dart';
import 'package:ai_demy_app/features/learn/screens/learn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _courseId = 'course-1';
const _unitId = 'unit-1';

Future<void> _init({List<Map<String, dynamic>> messages = const []}) =>
    initSupabaseForTest(
      signedInUserId: 'user-1',
      tables: {
        'curriculum_units': (_) => {
          'title': '第1章 AIとは',
          'difficulty': 'beginner',
        },
        'chat_messages': (_) => messages,
      },
    );

/// AIチャット API（/api/mobile/ai-chat）のフェイク。
List<http.Request> fakeAiChat({Object? body, int status = 200}) {
  final requests = <http.Request>[];
  appHttpClient = MockClient((req) async {
    requests.add(req);
    return http.Response(
      jsonEncode(body),
      status,
      request: req,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  addTearDown(resetAppHttpClient);
  return requests;
}

Future<void> _openChatTab(WidgetTester tester) async {
  await tester.tap(find.text('AIチャット'));
  // タブ切り替えアニメーション（既定 300ms）が終わるまで待つ
  await settle(tester, frames: 25);
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.tap(find.byIcon(Icons.send));
  await settle(tester);
}

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('ユニット名と2つのタブが表示される', (tester) async {
    await _init();

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );

    expect(find.text('第1章 AIとは'), findsOneWidget);
    expect(find.text('コンテンツ'), findsOneWidget);
    expect(find.text('AIチャット'), findsOneWidget);
    expect(find.text('コンテンツを選択してください'), findsOneWidget);
  });

  testWidgets('保存済みの会話履歴を表示する', (tester) async {
    await _init(
      messages: [
        {'role': 'user', 'content': 'AIとは何ですか', 'created_at': '2026-01-01'},
        {
          'role': 'assistant',
          'content': '人工知能のことです',
          'created_at': '2026-01-01',
        },
      ],
    );

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);

    expect(find.text('AIとは何ですか'), findsOneWidget);
    expect(find.text('人工知能のことです'), findsOneWidget);
  });

  testWidgets('履歴が空ならプレースホルダを出す', (tester) async {
    await _init();

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);

    expect(find.text('AIに質問してみましょう'), findsOneWidget);
  });

  testWidgets('このユニットの履歴だけを取得している', (tester) async {
    await _init();

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );

    expect(
      SupabaseHarness.queryTo('/chat_messages'),
      contains('unit_id=eq.$_unitId'),
    );
    expect(
      SupabaseHarness.queryTo('/curriculum_units'),
      contains('id=eq.$_unitId'),
    );
  });

  testWidgets('メッセージを送るとAIの返答が追加される', (tester) async {
    await _init();
    fakeAiChat(body: {'content': 'AIとは人工知能です'});

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, 'AIとは？');

    expect(find.text('AIとは？'), findsOneWidget);
    expect(find.text('AIとは人工知能です'), findsOneWidget);
  });

  testWidgets('courseId / unitId / message と認証トークンを送っている', (tester) async {
    await _init();
    final requests = fakeAiChat(body: {'content': '回答'});

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, 'テスト質問');

    final req = requests.single;
    expect(req.url.path, endsWith('/api/mobile/ai-chat'));
    expect(req.headers['Authorization'], startsWith('Bearer '));
    expect(req.body, contains('"courseId":"$_courseId"'));
    expect(req.body, contains('"unitId":"$_unitId"'));
    expect(req.body, contains('"message":"テスト質問"'));
  });

  testWidgets('直前までの会話を history として送る', (tester) async {
    await _init(
      messages: [
        {'role': 'user', 'content': '前の質問', 'created_at': '2026-01-01'},
        {'role': 'assistant', 'content': '前の回答', 'created_at': '2026-01-01'},
      ],
    );
    final requests = fakeAiChat(body: {'content': '新しい回答'});

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, '新しい質問');

    final body = requests.single.body;
    expect(body, contains('"前の質問"'));
    expect(body, contains('"前の回答"'));
    // 送信中のメッセージ自体は history に含めない
    expect(body, isNot(contains('"content":"新しい質問"}]')));
  });

  testWidgets('APIがエラーを返してもエラー文言を出して落ちない', (tester) async {
    await _init();
    fakeAiChat(body: {'error': 'Not enrolled'}, status: 403);

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, '失敗するはずの質問');

    expect(find.text('失敗するはずの質問'), findsOneWidget);
    expect(find.text('エラーが発生しました。再度お試しください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通信自体が失敗しても落ちない', (tester) async {
    await _init();
    appHttpClient = MockClient(
      (_) => throw http.ClientException('接続できません'),
    );
    addTearDown(resetAppHttpClient);

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, '質問');

    expect(find.text('エラーが発生しました。再度お試しください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('応答に content がなければ代替文言を出す', (tester) async {
    await _init();
    fakeAiChat(body: {'unexpected': true});

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, '質問');

    expect(find.text('応答を取得できませんでした'), findsOneWidget);
  });

  testWidgets('空文字は送信しない', (tester) async {
    await _init();
    final requests = fakeAiChat(body: {'content': '返答'});

    await pumpScreen(
      tester,
      const LearnScreen(courseId: _courseId, unitId: _unitId),
    );
    await _openChatTab(tester);
    await _send(tester, '   ');

    expect(find.text('AIに質問してみましょう'), findsOneWidget);
    expect(requests, isEmpty);
  });
}
