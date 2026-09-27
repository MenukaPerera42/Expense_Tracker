import 'package:intl/intl.dart';

/// A single currency per installation until user preferences are introduced.
class CurrencyConfig {
  const CurrencyConfig({
    this.code = 'LKR',
    this.locale = 'en_LK',
    this.decimalDigits = 2,
  });

  static const defaultCurrency = CurrencyConfig();

  /// Selectable currencies for the Settings screen's currency preference.
  /// The preference is persisted, but nothing outside Settings reads it yet;
  /// the rest of the app still formats amounts with [defaultCurrency].
  static const options = [
    CurrencyConfig(),
    CurrencyConfig(code: 'USD', locale: 'en_US'),
    CurrencyConfig(code: 'EUR', locale: 'en_IE'),
    CurrencyConfig(code: 'GBP', locale: 'en_GB'),
    CurrencyConfig(code: 'INR', locale: 'en_IN'),
  ];

  final String code;
  final String locale;
  final int decimalDigits;

  String format(num amount) => NumberFormat.currency(
    locale: locale,
    name: code,
    symbol: '$code ',
    decimalDigits: decimalDigits,
  ).format(amount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrencyConfig &&
          other.code == code &&
          other.locale == locale &&
          other.decimalDigits == decimalDigits);

  @override
  int get hashCode => Object.hash(code, locale, decimalDigits);
}
