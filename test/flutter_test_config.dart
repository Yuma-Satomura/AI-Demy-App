import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// `test/` 配下のすべてのテストが起動する前に一度だけ実行される。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppTheme は GoogleFonts を使う。テスト中にフォントを
  // ネットワーク取得しに行かないよう無効化する（バンドル済みフォントのみ使用）。
  GoogleFonts.config.allowRuntimeFetching = false;

  await testMain();
}
