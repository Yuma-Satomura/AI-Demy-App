import 'package:ai_demy_app/shared/widgets/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navIndexForLocation', () {
    test('各タブのトップが正しいインデックスを返す', () {
      expect(navIndexForLocation('/dashboard'), 0);
      expect(navIndexForLocation('/courses'), 1);
      expect(navIndexForLocation('/instructor'), 2);
      expect(navIndexForLocation('/btob'), 3);
    });

    test('配下のネストしたパスでも同じタブが選択される', () {
      expect(navIndexForLocation('/courses/abc'), 1);
      expect(navIndexForLocation('/courses/abc/learn/unit-1'), 1);
    });

    test('未知のパスはホームにフォールバックする', () {
      expect(navIndexForLocation('/unknown'), 0);
      expect(navIndexForLocation('/'), 0);
    });

    test('navRoutes のインデックスと対応が一致している', () {
      for (var i = 0; i < navRoutes.length; i++) {
        expect(
          navIndexForLocation(navRoutes[i]),
          i,
          reason: '${navRoutes[i]} は index $i であるべき',
        );
      }
    });
  });
}
