import '../models/finance_entry.dart';
import 'currency_formatter.dart';
import 'currency_settings_service.dart';
import 'finance_currency_settings_service.dart';

class FinanceCurrencyFormatter {
  const FinanceCurrencyFormatter._();

  static String formatAmount(
    double value, {
    bool useCode = false,
    bool includeCode = false,
  }) {
    return CurrencyFormatter.formatAmount(
      value,
      useCode: useCode,
      includeCode: includeCode,
      currencyCode: FinanceCurrencySettingsService.currentCurrency.code,
    );
  }

  static String currencyHint({String? currencyCode}) {
    return CurrencyFormatter.currencyHint(
      currencyCode:
          currencyCode ?? FinanceCurrencySettingsService.currentCurrency.code,
    );
  }

  static double parseEnteredAmount(String rawValue, {String? currencyCode}) {
    return CurrencyFormatter.parseEnteredAmount(
      rawValue,
      currencyCode:
          currencyCode ?? FinanceCurrencySettingsService.currentCurrency.code,
    );
  }

  static String formatStoredEntryAmount(
    FinanceEntry entry, {
    bool useCode = false,
    bool includeCode = true,
  }) {
    return formatDisplayAmount(
      entry.displayAmount,
      currencyCode: entry.currencyCode,
      useCode: useCode,
      includeCode: includeCode,
    );
  }

  static String formatDisplayAmount(
    double amount, {
    required String currencyCode,
    bool useCode = false,
    bool includeCode = false,
  }) {
    final currency = CurrencySettingsService.optionForCode(currencyCode);
    final fixedAmount = amount.toStringAsFixed(2);

    if (useCode || currency.symbol.trim().isEmpty) {
      return '${currency.code} $fixedAmount';
    }

    if (includeCode) {
      return '${currency.symbol}$fixedAmount ${currency.code}';
    }

    return '${currency.symbol}$fixedAmount';
  }
}
