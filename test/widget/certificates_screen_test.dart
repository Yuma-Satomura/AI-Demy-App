import 'package:ai_demy_app/features/certificates/screens/certificates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'user-1';

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('修了証のコース名・スコア・発行日が表示される', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'completion_certs': (_) => [
          {
            'id': 'cert-1',
            'issued_at': '2026-03-15T10:00:00Z',
            'score': 92,
            'courses': {'title': 'AI入門'},
          },
        ],
      },
    );

    await pumpScreen(tester, const CertificatesScreen());

    expect(find.text('修了証明書'), findsOneWidget);
    expect(find.text('AI入門'), findsOneWidget);
    expect(find.text('スコア: 92点'), findsOneWidget);
    expect(find.textContaining('2026年3月15日'), findsOneWidget);
    expect(find.text('修了'), findsOneWidget);
  });

  testWidgets('スコアがない証明書ではスコア行を出さない', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'completion_certs': (_) => [
          {
            'id': 'cert-1',
            'issued_at': '2026-03-15T10:00:00Z',
            'score': null,
            'courses': {'title': 'AI入門'},
          },
        ],
      },
    );

    await pumpScreen(tester, const CertificatesScreen());

    expect(find.textContaining('スコア'), findsNothing);
    expect(find.text('AI入門'), findsOneWidget);
  });

  testWidgets('発行日が不正な文字列でも落ちずにそのまま表示する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {
        'completion_certs': (_) => [
          {
            'id': 'cert-1',
            'issued_at': 'not-a-date',
            'score': 80,
            'courses': {'title': 'AI入門'},
          },
        ],
      },
    );

    await pumpScreen(tester, const CertificatesScreen());

    expect(find.text('not-a-date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('証明書が0件なら案内を表示する', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {'completion_certs': (_) => []},
    );

    await pumpScreen(tester, const CertificatesScreen());

    expect(find.text('まだ証明書がありません'), findsOneWidget);
    expect(find.text('コースを修了すると証明書が発行されます'), findsOneWidget);
  });

  testWidgets('自分の証明書を新しい順に取得している', (tester) async {
    await initSupabaseForTest(
      signedInUserId: _userId,
      tables: {'completion_certs': (_) => []},
    );

    await pumpScreen(tester, const CertificatesScreen());

    final query = SupabaseHarness.queryTo('/completion_certs');
    expect(query, contains('user_id=eq.$_userId'));
    expect(query, contains('issued_at.desc'));
  });

  testWidgets('未ログインなら取得せずローディングのまま', (tester) async {
    await initSupabaseForTest(tables: {'completion_certs': (_) => []});

    await pumpScreen(tester, const CertificatesScreen());

    expect(SupabaseHarness.requests, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
