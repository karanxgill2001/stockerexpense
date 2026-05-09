import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/account_profile.dart';
import '../models/app_update_info.dart';
import '../models/employee_record.dart';
import '../models/finance_entry.dart';
import '../models/inventory_item.dart';
import '../models/order_line_item.dart';
import '../models/order_record.dart';
import '../models/sale_record.dart';
import 'backend_config_service.dart';

class GoogleSheetService {
  GoogleSheetService._();

  static final GoogleSheetService instance = GoogleSheetService._();
  static const int _maxRedirects = 5;
  static const String _noInternetMessage =
      'No internet connection. Check your internet and try again.';
    static const String _webRequestBlockedMessage =
      'Browser could not reach the Google Sheets server. Check the Apps Script URL, deployment access, and browser cross-origin access.';
  static const String _dataFolderName = 'stocker/data';
  static const String _inventoryFileName = 'inventory_data.json';
  static const String _ordersFileName = 'orders_data.json';
  static const String _invoiceLogoFileName = 'invoice_logo_data.json';
  static const String _settingsProfileFilePrefix = 'settings_profile_';

  final http.Client _client = http.Client();

  List<InventoryItem>? _inventoryCache;
  DateTime? _inventoryCacheTime;
  List<OrderRecord>? _ordersCache;
  DateTime? _ordersCacheTime;
  String? _invoiceLogoBase64Cache;
  DateTime? _invoiceLogoCacheTime;
  bool _persistentCacheLoaded = false;

  Future<void> preloadStartupData() async {
    await _ensurePersistentCacheLoaded();

    try {
      await fetchInventory(forceRefresh: true);
    } catch (_) {
      // Keep using locally cached inventory if the network refresh fails.
    }

    try {
      await fetchOrders(forceRefresh: true);
    } catch (_) {
      // Keep using locally cached orders if the network refresh fails.
    }
  }

  Future<List<InventoryItem>> fetchInventory({
    bool forceRefresh = false,
  }) async {
    await _ensurePersistentCacheLoaded();

    if (!forceRefresh && _inventoryCache != null) {
      return _inventoryCache!;
    }

    try {
      final uri = await _buildStockUri('getStock');
      final response = await _sendRequest(
        method: 'GET',
        uri: uri,
        headers: const {'Accept': 'application/json'},
      );
      final data = _decodeResponse(response);
      final rows = data['data'];

      if (rows is! List) {
        _inventoryCache = const [];
        _inventoryCacheTime = DateTime.now();
        await _persistInventoryCache();
        return const [];
      }

      final items = rows
          .whereType<Map>()
          .map((row) => InventoryItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      final mergedItems = _mergeItemsBySku(items);
      _inventoryCache = mergedItems;
      _inventoryCacheTime = DateTime.now();
      await _persistInventoryCache();
      return mergedItems;
    } catch (_) {
      if (_inventoryCache != null) {
        return _inventoryCache!;
      }

      rethrow;
    }
  }

  Future<List<OrderRecord>> fetchOrders({bool forceRefresh = false}) async {
    await _ensurePersistentCacheLoaded();

    if (!forceRefresh && _ordersCache != null) {
      return _ordersCache!;
    }

    try {
      final uri = await _buildStockUri('getOrders');
      final response = await _sendRequest(
        method: 'GET',
        uri: uri,
        headers: const {'Accept': 'application/json'},
      );
      final data = _decodeResponse(response);
      final rows = data['data'];

      if (rows is! List) {
        _ordersCache = const [];
        _ordersCacheTime = DateTime.now();
        await _persistOrdersCache();
        return const [];
      }

      final orders = rows
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => OrderRecord.fromJson(
              Map<String, dynamic>.from(entry.value),
              entry.key,
            ),
          )
          .toList();

      _ordersCache = orders;
      _ordersCacheTime = DateTime.now();
      await _persistOrdersCache();
      return orders;
    } catch (_) {
      if (_ordersCache != null) {
        return _ordersCache!;
      }

      rethrow;
    }
  }

