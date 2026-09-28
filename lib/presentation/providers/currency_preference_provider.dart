import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/currency_config.dart';
import '../../data/services/exchange_rate_service.dart';
import '../../data/services/local_preferences_providers.dart';

final currencyPreferenceProvider =
    NotifierProvider<CurrencyPreferenceController, CurrencyConfig>(
      CurrencyPreferenceController.new,
    );

const _prefsKey = 'currency_code';

/// Persists which of [CurrencyConfig.options] the user picked in Settings.
///
/// This is a real, working, persisted preference — but it is scoped to
/// Settings for now. The rest of the app (amount formatting on the
/// dashboard, history, and charts) still formats with
/// [CurrencyConfig.defaultCurrency]; wiring the rest of the app to this
/// preference is left for a future module rather than done silently here.
class CurrencyPreferenceController extends Notifier<CurrencyConfig> {
  @override
  CurrencyConfig build() {
    _restore();
    return CurrencyConfig.defaultCurrency;
  }

  Future<void> _restore() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;
    final restored = CurrencyConfig.options.firstWhere(
      (option) => option.code == stored,
      orElse: () => CurrencyConfig.defaultCurrency,
    );
    if (restored != state) state = restored;
  }

  Future<void> setCurrency(CurrencyConfig currency) async {
    state = currency;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_prefsKey, currency.code);
  }
}

class CurrencyFormatter {
  const CurrencyFormatter(this.config, this.rates);
  final CurrencyConfig config;
  final Map<String, double>? rates;

  String format(num baseAmount) => config.formatConverted(baseAmount, rates);
  double toBaseAmount(double enteredAmount) => config.toBaseAmount(enteredAmount, rates);
  
  double fromBaseAmount(double baseAmount) {
    if (config.code == 'LKR') return baseAmount;
    final rate = rates?[config.code] ?? (config.code == 'LKR' ? 1.0 : _fallbackRate());
    return baseAmount * rate;
  }

  double _fallbackRate() {
    switch (config.code) {
      case 'USD': return 0.003;
      case 'EUR': return 0.0028;
      case 'GBP': return 0.0024;
      case 'INR': return 0.25;
      default: return 1.0;
    }
  }

  String get code => config.code;
}

final currencyFormatterProvider = Provider<CurrencyFormatter>((ref) {
  final config = ref.watch(currencyPreferenceProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  return CurrencyFormatter(config, rates);
});
