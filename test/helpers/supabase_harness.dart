import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// テスト用の Supabase 初期化ヘルパー。
///
/// 本物のネットワークには一切出ない。PostgREST へのリクエストは
/// [tables] に登録したフェイク応答で返し、認証状態は [signedInUserId] で決める。
///
/// 使い方:
/// ```dart
/// setUp(() async {
///   await initSupabaseForTest(
///     signedInUserId: 'user-1',
///     tables: {'courses': (req) => [ {...} ]},
///   );
/// });
/// tearDown(disposeSupabaseForTest);
/// ```
class SupabaseHarness {
  SupabaseHarness._();

  /// テスト中に実際に飛んだリクエストの記録（クエリ・ボディ検証用）。
  static final List<http.Request> requests = [];

  /// 指定パスで終わる最初のリクエストを取り出す。
  static http.Request requestTo(String pathSuffix) => requests.firstWhere(
    (r) => r.url.path.endsWith(pathSuffix),
    orElse: () => throw StateError(
      '$pathSuffix へのリクエストがありません。実際: '
      '${requests.map((r) => r.url.path).toList()}',
    ),
  );

  /// 指定パスで終わる最初のリクエストのクエリ文字列（デコード済み）。
  static String queryTo(String pathSuffix) =>
      Uri.decodeQueryComponent(requestTo(pathSuffix).url.query);

  /// 未登録のテーブルにアクセスした場合に投げられた例外の記録。
  static final List<String> unhandledPaths = [];
}

/// PostgREST の 1 テーブルに対するフェイク応答を組み立てるコールバック。
/// 戻り値は JSON エンコード可能な値（通常は `List<Map>` か `Map`）。
typedef TableResponder = Object? Function(http.Request request);

/// `/auth/v1/*` へのリクエストに対するフェイク応答。
typedef AuthResponder = http.Response Function(http.Request request);

/// Edge Function 1つに対するフェイク応答を組み立てるコールバック。
/// 例外を投げると呼び出し側では FunctionsException になる。
typedef FunctionResponder = Object? Function(http.Request request);

const testSupabaseUrl = 'https://test.supabase.co';

// 署名検証はされないが、Session.expiresAt の算出で JWT としてパースされるため
// 形だけ有効なトークンを渡す（exp = 2099-01-01）。
const _fakeAccessToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiJ0ZXN0Iiwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJleHAiOjQwNzA5MDg4MDB9.'
    'c2lnbmF0dXJlLW5vdC12ZXJpZmllZA';

/// テスト用に Supabase を初期化する。
///
/// [tables] のキーは `/rest/v1/<table>` のテーブル名。値はそのテーブルへの
/// リクエストに対して返す JSON。未登録のテーブルを叩いた場合は 500 を返し、
/// [SupabaseHarness.unhandledPaths] に記録する（テストの見落とし防止）。
Future<void> initSupabaseForTest({
  String? signedInUserId,
  Map<String, TableResponder> tables = const {},
  Map<String, FunctionResponder> functions = const {},
  AuthResponder? auth,
  MockClient? httpClient,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SupabaseHarness.requests.clear();
  SupabaseHarness.unhandledPaths.clear();

  final client = httpClient ?? _mockClientFor(tables, functions, auth);

  await Supabase.initialize(
    url: testSupabaseUrl,
    publishableKey: 'test-anon-key',
    httpClient: client,
    debug: false,
    // 端末ストレージ（shared_preferences / secure_storage）に触らせない。
    authOptions: FlutterAuthClientOptions(
      localStorage: const EmptyLocalStorage(),
      pkceAsyncStorage: _InMemoryAsyncStorage(),
      autoRefreshToken: false,
      detectSessionInUri: false,
    ),
  );

  if (signedInUserId != null) {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode(fakeSessionJson(userId: signedInUserId)),
    );
  }
}

/// 各テスト後に必ず呼ぶ。シングルトンが残るとテスト間で状態が漏れる。
Future<void> disposeSupabaseForTest() async {
  await Supabase.instance.dispose();
}

/// gotrue が受け付ける最小限のセッション JSON。
Map<String, dynamic> fakeSessionJson({
  required String userId,
  String email = 'test@example.com',
}) => {
  'access_token': _fakeAccessToken,
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'fake-refresh-token',
  'user': {
    'id': userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-01-01T00:00:00Z',
  },
};

/// ログイン失敗（認証情報が不正）を模した応答。
http.Response invalidCredentialsResponse(
  http.Request request, {
  String message = 'Invalid login credentials',
}) => _response(
  {'error': 'invalid_grant', 'error_description': message, 'message': message},
  request,
  status: 400,
);

/// ログイン成功を模した応答。
http.Response signInSuccessResponse(
  http.Request request, {
  required String userId,
}) => _response(fakeSessionJson(userId: userId), request);

MockClient _mockClientFor(
  Map<String, TableResponder> tables,
  Map<String, FunctionResponder> functions,
  AuthResponder? auth,
) {
  return MockClient((request) async {
    SupabaseHarness.requests.add(request);
    final path = request.url.path;

    if (path.startsWith('/rest/v1/')) {
      final table = path.substring('/rest/v1/'.length);
      final responder = tables[table];
      if (responder == null) {
        SupabaseHarness.unhandledPaths.add(path);
        return _response(
          {'message': 'テストで未登録のテーブルにアクセスしました: $table'},
          request,
          status: 500,
        );
      }
      return _json(responder(request), request);
    }

    if (path.startsWith('/functions/v1/')) {
      final name = path.substring('/functions/v1/'.length);
      final responder = functions[name];
      if (responder == null) {
        SupabaseHarness.unhandledPaths.add(path);
        return _response(
          {'message': 'テストで未登録の Edge Function を呼びました: $name'},
          request,
          status: 500,
        );
      }
      return _response(responder(request), request);
    }

    if (path.startsWith('/auth/v1/')) {
      if (auth != null) return auth(request);
      // 既定はログイン失敗。成功パスを検証したいテストは [auth] を渡す。
      if (path.endsWith('/token')) return invalidCredentialsResponse(request);
      return _json(<String, dynamic>{}, request);
    }

    SupabaseHarness.unhandledPaths.add(path);
    return _response(
      {'message': 'unexpected request: $path'},
      request,
      status: 500,
    );
  });
}

http.Response _json(Object? body, http.Request request) {
  // PostgREST の `.single()` / `.maybeSingle()` は
  // Accept: application/vnd.pgrst.object+json を送り、ちょうど 1 行を期待する。
  // 行数が合わなければ本番同様 406 を返す
  // （`single()` は例外、`maybeSingle()` は null になる）。
  final wantsSingleObject = (request.headers['Accept'] ?? '').contains(
    'vnd.pgrst.object',
  );

  if (!wantsSingleObject) return _response(body, request);

  final rows = body == null
      ? const []
      : body is List
      ? body
      : [body];

  if (rows.length != 1) return _notASingleRowResponse(request, rows.length);
  return _response(rows.first, request);
}

http.Response _notASingleRowResponse(http.Request request, int rowCount) =>
    _response(
      {
        'code': 'PGRST116',
        'details':
            'Results contain $rowCount rows, '
            'application/vnd.pgrst.object+json requires 1 row',
        'hint': null,
        'message': 'JSON object requested, multiple (or no) rows returned',
      },
      request,
      status: 406,
    );

/// postgrest / gotrue は `response.request` を参照するため、
/// MockClient に返す Response には必ず元のリクエストを載せる。
http.Response _response(
  Object? body,
  http.Request request, {
  int status = 200,
}) {
  return http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _store.remove(key);
  }
}