  Future<void> addStock(InventoryItem item) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'addStock', ...item.toJson()}),
    );

    _decodeResponse(response);
    await _applyLocalInventoryUpsert(item);
  }

  Future<void> updateStock({
    required String currentItemName,
    required String currentSku,
    required InventoryItem item,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'updateStock',
        'currentItemName': currentItemName,
        'currentSku': currentSku,
        ...item.toJson(),
      }),
    );

    _decodeResponse(response);
    await _applyLocalInventoryReplace(
      currentItemName: currentItemName,
      currentSku: currentSku,
      updatedItem: item,
    );
  }

  Future<void> deleteStock({
    required String itemName,
    required String sku,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'deleteStock',
        'itemName': itemName,
        'sku': sku,
      }),
    );

    _decodeResponse(response);
    await _applyLocalInventoryDelete(itemName: itemName, sku: sku);
  }

  Future<void> addSale(SaleRecord saleRecord) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'addSale', ...saleRecord.toJson()}),
    );

    _decodeResponse(response);
    _invalidateInventoryCache();
    _invalidateOrdersCache();
  }

  Future<void> updateOrder({
    required String orderId,
    required String companyName,
    required String customerName,
    required String phoneNo,
    required String email,
    required String shippingAddress,
    required double shippingCost,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'updateOrder',
        'orderId': orderId,
        'companyName': companyName,
        'customerName': customerName,
        'phoneNo': phoneNo,
        'email': email,
        'shippingAddress': shippingAddress,
        'shippingCost': shippingCost,
      }),
    );

    _decodeResponse(response);
    await _applyLocalOrderUpdate(
      orderId: orderId,
      companyName: companyName,
      customerName: customerName,
      phoneNo: phoneNo,
      email: email,
      shippingAddress: shippingAddress,
      shippingCost: shippingCost,
    );
  }

  Future<void> deleteOrder(String orderId) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'deleteOrder', 'orderId': orderId}),
    );

    _decodeResponse(response);
    await _applyLocalOrderDelete(orderId);
    _invalidateInventoryCache();
  }

  Future<double> fetchTaxPercentage() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: await _buildStockUri('getTaxSetting'),
      headers: const {'Accept': 'application/json'},
    );

    final data = _decodeResponse(response);
    final value = data['taxPercentage'];
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> updateTaxPercentage(double value) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'updateTaxSetting', 'taxPercentage': value}),
    );

    _decodeResponse(response);
  }

  Future<List<FinanceEntry>> fetchFinanceEntries() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: await _buildStockUri('getFinanceEntries'),
      headers: const {'Accept': 'application/json'},
    );

    final data = _decodeResponse(response);
    final rows = data['data'];
    if (rows is! List) {
      return const [];
    }

    return rows
        .whereType<Map>()
        .map((row) => FinanceEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<EmployeeRecord>> fetchEmployees() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: await _buildStockUri('getEmployees'),
      headers: const {'Accept': 'application/json'},
    );

    final data = _decodeResponse(response);
    final rows = data['data'];
    if (rows is! List) {
      return const [];
    }

    return rows
        .whereType<Map>()
        .map((row) => EmployeeRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> upsertEmployee(EmployeeRecord employee) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'upsertEmployee',
        'employeeId': employee.id,
        'name': employee.name,
        'createdAt': employee.createdAt.toIso8601String(),
      }),
    );

    _decodeResponse(response);
  }

  Future<void> deleteEmployee(String employeeId) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'deleteEmployee',
        'employeeId': employeeId,
      }),
    );

    _decodeResponse(response);
  }

  Future<void> upsertFinanceEntry({required FinanceEntry entry}) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'upsertFinanceEntry',
        'entryId': entry.id,
        'name': entry.accountName,
        'accountEmail': entry.accountEmail.trim().toLowerCase(),
        'employeeName': entry.employeeName,
        'employeeBreakdown': entry.employeeBreakdown,
        'type': entry.type.storageValue,
        'title': entry.title,
        'amount': entry.amount,
        'displayAmount': entry.displayAmount,
        'currencyCode': entry.currencyCode,
        'occurredOn': entry.occurredOnStorageValue,
        'note': entry.note,
        'createdAt': entry.createdAt.toIso8601String(),
      }),
    );

    _decodeResponse(response);
  }

  Future<void> deleteFinanceEntry({
    required String accountEmail,
    required String entryId,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'deleteFinanceEntry',
        'entryId': entryId,
        'accountEmail': accountEmail.trim().toLowerCase(),
      }),
    );

    _decodeResponse(response);
  }

  Future<String?> fetchInvoiceLogoBase64({bool forceRefresh = false}) async {
    await _ensurePersistentCacheLoaded();

    if (!forceRefresh && _invoiceLogoBase64Cache != null) {
      return _invoiceLogoBase64Cache!.trim().isEmpty
          ? null
          : _invoiceLogoBase64Cache;
    }

    try {
      final response = await _sendRequest(
        method: 'GET',
        uri: await _buildStockUri('getInvoiceLogo'),
        headers: const {'Accept': 'application/json'},
      );

      final data = _decodeResponse(response);
      final value = (data['invoiceLogoBase64'] ?? '').toString().trim();
      _invoiceLogoBase64Cache = value;
      _invoiceLogoCacheTime = DateTime.now();
      await _persistInvoiceLogoCache();
      return value.isEmpty ? null : value;
    } catch (_) {
      if (_invoiceLogoBase64Cache != null) {
        return _invoiceLogoBase64Cache!.trim().isEmpty
            ? null
            : _invoiceLogoBase64Cache;
      }

      rethrow;
    }
  }

  Future<void> updateInvoiceLogoBase64(String base64Value) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'updateInvoiceLogo',
        'invoiceLogoBase64': base64Value,
      }),
    );

    _decodeResponse(response);
    _invoiceLogoBase64Cache = base64Value;
    _invoiceLogoCacheTime = DateTime.now();
    await _persistInvoiceLogoCache();
  }

  Future<void> clearInvoiceLogo() async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildStockUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'clearInvoiceLogo'}),
    );

    _decodeResponse(response);
    _invoiceLogoBase64Cache = '';
    _invoiceLogoCacheTime = DateTime.now();
    await _persistInvoiceLogoCache();
  }

  Future<void> createAccount({
    required String companyName,
    required String fullName,
    required String address,
    required String email,
    required String phoneNo,
    required String masterKey,
    required String password,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildCredentialsUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'createAccount',
        'companyName': companyName,
        'fullName': fullName,
        'address': address,
        'email': email,
        'phoneNo': phoneNo,
        'masterKey': masterKey,
        'password': password,
      }),
    );

    _decodeResponse(response);
  }

  Future<AccountProfile> authenticateAccount({
    required String email,
    required String password,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildCredentialsUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'authenticateAccount',
        'email': email,
        'password': password,
      }),
    );

    final profile = AccountProfile.fromJson(_decodeResponse(response));
    await _persistAccountProfile(profile);
    return profile;
  }

  Future<AccountProfile> fetchAccountProfile(String email) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildCredentialsUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'getAccountProfile', 'email': email}),
    );

    final profile = AccountProfile.fromJson(_decodeResponse(response));
    await _persistAccountProfile(profile);
    return profile;
  }

  Future<AccountProfile> updateAccountProfile({
    required String currentEmail,
    required String companyName,
    required String fullName,
    required String address,
    required String email,
    required String phoneNo,
    required String masterKey,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildCredentialsUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'updateAccountProfile',
        'currentEmail': currentEmail,
        'companyName': companyName,
        'fullName': fullName,
        'address': address,
        'email': email,
        'phoneNo': phoneNo,
        'masterKey': masterKey,
      }),
    );

    final profile = AccountProfile.fromJson(_decodeResponse(response));
    await _persistAccountProfile(profile);
    return profile;
  }

  Future<AccountProfile?> getStoredAccountProfile(String email) async {
    if (kIsWeb) {
      return null;
    }

    final normalizedEmail = _normalizeFileSegment(email);
    if (normalizedEmail.isEmpty) {
      return null;
    }

    final payload = await _readStoredPayload(
      '$_settingsProfileFilePrefix$normalizedEmail.json',
    );
    if (payload == null) {
      return null;
    }

    final profileData = payload['data'];
    if (profileData is! Map<String, dynamic>) {
      return null;
    }

    return AccountProfile.fromJson(profileData);
  }

  Future<void> resetAccountPassword({
    required String email,
    required String masterKey,
    required String newPassword,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      uri: await _buildCredentialsUri(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'resetAccountPassword',
        'email': email,
        'masterKey': masterKey,
        'newPassword': newPassword,
      }),
    );

    _decodeResponse(response);
  }

  Future<AppUpdateInfo?> fetchAppUpdateInfo() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: await _buildCredentialsUri('getAppUpdate'),
      headers: const {'Accept': 'application/json'},
    );

    final data = _decodeResponse(response);
    final info = AppUpdateInfo.fromJson(data);
    if (!info.isConfigured) {
      return null;
    }

    return info;
  }

  Future<http.Response> _sendRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      var currentMethod = method.toUpperCase();
      var currentUri = uri;
      var currentBody = body;
      var redirectCount = 0;

      while (true) {
        final requestHeaders = _prepareRequestHeaders(
          method: currentMethod,
          headers: headers,
        );
        final request = http.Request(currentMethod, currentUri)
          ..headers.addAll(requestHeaders);
        if (currentBody != null &&
            currentMethod != 'GET' &&
            currentMethod != 'HEAD') {
          request.body = currentBody;
        }

        final streamedResponse = await _client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (!_isRedirect(response.statusCode)) {
          return response;
        }

        final location = response.headers['location'];
        if (location == null || location.isEmpty) {
          return response;
        }

        redirectCount += 1;
        if (redirectCount > _maxRedirects) {
          throw const GoogleSheetException(
            'Too many redirects from Google Sheets server.',
          );
        }

        currentUri = currentUri.resolve(location);

        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303) {
          currentMethod = 'GET';
          currentBody = null;
        }
      }
    } on SocketException {
      throw const GoogleSheetException(_noInternetMessage);
    } on HttpException {
      throw const GoogleSheetException(_noInternetMessage);
    } on http.ClientException {
      if (kIsWeb) {
        throw const GoogleSheetException(_webRequestBlockedMessage);
      }
      throw const GoogleSheetException(_noInternetMessage);
    }
  }

  Map<String, String> _prepareRequestHeaders({
    required String method,
    Map<String, String>? headers,
  }) {
    final requestHeaders = Map<String, String>.from(headers ?? const {});
    final normalizedMethod = method.toUpperCase();

    if (!kIsWeb ||
        normalizedMethod == 'GET' ||
        normalizedMethod == 'HEAD' ||
        !_hasJsonContentType(requestHeaders)) {
      return requestHeaders;
    }

    final contentTypeKey = requestHeaders.keys.firstWhere(
      (key) => key.toLowerCase() == 'content-type',
      orElse: () => 'Content-Type',
    );
    requestHeaders[contentTypeKey] = 'text/plain;charset=UTF-8';
    return requestHeaders;
  }

  bool _hasJsonContentType(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'content-type') {
        continue;
      }

      return entry.value.toLowerCase().contains('application/json');
    }

    return false;
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  Future<Uri> _buildStockUri([String? action]) async {
    final url = (await BackendConfigService.getStockGoogleScriptUrl()).trim();
    if (url.isEmpty) {
      throw const GoogleSheetException(
        'Stock Google Sheets server URL is missing. Set GOOGLE_SCRIPT_URL before running the app.',
      );
    }

    return _buildUriFromUrl(url, action);
  }

  Future<Uri> _buildCredentialsUri([String? action]) async {
    final url = (await BackendConfigService.getCredentialsGoogleScriptUrl())
        .trim();
    if (url.isEmpty) {
      throw const GoogleSheetException(
        'Credentials Google Sheets server URL is missing. Set CREDENTIALS_SCRIPT_URL before running the app.',
      );
    }

    return _buildUriFromUrl(url, action);
  }

  Uri _buildUriFromUrl(String url, [String? action]) {
    final baseUri = Uri.parse(url);
    final queryParameters = Map<String, String>.from(baseUri.queryParameters);
    if (action != null && action.isNotEmpty) {
      queryParameters['action'] = action;
    }

    return baseUri.replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleSheetException(
        'Google Sheets server returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const GoogleSheetException(
        'Invalid response from Google Sheets server.',
      );
    }

    if (decoded['success'] == false) {
      throw GoogleSheetException(
        decoded['error']?.toString() ?? 'Google Sheets request failed.',
      );
    }

    return decoded;
  }

  List<InventoryItem> _mergeItemsBySku(List<InventoryItem> items) {
    final mergedItems = <String, InventoryItem>{};
    var emptySkuIndex = 0;

    for (final item in items) {
      final normalizedSku = item.sku.trim().toLowerCase();
      final key = normalizedSku.isEmpty
          ? '__empty__${emptySkuIndex++}'
          : normalizedSku;
      final existingItem = mergedItems[key];

      if (existingItem == null) {
        mergedItems[key] = item;
        continue;
      }

      mergedItems[key] = existingItem.mergeWith(item);
    }

    return mergedItems.values.toList();
  }

  Future<void> _applyLocalInventoryUpsert(InventoryItem item) async {
    await _ensurePersistentCacheLoaded();
    final items = List<InventoryItem>.from(_inventoryCache ?? const []);
    final normalizedSku = item.sku.trim().toLowerCase();
    final index = items.indexWhere(
      (entry) => entry.sku.trim().toLowerCase() == normalizedSku,
    );

    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }

    _inventoryCache = _mergeItemsBySku(items);
    _inventoryCacheTime = DateTime.now();
    await _persistInventoryCache();
  }

  Future<void> _applyLocalInventoryReplace({
    required String currentItemName,
    required String currentSku,
    required InventoryItem updatedItem,
  }) async {
    await _ensurePersistentCacheLoaded();
    final items = List<InventoryItem>.from(_inventoryCache ?? const []);
    final normalizedSku = currentSku.trim().toLowerCase();
    final normalizedName = currentItemName.trim().toLowerCase();
    final index = items.indexWhere(
      (entry) =>
          entry.sku.trim().toLowerCase() == normalizedSku &&
          entry.itemName.trim().toLowerCase() == normalizedName,
    );

    if (index == -1) {
      items.add(updatedItem);
    } else {
      items[index] = updatedItem;
    }

    _inventoryCache = _mergeItemsBySku(items);
    _inventoryCacheTime = DateTime.now();
    await _persistInventoryCache();
  }

  Future<void> _applyLocalInventoryDelete({
    required String itemName,
    required String sku,
  }) async {
    await _ensurePersistentCacheLoaded();
    final normalizedSku = sku.trim().toLowerCase();
    final normalizedName = itemName.trim().toLowerCase();
    _inventoryCache = List<InventoryItem>.from(_inventoryCache ?? const [])
        .where(
          (entry) =>
              !(entry.sku.trim().toLowerCase() == normalizedSku &&
                  entry.itemName.trim().toLowerCase() == normalizedName),
        )
        .toList();
    _inventoryCacheTime = DateTime.now();
    await _persistInventoryCache();
  }

  Future<void> _applyLocalOrderUpdate({
    required String orderId,
    required String companyName,
    required String customerName,
    required String phoneNo,
    required String email,
    required String shippingAddress,
    required double shippingCost,
  }) async {
    await _ensurePersistentCacheLoaded();
    final orders = List<OrderRecord>.from(_ordersCache ?? const []);
    final index = orders.indexWhere((order) => order.orderId == orderId);
    if (index == -1) {
      return;
    }

    final existing = orders[index];
    orders[index] = OrderRecord(
      companyName: companyName,
      customerName: customerName,
      phoneNo: phoneNo,
      email: email,
      shippingAddress: shippingAddress,
      shippingCost: shippingCost,
      quantity: existing.quantity,
      sku: existing.sku,
      itemName: existing.itemName,
      unitPrice: existing.unitPrice,
      taxPercentage: existing.taxPercentage,
      taxAmount: existing.taxAmount,
      totalCost: _calculateOrderTotal(
        items: existing.items,
        shippingCost: shippingCost,
        taxAmount: existing.taxAmount,
      ),
      orderId: existing.orderId,
      createdAt: existing.createdAt,
      items: existing.items,
    );

    _ordersCache = orders;
    _ordersCacheTime = DateTime.now();
    await _persistOrdersCache();
  }

  Future<void> _applyLocalOrderDelete(String orderId) async {
    await _ensurePersistentCacheLoaded();
    _ordersCache = List<OrderRecord>.from(
      _ordersCache ?? const [],
    ).where((order) => order.orderId != orderId).toList();
    _ordersCacheTime = DateTime.now();
    await _persistOrdersCache();
  }

  double _calculateOrderTotal({
    required List<OrderLineItem> items,
    required double shippingCost,
    required double taxAmount,
  }) {
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    return subtotal + shippingCost + taxAmount;
  }

  Future<void> _ensurePersistentCacheLoaded() async {
    if (_persistentCacheLoaded) {
      return;
    }

    if (kIsWeb) {
      _persistentCacheLoaded = true;
      return;
    }

    final inventoryPayload = await _readStoredPayload(_inventoryFileName);
    final inventoryData = inventoryPayload?['data'];
    if (inventoryData is List) {
      _inventoryCache = inventoryData
          .whereType<Map>()
          .map(
            (item) => InventoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    _inventoryCacheTime = DateTime.tryParse(
      (inventoryPayload?['updatedAt'] ?? '').toString(),
    );

    final ordersPayload = await _readStoredPayload(_ordersFileName);
    final ordersData = ordersPayload?['data'];
    if (ordersData is List) {
      _ordersCache = ordersData
          .whereType<Map>()
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => OrderRecord.fromJson(
              Map<String, dynamic>.from(entry.value),
              entry.key,
            ),
          )
          .toList();
    }
    _ordersCacheTime = DateTime.tryParse(
      (ordersPayload?['updatedAt'] ?? '').toString(),
    );

    final invoiceLogoPayload = await _readStoredPayload(_invoiceLogoFileName);
    _invoiceLogoBase64Cache = (invoiceLogoPayload?['data'] ?? '').toString();
    _invoiceLogoCacheTime = DateTime.tryParse(
      (invoiceLogoPayload?['updatedAt'] ?? '').toString(),
    );

    _persistentCacheLoaded = true;
  }

  Future<void> _persistInventoryCache() async {
    await _writeStoredPayload(_inventoryFileName, {
      'updatedAt': (_inventoryCacheTime ?? DateTime.now()).toIso8601String(),
      'data': (_inventoryCache ?? const [])
          .map((item) => item.toJson())
          .toList(),
    });
  }

  Future<void> _persistOrdersCache() async {
    await _writeStoredPayload(_ordersFileName, {
      'updatedAt': (_ordersCacheTime ?? DateTime.now()).toIso8601String(),
      'data': (_ordersCache ?? const [])
          .map((order) => order.toJson())
          .toList(),
    });
  }

  Future<void> _persistInvoiceLogoCache() async {
    await _writeStoredPayload(_invoiceLogoFileName, {
      'updatedAt': (_invoiceLogoCacheTime ?? DateTime.now()).toIso8601String(),
      'data': _invoiceLogoBase64Cache ?? '',
    });
  }

  Future<void> _clearPersistentInventoryCache() async {
    await _deleteStoredFile(_inventoryFileName);
  }

  Future<void> _clearPersistentOrdersCache() async {
    await _deleteStoredFile(_ordersFileName);
  }

  Future<void> _clearPersistentInvoiceLogoCache() async {
    await _deleteStoredFile(_invoiceLogoFileName);
  }

  Future<Map<String, dynamic>?> _readStoredPayload(String fileName) async {
    if (kIsWeb) {
      return null;
    }

    final file = await _getDataFile(fileName);
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return decoded;
  }

  Future<void> _writeStoredPayload(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    if (kIsWeb) {
      return;
    }

    final file = await _getDataFile(fileName);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<void> _deleteStoredFile(String fileName) async {
    if (kIsWeb) {
      return;
    }

    final file = await _getDataFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _persistAccountProfile(AccountProfile profile) async {
    final normalizedEmail = _normalizeFileSegment(profile.email);
    if (normalizedEmail.isEmpty) {
      return;
    }

    await _writeStoredPayload(
      '$_settingsProfileFilePrefix$normalizedEmail.json',
      {'updatedAt': DateTime.now().toIso8601String(), 'data': profile.toJson()},
    );
  }

  String _normalizeFileSegment(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Future<File> _getDataFile(String fileName) async {
    final directory = await _getDataDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<Directory> _getDataDirectory() async {
    Directory? baseDirectory;
    if (Platform.isAndroid) {
      baseDirectory = await getExternalStorageDirectory();
    }
    baseDirectory ??= await getApplicationDocumentsDirectory();

    return Directory(
      '${baseDirectory.path}${Platform.pathSeparator}${_dataFolderName.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  void _invalidateInventoryCache() {
    _inventoryCache = null;
    _inventoryCacheTime = null;
    _clearPersistentInventoryCache();
  }

  void _invalidateOrdersCache() {
    _ordersCache = null;
    _ordersCacheTime = null;
    _clearPersistentOrdersCache();
  }

  void clearCache() {
    _invalidateInventoryCache();
    _invalidateOrdersCache();
    _invoiceLogoBase64Cache = null;
    _invoiceLogoCacheTime = null;
    _clearPersistentInvoiceLogoCache();
  }
}

class GoogleSheetException implements Exception {
  const GoogleSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}
