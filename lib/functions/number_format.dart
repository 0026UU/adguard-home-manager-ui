import 'package:intl/intl.dart';

String intFormat(int value, String locale) {
  final f = NumberFormat("#,###", locale);
  return f.format(value);
}

String doubleFormat(double value, String locale) {
  final f = NumberFormat("#.##", locale);
  return f.format(value);
}

/// Abbreviated count, for the tiles of a dashboard where the number has to
/// stay on one line: 18432 -> "18K", or "1.8万" in Chinese.
String compactFormat(num value, String locale) {
  return NumberFormat.compact(locale: locale).format(value);
}

/// Share of something, told with the one decimal the design layer uses:
/// a block rate of 35.648 is "35.6", a day-over-day change is "6.2".
String percentFormat(num value, String locale) {
  final f = NumberFormat("#.#", locale);
  return f.format(value);
}

/// The same share rounded to whole numbers, which is all a ring can show
/// inside its 58 pixel circle.
String wholePercentFormat(num value, String locale) {
  final f = NumberFormat("0", locale);
  return f.format(value);
}

/// A size the server sent in bytes, told in the unit a person reads it in:
/// 4194304 is "4 MB". The step stops as soon as the value fits its unit, so a
/// 65536 byte cache says "64 KB" rather than rounding away to "0 MB".
String bytesFormat(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;

  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }

  return '${doubleFormat(value, locale)} ${units[unit]}';
}
