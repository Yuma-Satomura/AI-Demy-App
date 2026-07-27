# テストガイド

## 実行方法

```bash
flutter test                      # 全テスト
flutter test test/unit            # ユニットテストのみ
flutter test test/widget/courses_screen_test.dart   # ファイル単位
flutter test --coverage           # カバレッジ出力（coverage/lcov.info）
flutter analyze                   # 静的解析
```

CI（`.github/workflows/flutter-ci.yml`）は main への push / PR で
`flutter analyze` と `flutter test --coverage` を実行する。

## ディレクトリ構成

| パス | 内容 |
|---|---|
| `test/unit/` | 純粋関数のユニットテスト（Flutter に依存しない） |
| `test/widget/` | 画面単位のウィジェットテスト |
| `test/router/` | ルーティング・認証リダイレクトのテスト |
| `test/widget_test.dart` | アプリ全体のスモークテスト |
| `test/helpers/` | テスト共通のヘルパー |
| `test/flutter_test_config.dart` | 全テスト共通の前処理（GoogleFonts のネットワーク取得を無効化） |

## Supabase をどう扱っているか

各画面は `Supabase.instance.client` を直接呼ぶため、テストでも Supabase の
初期化が必要になる。`test/helpers/supabase_harness.dart` が
**ネットワークに一切出ない Supabase** を組み立てる。

- HTTP 層を `MockClient` に差し替え、`/rest/v1/<テーブル>` へのリクエストに
  テストが指定した JSON を返す
- 認証状態は `signedInUserId` で決める（実際のログインは走らない）
- 端末ストレージ（shared_preferences / secure_storage）には触らない

```dart
void main() {
  tearDown(disposeSupabaseForTest);   // 各テスト後に必ず破棄する

  testWidgets('コースが一覧表示される', (tester) async {
    await initSupabaseForTest(
      signedInUserId: 'user-1',
      tables: {
        'courses': (_) => [
          {'id': 'c1', 'title': 'AI入門', 'price_type': 'free'},
        ],
      },
    );

    await pumpScreen(tester, const CoursesScreen());

    expect(find.text('AI入門'), findsOneWidget);
  });
}
```

### 応答の書き方

- `.select()`（複数行）→ `List<Map>` を返す
- `.single()` / `.maybeSingle()` → `Map` を返す。行数が 1 でなければ
  本番同様 406 を返すので、`single()` は例外、`maybeSingle()` は null になる
- 1件だけの `List` は複数行クエリ・単一行クエリのどちらにも使える
- 登録していないテーブルを叩くと 500 になり、`SupabaseHarness.unhandledPaths`
  に記録される（フェイク応答の登録漏れに気付けるようにするため）

### 発行されたクエリの検証

```dart
expect(SupabaseHarness.queryTo('/courses'), contains('is_published=eq.true'));
expect(SupabaseHarness.requestTo('/token').body, contains('"test@example.com"'));
```

### ログインの成否を切り替える

```dart
// 既定は「認証失敗」
await initSupabaseForTest();

// 成功させたい場合
await initSupabaseForTest(
  auth: (req) => signInSuccessResponse(req, userId: 'user-1'),
);
```

## ヘルパー（`test/helpers/pump_app.dart`）

| 関数 | 用途 |
|---|---|
| `pumpScreen(tester, screen, otherRoutes: {...})` | 1画面をテーマ + ルーター付きでマウント。`otherRoutes` に遷移先のダミーを登録できる |
| `pumpRouter(tester, router)` | 任意の `GoRouter` をマウント |
| `pumpAppRouter(tester, overrides: [...])` | アプリ本体の `routerProvider` でマウント |
| `currentLocation(router)` | 現在のパスを取得 |
| `settle(tester)` | 非同期ロードの完了待ち |

`pumpAndSettle` は使わない。ローディング中の `CircularProgressIndicator` が
回り続けてタイムアウトするため、代わりに `settle(tester)` で
固定回数フレームを進める。

## 認証リダイレクトのテスト

ルーターの認証判定は `AuthGateway`（`lib/core/auth/auth_gateway.dart`）を
経由しているので、Provider を差し替えるだけでログイン状態を作れる。

```dart
final router = await pumpAppRouter(
  tester,
  overrides: [
    authGatewayProvider.overrideWithValue(FakeAuthGateway(isSignedIn: false)),
  ],
);
expect(currentLocation(router), '/login');
```

## テストを足すときの注意

- 画面が新しいテーブルを参照するようになったら、`tables` への登録も足すこと
  （未登録だと 500 になり、原因が分かりにくい失敗になる）
- `tearDown(disposeSupabaseForTest)` を忘れない。Supabase はシングルトンなので
  破棄しないと次のテストへ状態が漏れる
