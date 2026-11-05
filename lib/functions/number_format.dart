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
