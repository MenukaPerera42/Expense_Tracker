import 'package:intl/intl.dart';

/// A single currency per installation until user preferences are introduced.
class CurrencyConfig {
  const CurrencyConfig({
    this.code = 'LKR',
    this.locale = 'en_LK',
    this.decimalDigits = 2,
  });

  static const defaultCurrency = CurrencyConfig();

  final String code;
  final String locale;
  final int decimalDigits;

  String format(num amount) => NumberFormat.currency(
    locale: locale,
    name: code,
    symbol: '$code ',
    decimalDigits: decimalDigits,
  ).format(amount);
}
