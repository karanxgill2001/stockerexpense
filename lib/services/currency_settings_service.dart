import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  String get summary {
    if (symbol.isEmpty) {
      return '$name ($code)';
    }

    return '$name ($code $symbol)';
  }
}

class CurrencySettingsService {
  const CurrencySettingsService._();

  static const String _selectedCurrencyCodeKey = 'selected_currency_code';
  static const String _cachedRatesKey = 'cached_currency_rates';
  static const String _ratesUpdatedAtKey = 'cached_currency_rates_updated_at';
  static const String _cachedPreferredRatesKey =
      'cached_preferred_currency_rates';
  static const String defaultCurrencyCode = 'USD';
  static final ValueNotifier<int> _changeCounter = ValueNotifier<int>(0);
  static final http.Client _httpClient = http.Client();
  static const String _latestUsdRatesUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String _yahooUsdPairUrlPrefix =
      'https://query1.finance.yahoo.com/v8/finance/chart/USD';

  static const List<CurrencyOption> options = [
    CurrencyOption(code: 'AED', name: 'UAE Dirham', symbol: 'AED'),
    CurrencyOption(code: 'AFN', name: 'Afghan Afghani', symbol: 'AFN'),
    CurrencyOption(code: 'ALL', name: 'Albanian Lek', symbol: 'ALL'),
    CurrencyOption(code: 'AMD', name: 'Armenian Dram', symbol: 'AMD'),
    CurrencyOption(code: 'ANG', name: 'Netherlands Antillean Guilder', symbol: 'ANG'),
    CurrencyOption(code: 'AOA', name: 'Angolan Kwanza', symbol: 'Kz'),
    CurrencyOption(code: 'ARS', name: 'Argentine Peso', symbol: 'ARS'),
    CurrencyOption(code: 'AUD', name: 'Australian Dollar', symbol: r'$'),
    CurrencyOption(code: 'AWG', name: 'Aruban Florin', symbol: 'AWG'),
    CurrencyOption(code: 'AZN', name: 'Azerbaijani Manat', symbol: 'AZN'),
    CurrencyOption(code: 'BAM', name: 'Bosnia and Herzegovina Convertible Mark', symbol: 'BAM'),
    CurrencyOption(code: 'BBD', name: 'Barbadian Dollar', symbol: r'$'),
    CurrencyOption(code: 'BDT', name: 'Bangladeshi Taka', symbol: 'Tk'),
    CurrencyOption(code: 'BGN', name: 'Bulgarian Lev', symbol: 'BGN'),
    CurrencyOption(code: 'BHD', name: 'Bahraini Dinar', symbol: 'BHD'),
    CurrencyOption(code: 'BIF', name: 'Burundian Franc', symbol: 'BIF'),
    CurrencyOption(code: 'BMD', name: 'Bermudan Dollar', symbol: r'$'),
    CurrencyOption(code: 'BND', name: 'Brunei Dollar', symbol: r'$'),
    CurrencyOption(code: 'BOB', name: 'Bolivian Boliviano', symbol: 'Bs'),
    CurrencyOption(code: 'BRL', name: 'Brazilian Real', symbol: r'R$'),
    CurrencyOption(code: 'BSD', name: 'Bahamian Dollar', symbol: r'$'),
    CurrencyOption(code: 'BTN', name: 'Bhutanese Ngultrum', symbol: 'Nu'),
    CurrencyOption(code: 'BWP', name: 'Botswanan Pula', symbol: 'P'),
    CurrencyOption(code: 'BYN', name: 'Belarusian Ruble', symbol: 'BYN'),
    CurrencyOption(code: 'BZD', name: 'Belize Dollar', symbol: r'BZ$'),
    CurrencyOption(code: 'CAD', name: 'Canadian Dollar', symbol: r'C$'),
    CurrencyOption(code: 'CDF', name: 'Congolese Franc', symbol: 'CDF'),
    CurrencyOption(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
    CurrencyOption(code: 'CLP', name: 'Chilean Peso', symbol: 'CLP'),
    CurrencyOption(code: 'CNY', name: 'Chinese Yuan', symbol: 'CNY'),
    CurrencyOption(code: 'COP', name: 'Colombian Peso', symbol: 'COP'),
    CurrencyOption(code: 'CRC', name: 'Costa Rican Colon', symbol: 'CRC'),
    CurrencyOption(code: 'CUP', name: 'Cuban Peso', symbol: 'CUP'),
    CurrencyOption(code: 'CVE', name: 'Cape Verdean Escudo', symbol: 'CVE'),
    CurrencyOption(code: 'CZK', name: 'Czech Koruna', symbol: 'CZK'),
    CurrencyOption(code: 'DJF', name: 'Djiboutian Franc', symbol: 'DJF'),
    CurrencyOption(code: 'DKK', name: 'Danish Krone', symbol: 'DKK'),
    CurrencyOption(code: 'DOP', name: 'Dominican Peso', symbol: 'DOP'),
    CurrencyOption(code: 'DZD', name: 'Algerian Dinar', symbol: 'DZD'),
    CurrencyOption(code: 'EGP', name: 'Egyptian Pound', symbol: 'EGP'),
    CurrencyOption(code: 'ERN', name: 'Eritrean Nakfa', symbol: 'ERN'),
    CurrencyOption(code: 'ETB', name: 'Ethiopian Birr', symbol: 'Br'),
    CurrencyOption(code: 'EUR', name: 'Euro', symbol: 'EUR'),
    CurrencyOption(code: 'FJD', name: 'Fijian Dollar', symbol: r'FJ$'),
    CurrencyOption(code: 'FKP', name: 'Falkland Islands Pound', symbol: 'FKP'),
    CurrencyOption(code: 'GBP', name: 'British Pound Sterling', symbol: 'GBP'),
    CurrencyOption(code: 'GEL', name: 'Georgian Lari', symbol: 'GEL'),
    CurrencyOption(code: 'GGP', name: 'Guernsey Pound', symbol: 'GGP'),
    CurrencyOption(code: 'GHS', name: 'Ghanaian Cedi', symbol: 'GHS'),
    CurrencyOption(code: 'GIP', name: 'Gibraltar Pound', symbol: 'GIP'),
    CurrencyOption(code: 'GMD', name: 'Gambian Dalasi', symbol: 'D'),
    CurrencyOption(code: 'GNF', name: 'Guinean Franc', symbol: 'GNF'),
    CurrencyOption(code: 'GTQ', name: 'Guatemalan Quetzal', symbol: 'Q'),
    CurrencyOption(code: 'GYD', name: 'Guyanaese Dollar', symbol: r'GY$'),
    CurrencyOption(code: 'HKD', name: 'Hong Kong Dollar', symbol: r'HK$'),
    CurrencyOption(code: 'HNL', name: 'Honduran Lempira', symbol: 'L'),
    CurrencyOption(code: 'HRK', name: 'Croatian Kuna', symbol: 'HRK'),
    CurrencyOption(code: 'HTG', name: 'Haitian Gourde', symbol: 'HTG'),
    CurrencyOption(code: 'HUF', name: 'Hungarian Forint', symbol: 'HUF'),
    CurrencyOption(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp'),
    CurrencyOption(code: 'ILS', name: 'Israeli New Shekel', symbol: 'ILS'),
    CurrencyOption(code: 'IMP', name: 'Isle of Man Pound', symbol: 'IMP'),
    CurrencyOption(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
    CurrencyOption(code: 'IQD', name: 'Iraqi Dinar', symbol: 'IQD'),
    CurrencyOption(code: 'IRR', name: 'Iranian Rial', symbol: 'IRR'),
    CurrencyOption(code: 'ISK', name: 'Icelandic Krona', symbol: 'ISK'),
    CurrencyOption(code: 'JEP', name: 'Jersey Pound', symbol: 'JEP'),
    CurrencyOption(code: 'JMD', name: 'Jamaican Dollar', symbol: r'J$'),
    CurrencyOption(code: 'JOD', name: 'Jordanian Dinar', symbol: 'JOD'),
    CurrencyOption(code: 'JPY', name: 'Japanese Yen', symbol: 'JPY'),
    CurrencyOption(code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh'),
    CurrencyOption(code: 'KGS', name: 'Kyrgystani Som', symbol: 'KGS'),
    CurrencyOption(code: 'KHR', name: 'Cambodian Riel', symbol: 'KHR'),
    CurrencyOption(code: 'KMF', name: 'Comorian Franc', symbol: 'KMF'),
    CurrencyOption(code: 'KPW', name: 'North Korean Won', symbol: 'KPW'),
    CurrencyOption(code: 'KRW', name: 'South Korean Won', symbol: 'KRW'),
    CurrencyOption(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'KWD'),
    CurrencyOption(code: 'KYD', name: 'Cayman Islands Dollar', symbol: r'KY$'),
    CurrencyOption(code: 'KZT', name: 'Kazakhstani Tenge', symbol: 'KZT'),
    CurrencyOption(code: 'LAK', name: 'Laotian Kip', symbol: 'LAK'),
    CurrencyOption(code: 'LBP', name: 'Lebanese Pound', symbol: 'LBP'),
    CurrencyOption(code: 'LKR', name: 'Sri Lankan Rupee', symbol: 'LKR'),
    CurrencyOption(code: 'LRD', name: 'Liberian Dollar', symbol: r'L$'),
    CurrencyOption(code: 'LSL', name: 'Lesotho Loti', symbol: 'LSL'),
    CurrencyOption(code: 'LYD', name: 'Libyan Dinar', symbol: 'LYD'),
    CurrencyOption(code: 'MAD', name: 'Moroccan Dirham', symbol: 'MAD'),
    CurrencyOption(code: 'MDL', name: 'Moldovan Leu', symbol: 'MDL'),
    CurrencyOption(code: 'MGA', name: 'Malagasy Ariary', symbol: 'MGA'),
    CurrencyOption(code: 'MKD', name: 'Macedonian Denar', symbol: 'MKD'),
    CurrencyOption(code: 'MMK', name: 'Myanmar Kyat', symbol: 'MMK'),
    CurrencyOption(code: 'MNT', name: 'Mongolian Tugrik', symbol: 'MNT'),
    CurrencyOption(code: 'MOP', name: 'Macanese Pataca', symbol: 'MOP'),
    CurrencyOption(code: 'MRU', name: 'Mauritanian Ouguiya', symbol: 'MRU'),
    CurrencyOption(code: 'MUR', name: 'Mauritian Rupee', symbol: 'MUR'),
    CurrencyOption(code: 'MVR', name: 'Maldivian Rufiyaa', symbol: 'MVR'),
    CurrencyOption(code: 'MWK', name: 'Malawian Kwacha', symbol: 'MWK'),
    CurrencyOption(code: 'MXN', name: 'Mexican Peso', symbol: r'MX$'),
    CurrencyOption(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM'),
    CurrencyOption(code: 'MZN', name: 'Mozambican Metical', symbol: 'MZN'),
    CurrencyOption(code: 'NAD', name: 'Namibian Dollar', symbol: r'N$'),
    CurrencyOption(code: 'NGN', name: 'Nigerian Naira', symbol: 'NGN'),
    CurrencyOption(code: 'NIO', name: 'Nicaraguan Cordoba', symbol: r'C$'),
    CurrencyOption(code: 'NOK', name: 'Norwegian Krone', symbol: 'NOK'),
    CurrencyOption(code: 'NPR', name: 'Nepalese Rupee', symbol: 'NPR'),
    CurrencyOption(code: 'NZD', name: 'New Zealand Dollar', symbol: r'NZ$'),
    CurrencyOption(code: 'OMR', name: 'Omani Rial', symbol: 'OMR'),
    CurrencyOption(code: 'PAB', name: 'Panamanian Balboa', symbol: 'PAB'),
    CurrencyOption(code: 'PEN', name: 'Peruvian Sol', symbol: 'PEN'),
    CurrencyOption(code: 'PGK', name: 'Papua New Guinean Kina', symbol: 'PGK'),
    CurrencyOption(code: 'PHP', name: 'Philippine Peso', symbol: 'PHP'),
    CurrencyOption(code: 'PKR', name: 'Pakistani Rupee', symbol: 'PKR'),
    CurrencyOption(code: 'PLN', name: 'Polish Zloty', symbol: 'PLN'),
    CurrencyOption(code: 'PYG', name: 'Paraguayan Guarani', symbol: 'PYG'),
    CurrencyOption(code: 'QAR', name: 'Qatari Rial', symbol: 'QAR'),
    CurrencyOption(code: 'RON', name: 'Romanian Leu', symbol: 'RON'),
    CurrencyOption(code: 'RSD', name: 'Serbian Dinar', symbol: 'RSD'),
    CurrencyOption(code: 'RUB', name: 'Russian Ruble', symbol: 'RUB'),
    CurrencyOption(code: 'RWF', name: 'Rwandan Franc', symbol: 'RWF'),
    CurrencyOption(code: 'SAR', name: 'Saudi Riyal', symbol: 'SAR'),
    CurrencyOption(code: 'SBD', name: 'Solomon Islands Dollar', symbol: r'SI$'),
    CurrencyOption(code: 'SCR', name: 'Seychellois Rupee', symbol: 'SCR'),
    CurrencyOption(code: 'SDG', name: 'Sudanese Pound', symbol: 'SDG'),
    CurrencyOption(code: 'SEK', name: 'Swedish Krona', symbol: 'SEK'),
    CurrencyOption(code: 'SGD', name: 'Singapore Dollar', symbol: r'S$'),
    CurrencyOption(code: 'SHP', name: 'Saint Helena Pound', symbol: 'SHP'),
    CurrencyOption(code: 'SLE', name: 'Sierra Leonean Leone', symbol: 'SLE'),
    CurrencyOption(code: 'SOS', name: 'Somali Shilling', symbol: 'SOS'),
    CurrencyOption(code: 'SRD', name: 'Surinamese Dollar', symbol: 'SRD'),
    CurrencyOption(code: 'STN', name: 'Sao Tome and Principe Dobra', symbol: 'STN'),
    CurrencyOption(code: 'SVC', name: 'Salvadoran Colon', symbol: 'SVC'),
    CurrencyOption(code: 'SYP', name: 'Syrian Pound', symbol: 'SYP'),
    CurrencyOption(code: 'SZL', name: 'Swazi Lilangeni', symbol: 'SZL'),
    CurrencyOption(code: 'THB', name: 'Thai Baht', symbol: 'THB'),
    CurrencyOption(code: 'TJS', name: 'Tajikistani Somoni', symbol: 'TJS'),
    CurrencyOption(code: 'TMT', name: 'Turkmenistani Manat', symbol: 'TMT'),
    CurrencyOption(code: 'TND', name: 'Tunisian Dinar', symbol: 'TND'),
    CurrencyOption(code: 'TOP', name: 'Tongan Paanga', symbol: 'TOP'),
    CurrencyOption(code: 'TRY', name: 'Turkish Lira', symbol: 'TRY'),
    CurrencyOption(code: 'TTD', name: 'Trinidad and Tobago Dollar', symbol: r'TT$'),
    CurrencyOption(code: 'TWD', name: 'New Taiwan Dollar', symbol: r'NT$'),
    CurrencyOption(code: 'TZS', name: 'Tanzanian Shilling', symbol: 'TZS'),
    CurrencyOption(code: 'UAH', name: 'Ukrainian Hryvnia', symbol: 'UAH'),
    CurrencyOption(code: 'UGX', name: 'Ugandan Shilling', symbol: 'UGX'),
    CurrencyOption(code: 'USD', name: 'United States Dollar', symbol: r'$'),
    CurrencyOption(code: 'UYU', name: 'Uruguayan Peso', symbol: 'UYU'),
    CurrencyOption(code: 'UZS', name: 'Uzbekistani Som', symbol: 'UZS'),
    CurrencyOption(code: 'VES', name: 'Venezuelan Bolivar', symbol: 'VES'),
    CurrencyOption(code: 'VND', name: 'Vietnamese Dong', symbol: 'VND'),
    CurrencyOption(code: 'VUV', name: 'Vanuatu Vatu', symbol: 'VUV'),
    CurrencyOption(code: 'WST', name: 'Samoan Tala', symbol: 'WST'),
    CurrencyOption(code: 'XAF', name: 'Central African CFA Franc', symbol: 'XAF'),
    CurrencyOption(code: 'XCD', name: 'East Caribbean Dollar', symbol: r'EC$'),
    CurrencyOption(code: 'XOF', name: 'West African CFA Franc', symbol: 'XOF'),
    CurrencyOption(code: 'XPF', name: 'CFP Franc', symbol: 'XPF'),
    CurrencyOption(code: 'YER', name: 'Yemeni Rial', symbol: 'YER'),
    CurrencyOption(code: 'ZAR', name: 'South African Rand', symbol: 'ZAR'),
    CurrencyOption(code: 'ZMW', name: 'Zambian Kwacha', symbol: 'ZK'),
    CurrencyOption(code: 'ZWL', name: 'Zimbabwean Dollar', symbol: 'ZWL'),
  ];

  static const Map<String, double> _fallbackUsdToCurrencyRateByCode = {
    'AED': 3.67,
    'AFN': 72.0,
    'ALL': 95.0,
    'AMD': 390.0,
    'ANG': 1.79,
    'AOA': 915.0,
    'ARS': 1070.0,
    'AUD': 1.54,
    'AWG': 1.79,
    'AZN': 1.70,
    'BAM': 1.80,
    'BBD': 2.00,
    'BDT': 117.0,
    'BGN': 1.80,
    'BHD': 0.376,
    'BIF': 2900.0,
    'BMD': 1.0,
    'BND': 1.35,
    'BOB': 6.91,
    'BRL': 5.08,
    'BSD': 1.0,
    'BTN': 83.3,
    'BWP': 13.8,
    'BYN': 3.27,
    'BZD': 2.02,
    'CAD': 1.37,
    'CDF': 2850.0,
    'CHF': 0.91,
    'CLP': 960.0,
    'CNY': 7.24,
    'COP': 3900.0,
    'CRC': 505.0,
    'CUP': 24.0,
    'CVE': 101.0,
    'CZK': 23.2,
    'DJF': 177.7,
    'DKK': 6.87,
    'DOP': 59.2,
    'DZD': 134.0,
    'EGP': 48.5,
    'ERN': 15.0,
    'ETB': 126.0,
    'EUR': 0.92,
    'FJD': 2.25,
    'FKP': 0.79,
    'GBP': 0.79,
    'GEL': 2.72,
    'GGP': 0.79,
    'GHS': 15.5,
    'GIP': 0.79,
    'GMD': 71.5,
    'GNF': 8600.0,
    'GTQ': 7.74,
    'GYD': 209.0,
    'HKD': 7.82,
    'HNL': 24.8,
    'HRK': 6.95,
    'HTG': 132.0,
    'HUF': 362.0,
    'IDR': 16250.0,
    'ILS': 3.69,
    'IMP': 0.79,
    'INR': 83.3,
    'IQD': 1310.0,
    'IRR': 42000.0,
    'ISK': 138.0,
    'JEP': 0.79,
    'JMD': 156.0,
    'JOD': 0.709,
    'JPY': 151.0,
    'KES': 129.0,
    'KGS': 89.0,
    'KHR': 4050.0,
    'KMF': 452.0,
    'KPW': 900.0,
    'KRW': 1360.0,
    'KWD': 0.307,
    'KYD': 0.83,
    'KZT': 495.0,
    'LAK': 21600.0,
    'LBP': 89500.0,
    'LKR': 301.0,
    'LRD': 193.0,
    'LSL': 18.3,
    'LYD': 4.86,
    'MAD': 9.95,
    'MDL': 17.7,
    'MGA': 4550.0,
    'MKD': 56.7,
    'MMK': 2100.0,
    'MNT': 3450.0,
    'MOP': 8.03,
    'MRU': 39.7,
    'MUR': 46.5,
    'MVR': 15.42,
    'MWK': 1730.0,
    'MXN': 16.9,
    'MYR': 4.73,
    'MZN': 63.9,
    'NAD': 18.3,
    'NGN': 1500.0,
    'NIO': 36.8,
    'NOK': 10.8,
    'NPR': 133.3,
    'NZD': 1.66,
    'OMR': 0.384,
    'PAB': 1.0,
    'PEN': 3.72,
    'PGK': 4.05,
    'PHP': 57.5,
    'PKR': 279.0,
    'PLN': 3.98,
    'PYG': 7900.0,
    'QAR': 3.64,
    'RON': 4.57,
    'RSD': 108.0,
    'RUB': 94.0,
    'RWF': 1290.0,
    'SAR': 3.75,
    'SBD': 8.39,
    'SCR': 13.6,
    'SDG': 600.0,
    'SEK': 10.6,
    'SGD': 1.35,
    'SHP': 0.79,
    'SLE': 22.7,
    'SOS': 571.0,
    'SRD': 36.7,
    'STN': 22.4,
    'SVC': 8.75,
    'SYP': 13000.0,
    'SZL': 18.3,
    'THB': 36.7,
    'TJS': 10.9,
    'TMT': 3.5,
    'TND': 3.12,
    'TOP': 2.36,
    'TRY': 32.4,
    'TTD': 6.78,
    'TWD': 32.1,
    'TZS': 2580.0,
    'UAH': 39.5,
    'UGX': 3810.0,
    'USD': 1.0,
    'UYU': 39.2,
    'UZS': 12700.0,
    'VES': 36.5,
    'VND': 25400.0,
    'VUV': 119.0,
    'WST': 2.75,
    'XAF': 603.0,
    'XCD': 2.70,
    'XOF': 603.0,
    'XPF': 110.0,
    'YER': 250.0,
    'ZAR': 18.3,
    'ZMW': 27.3,
    'ZWL': 322.0,
  };

  static CurrencyOption _selectedOption = optionForCode(defaultCurrencyCode);
  static Map<String, double> _activeUsdToCurrencyRateByCode =
      Map<String, double>.from(_fallbackUsdToCurrencyRateByCode);
  static Map<String, double> _preferredUsdToCurrencyRateByCode = {};

  static Future<void> initialize() async {
    _selectedOption = await getSelectedCurrency();
    await _loadCachedRates();
    await _loadCachedPreferredRates();
  }

  static CurrencyOption get currentCurrency => _selectedOption;
  static ValueListenable<int> get changes => _changeCounter;

  static double usdToCurrency(double usdAmount, {String? currencyCode}) {
    final rate = _rateForCode(currencyCode ?? currentCurrency.code);
    return usdAmount * rate;
  }

  static double currencyToUsd(double amount, {String? currencyCode}) {
    final rate = _rateForCode(currencyCode ?? currentCurrency.code);
    if (rate <= 0) {
      return amount;
    }

    return amount / rate;
  }

  static CurrencyOption optionForCode(String? code) {
    final normalizedCode = code?.trim().toUpperCase() ?? '';
    return options.firstWhere(
      (option) => option.code == normalizedCode,
      orElse: () => options.firstWhere(
        (option) => option.code == defaultCurrencyCode,
      ),
    );
  }

  static Future<CurrencyOption> getSelectedCurrency() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCode = preferences.getString(_selectedCurrencyCodeKey);
    return optionForCode(storedCode);
  }

  static Future<void> setSelectedCurrencyCode(String code) async {
    final selectedOption = optionForCode(code);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedCurrencyCodeKey, selectedOption.code);
    _selectedOption = selectedOption;
    _changeCounter.value++;
  }

  static Future<void> refreshPreferredRateForCode(
    String code, {
    bool force = false,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty || normalizedCode == defaultCurrencyCode) {
      return;
    }

    if (!force && _preferredUsdToCurrencyRateByCode.containsKey(normalizedCode)) {
      return;
    }

    final yahooRate = await _fetchYahooUsdPairRate(normalizedCode);
    if (yahooRate == null || yahooRate <= 0) {
      return;
    }

    _preferredUsdToCurrencyRateByCode = {
      ..._preferredUsdToCurrencyRateByCode,
      normalizedCode: yahooRate,
    };

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cachedPreferredRatesKey,
      jsonEncode(_preferredUsdToCurrencyRateByCode),
    );
    _changeCounter.value++;
  }

  static Future<void> refreshRatesFromInternet({bool force = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final lastUpdatedAt = preferences.getInt(_ratesUpdatedAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const refreshInterval = Duration(hours: 12);

    if (!force &&
        lastUpdatedAt > 0 &&
        now - lastUpdatedAt < refreshInterval.inMilliseconds) {
      return;
    }

    try {
      final response = await _httpClient.get(Uri.parse(_latestUsdRatesUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if ((decoded['result'] ?? '').toString().toLowerCase() != 'success') {
        return;
      }

      final rawRates = decoded['rates'];
      if (rawRates is! Map) {
        return;
      }

      final parsedRates = <String, double>{};
      for (final entry in rawRates.entries) {
        final code = entry.key.toString().trim().toUpperCase();
        final value = entry.value;
        final rate = value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (code.isEmpty || rate == null || rate <= 0) {
          continue;
        }

        parsedRates[code] = rate;
      }

      if (parsedRates.isEmpty) {
        return;
      }

      _activeUsdToCurrencyRateByCode = {
        ..._fallbackUsdToCurrencyRateByCode,
        ...parsedRates,
      };
      await preferences.setString(
        _cachedRatesKey,
        jsonEncode(_activeUsdToCurrencyRateByCode),
      );
      await preferences.setInt(_ratesUpdatedAtKey, now);
      _changeCounter.value++;
    } catch (_) {
      // Keep using cached or fallback rates when the network request fails.
    }
  }

  static Future<void> _loadCachedRates() async {
    final preferences = await SharedPreferences.getInstance();
    final rawCachedRates = preferences.getString(_cachedRatesKey)?.trim() ?? '';
    if (rawCachedRates.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawCachedRates);
      if (decoded is! Map) {
        return;
      }

      final parsedRates = <String, double>{};
      for (final entry in decoded.entries) {
        final code = entry.key.toString().trim().toUpperCase();
        final value = entry.value;
        final rate = value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (code.isEmpty || rate == null || rate <= 0) {
          continue;
        }

        parsedRates[code] = rate;
      }

      if (parsedRates.isEmpty) {
        return;
      }

      _activeUsdToCurrencyRateByCode = {
        ..._fallbackUsdToCurrencyRateByCode,
        ...parsedRates,
      };
    } catch (_) {
      // Ignore malformed cache and keep fallback rates.
    }
  }

  static Future<void> _loadCachedPreferredRates() async {
    final preferences = await SharedPreferences.getInstance();
    final rawCachedRates =
        preferences.getString(_cachedPreferredRatesKey)?.trim() ?? '';
    if (rawCachedRates.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawCachedRates);
      if (decoded is! Map) {
        return;
      }

      final parsedRates = <String, double>{};
      for (final entry in decoded.entries) {
        final code = entry.key.toString().trim().toUpperCase();
        final value = entry.value;
        final rate = value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (code.isEmpty || rate == null || rate <= 0) {
          continue;
        }

        parsedRates[code] = rate;
      }

      _preferredUsdToCurrencyRateByCode = parsedRates;
    } catch (_) {
      // Ignore malformed cache and continue with primary feed rates.
    }
  }

  static Future<double?> _fetchYahooUsdPairRate(String code) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_yahooUsdPairUrlPrefix$code=X?range=1d&interval=1d'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final chart = decoded['chart'];
      if (chart is! Map<String, dynamic>) {
        return null;
      }

      final results = chart['result'];
      if (results is! List || results.isEmpty) {
        return null;
      }

      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final meta = first['meta'];
      if (meta is! Map<String, dynamic>) {
        return null;
      }

      final price = meta['regularMarketPrice'];
      if (price is num && price > 0) {
        return price.toDouble();
      }

      final previousClose = meta['chartPreviousClose'];
      if (previousClose is num && previousClose > 0) {
        return previousClose.toDouble();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static double _rateForCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    return _preferredUsdToCurrencyRateByCode[normalizedCode] ??
        _activeUsdToCurrencyRateByCode[normalizedCode] ??
        1.0;
  }
}