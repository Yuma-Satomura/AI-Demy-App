import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 認証状態の参照口。
///
/// ルーターのリダイレクト判定が Supabase のグローバルシングルトンに
/// 直接依存しないよう、この層を挟んでいる。テストでは
/// [authGatewayProvider] を override して差し替える。
abstract class AuthGateway {
  bool get isSignedIn;
}

class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();

  @override
  bool get isSignedIn => Supabase.instance.client.auth.currentUser != null;
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const SupabaseAuthGateway(),
);
