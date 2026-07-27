import 'package:ai_demy_app/core/utils/price_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCoursePrice', () {
    test('サブスクは月額表示になる', () {
      expect(
        formatCoursePrice(priceType: 'subscription', priceMonthly: 1980),
        '¥1980/月',
      );
    });

    test('買い切りは一括金額を表示する', () {
      expect(
        formatCoursePrice(priceType: 'one_time', priceOneTime: 9800),
        '¥9800',
      );
    });

    test('price_type が free なら金額が入っていても無料表示', () {
      expect(
        formatCoursePrice(
          priceType: 'free',
          priceMonthly: 1980,
          priceOneTime: 9800,
        ),
        '無料',
      );
    });

    test('サブスクなのに月額が null なら無料表示（¥null を出さない）', () {
      expect(
        formatCoursePrice(priceType: 'subscription', priceMonthly: null),
        '無料',
      );
    });

    test('買い切りなのに金額が null なら無料表示（¥null を出さない）', () {
      expect(
        formatCoursePrice(priceType: 'one_time', priceOneTime: null),
        '無料',
      );
    });

    test('price_type 自体が null でも落ちない', () {
      expect(formatCoursePrice(), '無料');
      expect(formatCoursePrice(priceOneTime: 500), '¥500');
    });
  });

  group('formatCoursePriceFromRow', () {
    test('courses テーブルの行から価格を組み立てる', () {
      expect(
        formatCoursePriceFromRow({
          'price_type': 'subscription',
          'price_monthly': 2980,
          'price_one_time': null,
        }),
        '¥2980/月',
      );
    });

    test('キーが欠けた行でも落ちない', () {
      expect(formatCoursePriceFromRow({'title': 'テストコース'}), '無料');
    });
  });
}
