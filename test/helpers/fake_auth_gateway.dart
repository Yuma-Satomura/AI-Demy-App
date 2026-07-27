import 'package:ai_demy_app/core/auth/auth_gateway.dart';

/// ルーターのリダイレクト判定をテストから制御するためのフェイク。
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.isSignedIn = false});

  @override
  bool isSignedIn;
}
