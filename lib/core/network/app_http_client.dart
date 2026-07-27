import 'package:http/http.dart' as http;

/// 自社 Web API（`kApiBaseUrl`）への通信に使う HTTP クライアント。
///
/// Supabase 経由ではない直接の HTTP 呼び出しは必ずこれを通す。
/// テストではフェイクに差し替える（差し替えたら必ず [resetAppHttpClient] で戻すこと）。
http.Client appHttpClient = http.Client();

/// テスト用。既定のクライアントに戻す。
void resetAppHttpClient() {
  appHttpClient = http.Client();
}
