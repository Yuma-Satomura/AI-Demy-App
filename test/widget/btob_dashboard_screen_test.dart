import 'package:ai_demy_app/features/btob/screens/btob_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/supabase_harness.dart';

const _userId = 'user-1';
const _tenantId = 'tenant-1';

Future<void> _init({
  Object? tenantId = _tenantId,
  Map<String, dynamic>? tenant,
  int employees = 0,
  int assignments = 0,
}) => initSupabaseForTest(
  signedInUserId: _userId,
  tables: {
    'users': (_) => {'tenant_id': tenantId, 'role': 'btob_admin'},
    'tenants': (_) =>
        tenant ??
        {'name': '株式会社テスト', 'plan': 'standard', 'max_seats': 50},
    'employees': (_) =>
        List.generate(employees, (i) => {'id': 'emp-$i'}),
    'course_assignments': (_) =>
        List.generate(assignments, (i) => {'id': 'asg-$i'}),
  },
);

void main() {
  tearDown(disposeSupabaseForTest);

  testWidgets('テナント名・プラン・統計・クイックアクションが表示される', (tester) async {
    await _init(employees: 12, assignments: 4);

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(find.text('株式会社テスト'), findsNWidgets(2)); // AppBar とプランカード
    expect(find.text('プラン: スタンダード'), findsOneWidget);
    expect(find.text('12 / 50'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('社員管理'), findsOneWidget);
    expect(find.text('コース割当'), findsOneWidget);

    // 残りは画面外にあるのでスクロールして確認する
    // （統計の GridView も Scrollable なので、対象を ListView に明示する）
    await tester.dragUntilVisible(
      find.text('HR連携'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    expect(find.text('レポート'), findsOneWidget);
    expect(find.text('HR連携'), findsOneWidget);
  });

  testWidgets('プランコードは日本語ラベルに変換される', (tester) async {
    await _init(
      tenant: {'name': '大企業', 'plan': 'enterprise', 'max_seats': 1000},
    );

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(find.text('プラン: エンタープライズ'), findsOneWidget);
  });

  testWidgets('未知のプランコードはそのまま表示する', (tester) async {
    await _init(tenant: {'name': '試験', 'plan': 'trial', 'max_seats': 5});

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(find.text('プラン: trial'), findsOneWidget);
  });

  testWidgets('テナント未所属なら案内メッセージを出す', (tester) async {
    await _init(tenantId: null);

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(find.text('テナントに所属していません'), findsOneWidget);
    // テナント未所属なら以降の問い合わせはしない
    expect(
      SupabaseHarness.requests.any((r) => r.url.path.endsWith('/tenants')),
      isFalse,
    );
  });

  testWidgets('社員・割当コースは所属テナントで絞り込んでいる', (tester) async {
    await _init(employees: 1, assignments: 1);

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(
      SupabaseHarness.queryTo('/employees'),
      contains('tenant_id=eq.$_tenantId'),
    );
    expect(
      SupabaseHarness.queryTo('/course_assignments'),
      contains('tenant_id=eq.$_tenantId'),
    );
  });

  testWidgets('未ログインならローディングのまま何も取得しない', (tester) async {
    await initSupabaseForTest(tables: {'users': (_) => null});

    await pumpScreen(tester, const BtobDashboardScreen());

    expect(SupabaseHarness.requests, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
