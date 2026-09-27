import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default currency formats grouping, precision, zero and negatives', () {
    const currency = CurrencyConfig.defaultCurrency;
    expect(currency.format(1234.5), 'LKR 1,234.50');
    expect(currency.format(0), 'LKR 0.00');
    expect(currency.format(-12.5), '-LKR 12.50');
    expect(currency.format(12.346), 'LKR 12.35');
  });

  test('currency and precision can change centrally', () {
    const currency = CurrencyConfig(
      code: 'JPY',
      locale: 'en_US',
      decimalDigits: 0,
    );
    expect(currency.format(1234), 'JPY 1,234');
  });
}
