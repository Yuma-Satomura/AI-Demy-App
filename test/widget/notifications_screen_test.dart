import 'package:ai_demy_app/features/notifications/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'user-1';

Map<String, dynamic> _notification({
  String id = 'n1',
  String type = 'thread_reply',
  String title = '返信がありました',
  String? body = '本文',
  bool isRead = false,
  String createdAt = '2026-07-27T00:00:00Z',
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': body,
  'link': null,
  'is_read': isRead,
  'created_at': createdAt,
};

Future<void> _init({
  List<Map<String, dynamic>>? notifications,
  bool signedIn = true,
}) => initSupabaseForTest(
  signedInUserId: signedIn ? _userId : null,
  tables: {
    'notifications': (_) => notifications ?? [_notification()],
  },
);

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('通知のタイトル・本文・種別アイコンが表示される', (tester) async {
    await _init(
      notifications: [
        _notification(title: '返信がありました', body: 'コメントが付きました'),
        _notification(
          id: 'n2',
          type: 'cert_issued',
          title: '修了証が発行されました',
          body: null,
        ),
      ],
    );

    await pumpScreen(tester, const NotificationsScreen());

    expect(find.text('通知'), findsOneWidget);
    expect(find.text('返信がありました'), findsOneWidget);
    expect(find.text('コメントが付きました'), findsOneWidget);
    expect(find.text('修了証が発行されました'), findsOneWidget);
    expect(find.text('💬'), findsOneWidget);
    expect(find.text('🎓'), findsOneWidget);
  });

  testWidgets('未知の種別は既定のアイコンになる', (tester) async {
    await _init(notifications: [_notification(type: 'unknown_type')]);

    await pumpScreen(tester, const NotificationsScreen());

    expect(find.text('🔔'), findsOneWidget);
  });

  testWidgets('通知が0件なら案内を表示する', (tester) async {
    await _init(notifications: []);

    await pumpScreen(tester, const NotificationsScreen());

    expect(find.text('通知はありません'), findsOneWidget);
  });

  testWidgets('作成日時が不正でも落ちない', (tester) async {
    await _init(notifications: [_notification(createdAt: 'not-a-date')]);

    await pumpScreen(tester, const NotificationsScreen());

    expect(find.text('返信がありました'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('表示時に未読を既読へ更新する', (tester) async {
    await _init();

    await pumpScreen(tester, const NotificationsScreen());

    final patch = SupabaseHarness.requests.firstWhere(
      (r) => r.method == 'PATCH' && r.url.path.endsWith('/notifications'),
    );
    expect(patch.body, contains('"is_read":true'));
    expect(
      Uri.decodeQueryComponent(patch.url.query),
      contains('user_id=eq.$_userId'),
    );
    expect(
      Uri.decodeQueryComponent(patch.url.query),
      contains('is_read=eq.false'),
    );
  });

  testWidgets('自分の通知を新しい順に取得している', (tester) async {
    await _init(notifications: []);

    await pumpScreen(tester, const NotificationsScreen());

    final get = SupabaseHarness.requests.firstWhere(
      (r) => r.method == 'GET' && r.url.path.endsWith('/notifications'),
    );
    final query = Uri.decodeQueryComponent(get.url.query);
    expect(query, contains('user_id=eq.$_userId'));
    expect(query, contains('created_at.desc'));
  });

  testWidgets('未ログインなら取得せずローディングのまま', (tester) async {
    await _init(signedIn: false);

    await pumpScreen(tester, const NotificationsScreen());

    expect(SupabaseHarness.requests, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
