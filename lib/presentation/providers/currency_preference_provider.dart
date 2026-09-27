import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/currency_config.dart';
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
