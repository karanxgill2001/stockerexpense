import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class BackendConfigService {
  const BackendConfigService._();

  static const String _stockGoogleScriptUrlKey = 'google_script_url_override';

  static Future<String> getStockGoogleScriptUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final overrideUrl =
        preferences.getString(_stockGoogleScriptUrlKey)?.trim() ?? '';
    if (overrideUrl.isNotEmpty) {
      return overrideUrl;
    }

    return AppConfig.defaultStockGoogleScriptUrl.trim();
  }

  static Future<String> getCredentialsGoogleScriptUrl() async {
    return AppConfig.defaultCredentialsGoogleScriptUrl.trim();
  }

  static Future<String?> getOverrideStockGoogleScriptUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_stockGoogleScriptUrlKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  static Future<bool> hasStockGoogleScriptUrl() async {
    final url = await getStockGoogleScriptUrl();
    return url.trim().isNotEmpty;
  }

  static Future<void> setStockGoogleScriptUrl(String url) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_stockGoogleScriptUrlKey, url.trim());
  }

  static Future<void> clearStockGoogleScriptUrlOverride() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_stockGoogleScriptUrlKey);
  }


  static Future<String> getGoogleScriptUrl() => getStockGoogleScriptUrl();

  static Future<String?> getOverrideGoogleScriptUrl() =>
      getOverrideStockGoogleScriptUrl();

  static Future<void> setGoogleScriptUrl(String url) =>
      setStockGoogleScriptUrl(url);

  static Future<void> clearGoogleScriptUrlOverride() =>
      clearStockGoogleScriptUrlOverride();
}
