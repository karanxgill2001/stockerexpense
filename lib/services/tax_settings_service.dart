import 'package:shared_preferences/shared_preferences.dart';

import 'google_sheet_service.dart';

class TaxSettingsService {
  const TaxSettingsService._();

  static const String _taxPercentageKey = 'tax_percentage';

  static Future<double> getTaxPercentage() async {
    return getStoredTaxPercentage();
  }

  static Future<double> getStoredTaxPercentage() async {
    final preferences = await SharedPreferences.getInstance();
    return _sanitizePercentage(preferences.getDouble(_taxPercentageKey) ?? 0);
  }

  static Future<double> syncTaxPercentageFromServer() async {
    try {
      final value = _sanitizePercentage(
        await GoogleSheetService.instance.fetchTaxPercentage(),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_taxPercentageKey, value);
      return value;
    } catch (_) {
      return getStoredTaxPercentage();
    }
  }

  static Future<void> setTaxPercentage(double value) async {
    final sanitized = _sanitizePercentage(value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_taxPercentageKey, sanitized);
    await GoogleSheetService.instance.updateTaxPercentage(sanitized);
  }

  static double _sanitizePercentage(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }

    return value.clamp(0, 100).toDouble();
  }
}
