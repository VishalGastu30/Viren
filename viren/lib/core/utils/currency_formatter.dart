import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrFormatterWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats double to ₹ 1,25,000
  static String format(double value, {bool showDecimals = false}) {
    if (showDecimals) {
      return _inrFormatterWithDecimals.format(value);
    }
    return _inrFormatter.format(value);
  }

  /// Formats percentage, defaults to +12.5% or -4.2%
  static String formatPercentage(double value) {
    String prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  static String formatCompact(double value) {
     final NumberFormat compactFormatter = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );
     return compactFormatter.format(value);
  }
}
