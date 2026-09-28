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

  /// Format a base amount (in LKR) into this currency, using the provided exchange rates.
  String formatConverted(num baseAmount, Map<String, double>? rates) {
    final rate = rates?[code] ?? (code == 'LKR' ? 1.0 : _fallbackRate());
    final convertedAmount = baseAmount * rate;
    return format(convertedAmount);
  }

  /// Convert an entered amount in this currency back to the base currency (LKR).
  double toBaseAmount(double enteredAmount, Map<String, double>? rates) {
    final rate = rates?[code] ?? (code == 'LKR' ? 1.0 : _fallbackRate());
    if (rate == 0) return enteredAmount;
    return enteredAmount / rate;
  }

  double _fallbackRate() {
    switch (code) {
      case 'USD':
        return 0.003;
      case 'EUR':
        return 0.0028;
      case 'GBP':
        return 0.0024;
      case 'INR':
        return 0.25;
      default:
        return 1.0;
    }
  }

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
