import 'package:intl/intl.dart' as intl;

class NumberFormat {
  static final _adcFormat = intl.NumberFormat('#,###');
  static final _weightFormat = intl.NumberFormat('0.00');
  static final _densityFormat = intl.NumberFormat('0.00');
  static final _percentFormat = intl.NumberFormat('0.0');

  /// Formats ADC value with commas: 21847 → "21,847"
  static String formatADC(int value) => _adcFormat.format(value);

  /// Formats ADC value from double: 21847.0 → "21,847"
  static String formatADCDouble(double value) => _adcFormat.format(value.toInt());

  /// Formats weight in grams: 12.3456 → "12.35"
  static String formatWeight(double value) => _weightFormat.format(value);

  /// Formats density: 19.32 → "19.32"
  static String formatDensity(double value) => _densityFormat.format(value);

  /// Formats percentage: 75.0 → "75.0"
  static String formatPercent(double value) => _percentFormat.format(value);

  /// Formats ADC range: "21,300 – 22,900"
  static String formatADCRange(double min, double max) =>
      '${_adcFormat.format(min.toInt())} – ${_adcFormat.format(max.toInt())}';
}
