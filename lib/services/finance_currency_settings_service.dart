import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_settings_service.dart';

class FinanceCurrencySettingsService {
  const FinanceCurrencySettingsService._();

  static const String _selectedCurrencyCodeKey = 'selected_finance_currency_code';
  static CurrencyOption _selectedOption = CurrencySettingsService.optionForCode(
    CurrencySettingsService.defaultCurrencyCode,
  );
  static final ValueNotifier<int> _changeCounter = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    _selectedOption = await getSelectedCurrency();
  }

  static CurrencyOption get currentCurrency => _selectedOption;
  static ValueListenable<int> get changes => _changeCounter;

  static Future<CurrencyOption> getSelectedCurrency() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCode = preferences.getString(_selectedCurrencyCodeKey);
    return CurrencySettingsService.optionForCode(storedCode);
  }

  static Future<void> setSelectedCurrencyCode(String code) async {
    final selectedOption = CurrencySettingsService.optionForCode(code);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedCurrencyCodeKey, selectedOption.code);
    _selectedOption = selectedOption;
    _changeCounter.value++;
  }
}
