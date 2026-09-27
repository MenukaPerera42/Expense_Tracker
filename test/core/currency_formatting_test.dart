import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/core/config/currency_config.dart';

void main() {
  group('CurrencyConfig', () {
    test('default currency is LKR with 2 decimal digits', () {
      const defaultCur = CurrencyConfig.defaultCurrency;
      expect(defaultCur.code, 'LKR');
      expect(defaultCur.decimalDigits, 2);
    });

    test(
      'all supported options format amounts with correct symbols and precision',
      () {
        for (final option in CurrencyConfig.options) {
          expect(option.code.isNotEmpty, isTrue);
          expect(option.locale.isNotEmpty, isTrue);
          final formatted = option.format(1234.5);
          expect(formatted, contains(option.code));
        }
      },
    );

    test('formats zero and negative numbers properly', () {
      const usd = CurrencyConfig(code: 'USD', locale: 'en_US');
      expect(usd.format(0), 'USD 0.00');
      expect(usd.format(-45.2), '-USD 45.20');
      expect(usd.format(1000000), 'USD 1,000,000.00');
    });

    test(
      'currencies with 0 decimal digits format integers without decimals',
      () {
        const jpy = CurrencyConfig(
          code: 'JPY',
          locale: 'ja_JP',
          decimalDigits: 0,
        );
        expect(jpy.format(500), 'JPY 500');
      },
    );

    test('equality and hashCode compare code, locale, and decimalDigits', () {
      const c1 = CurrencyConfig(code: 'EUR', locale: 'en_IE', decimalDigits: 2);
      const c2 = CurrencyConfig(code: 'EUR', locale: 'en_IE', decimalDigits: 2);
      const c3 = CurrencyConfig(code: 'EUR', locale: 'fr_FR', decimalDigits: 2);
      const c4 = CurrencyConfig(code: 'EUR', locale: 'en_IE', decimalDigits: 0);

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1, isNot(equals(c3)));
      expect(c1, isNot(equals(c4)));
    });
  });
}
