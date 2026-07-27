/// コース価格の表示文字列を組み立てる。
///
/// - `subscription` → `¥1980/月`
/// - それ以外（`one_time` 等） → `¥9800`
/// - 価格が未設定、または `price_type` が `free` → `無料`
String formatCoursePrice({
  String? priceType,
  Object? priceMonthly,
  Object? priceOneTime,
}) {
  if (priceType == 'free') return '無料';

  if (priceType == 'subscription') {
    return priceMonthly == null ? '無料' : '¥$priceMonthly/月';
  }
  return priceOneTime == null ? '無料' : '¥$priceOneTime';
}

/// `courses` テーブルの 1 行から価格表示を組み立てるショートハンド。
String formatCoursePriceFromRow(Map<String, dynamic> course) =>
    formatCoursePrice(
      priceType: course['price_type'] as String?,
      priceMonthly: course['price_monthly'],
      priceOneTime: course['price_one_time'],
    );
