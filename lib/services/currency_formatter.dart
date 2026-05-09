import 'currency_settings_service.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static String formatAmount(
    double value, {
    bool useCode = false,
    bool includeCode = false,
    String? currencyCode,
  }) {
    final currency = CurrencySettingsService.optionForCode(
      currencyCode ?? CurrencySettingsService.currentCurrency.code,
    );
    final amount = value.toStringAsFixed(2);

    if (useCode || currency.symbol.trim().isEmpty) {
      return '${currency.code} $amount';
    }

    if (includeCode) {
      return '${currency.symbol}$amount ${currency.code}';
    }

    return '${currency.symbol}$amount';
  }

  static String currencyHint({String? currencyCode}) {
    final currency = CurrencySettingsService.optionForCode(
      currencyCode ?? CurrencySettingsService.currentCurrency.code,
    );
    if (currency.symbol.trim().isEmpty) {
      return '${currency.code} 0.00';
    }

    return '${currency.symbol} 0.00';
  }

  static String formatEditableAmount(double value, {String? currencyCode}) {
    return value.toStringAsFixed(2);
  }

  static double parseEnteredAmount(String rawValue, {String? currencyCode}) {
    return double.tryParse(rawValue.trim()) ?? 0;
  }
}