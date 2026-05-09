import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/order_notification_item.dart';
import '../models/order_record.dart';
import 'google_sheet_service.dart';
import 'session_service.dart';

const String orderSyncTaskName = 'orderBackgroundSyncTask';

@pragma('vm:entry-point')
void orderSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      await OrderSyncService.ensureInitializedForBackground();
      await OrderSyncService.runBackgroundOrderCheck();
      return true;
    } catch (_) {
      return false;
    } finally {
      await OrderSyncService.scheduleNextClosedAppBackgroundCheck();
    }
  });
}

class OrderSyncService {
  OrderSyncService._();

  static bool get _supportsPlatformNotifications => !kIsWeb;
  static bool get _supportsBackgroundWork => !kIsWeb;

  static const String _knownOrderSignaturesKey = 'known_order_signatures';
  static const String _storedNotificationsKey = 'stored_order_notifications';
  static const String _backgroundWorkUniqueName = 'order-background-sync';
  static const String _backgroundOneOffUniqueName =
      'order-background-sync-once';
  static const Duration _closedAppRefreshInterval = Duration(minutes: 1);
  static const String _notificationChannelId = 'order_updates';
  static const String _notificationChannelName = 'Order Updates';
  static const String _notificationChannelDescription =
      'Notifies when new Google Sheet orders are detected';
  static const int _notificationId = 3001;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsReady = false;
  static bool _workmanagerReady = false;

  static Future<void> initialize() async {
    if (!_supportsPlatformNotifications && !_supportsBackgroundWork) {
      return;
    }

    await _initializeNotifications();
    await _requestNotificationPermission();
    await _initializeWorkmanager();
    await scheduleImmediateBackgroundCheck();
  }

  static Future<void> ensureInitializedForBackground() async {
    await _initializeNotifications();
  }

  static Future<void> _initializeWorkmanager() async {
    if (!_supportsBackgroundWork) {
      return;
    }

    if (_workmanagerReady) {
      return;
    }

    await Workmanager().initialize(orderSyncCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _backgroundWorkUniqueName,
      orderSyncTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    _workmanagerReady = true;
  }

  static Future<void> scheduleImmediateBackgroundCheck() async {
    if (!_supportsBackgroundWork) {
      return;
    }

    await _initializeWorkmanager();
    await _registerClosedAppOneOffCheck();
  }

  static Future<void> scheduleNextClosedAppBackgroundCheck() async {
    if (!_supportsBackgroundWork) {
      return;
    }

    await _registerClosedAppOneOffCheck();
  }

  static Future<void> _registerClosedAppOneOffCheck() async {
    if (!_supportsBackgroundWork) {
      return;
    }

    await Workmanager().registerOneOffTask(
      _backgroundOneOffUniqueName,
      orderSyncTaskName,
      initialDelay: _closedAppRefreshInterval,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> _initializeNotifications() async {
    if (!_supportsPlatformNotifications) {
      return;
    }

    if (_notificationsReady) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(settings: initializationSettings);

    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: _notificationChannelDescription,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _notificationsReady = true;
  }

  static Future<void> _requestNotificationPermission() async {
    if (!_supportsPlatformNotifications) {
      return;
    }

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<bool> syncForegroundOrders() async {
    final result = await _pollOrders();
    if (result.hasNewOrders) {
      await _showNewOrderNotification(result.newOrders);
    }
    return result.hasChanges;
  }

  static Future<List<OrderNotificationItem>> fetchStoredNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storedNotificationsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              OrderNotificationItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<void> clearStoredNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storedNotificationsKey);
  }

  static Future<void> recordCompletedOrderNotification({
    required String customerName,
    required String companyName,
    required String itemName,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final displayName = _notificationDisplayName(
      customerName: customerName,
      companyName: companyName,
      itemName: itemName,
    );

    final existing = await fetchStoredNotifications();
    final notification = OrderNotificationItem(
      orderId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      customerName: displayName,
      detectedAt: DateTime.now(),
    );

    final next = [
      notification,
      ...existing,
    ].take(50).map((item) => item.toJson()).toList();
    await preferences.setString(_storedNotificationsKey, jsonEncode(next));

    try {
      final orders = await GoogleSheetService.instance.fetchOrders(
        forceRefresh: true,
      );
      await _storeKnownSignatures(
        preferences,
        orders.map(_orderSignature).toSet(),
      );
    } catch (_) {
      // Keep the locally recorded notification even if order sync refresh fails.
    }
  }

  static Future<void> runBackgroundOrderCheck() async {
    final signedInEmail = await SessionService.getUserEmail();
    if (signedInEmail == null || signedInEmail.trim().isEmpty) {
      return;
    }

    final result = await _pollOrders();
    if (!result.hasNewOrders) {
      return;
    }

    await _showNewOrderNotification(result.newOrders);
  }

  static Future<void> _showNewOrderNotification(
    List<OrderRecord> newOrders,
  ) async {
    if (!_supportsPlatformNotifications) {
      return;
    }

    if (newOrders.isEmpty) {
      return;
    }

    final latestOrder = newOrders.first;
    final title = newOrders.length == 1
        ? 'New order received'
        : '${newOrders.length} new orders received';
    final body = '${_orderDisplayName(latestOrder)} added to Orders.';

    await _notifications.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          _notificationChannelName,
          channelDescription: _notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<_OrderSyncResult> _pollOrders() async {
    final preferences = await SharedPreferences.getInstance();
    final previousSignatures = _readKnownSignatures(preferences);
    final orders = await GoogleSheetService.instance.fetchOrders(
      forceRefresh: true,
    );
    final currentSignatures = orders.map(_orderSignature).toSet();

    if (previousSignatures.isEmpty) {
      await _storeKnownSignatures(preferences, currentSignatures);
      return const _OrderSyncResult(
        hasChanges: false,
        hasNewOrders: false,
        newOrders: [],
      );
    }

    final changed = !_setEquals(previousSignatures, currentSignatures);
    final newSignatureSet = currentSignatures.difference(previousSignatures);
    final newOrders =
        orders
            .where((order) => newSignatureSet.contains(_orderSignature(order)))
            .toList()
          ..sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

    if (newOrders.isNotEmpty) {
      await _storeOrderNotifications(preferences, newOrders);
    }

    await _storeKnownSignatures(preferences, currentSignatures);
    return _OrderSyncResult(
      hasChanges: changed,
      hasNewOrders: newOrders.isNotEmpty,
      newOrders: newOrders,
    );
  }

  static Set<String> _readKnownSignatures(SharedPreferences preferences) {
    final raw = preferences.getString(_knownOrderSignaturesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <String>{};
    }

    return decoded.map((item) => item.toString()).toSet();
  }

  static Future<void> _storeKnownSignatures(
    SharedPreferences preferences,
    Set<String> signatures,
  ) async {
    final sorted = signatures.toList()..sort();
    await preferences.setString(_knownOrderSignaturesKey, jsonEncode(sorted));
  }

  static Future<void> _storeOrderNotifications(
    SharedPreferences preferences,
    List<OrderRecord> orders,
  ) async {
    final existing = await fetchStoredNotifications();
    final next = [
      ...orders.map(
        (order) => OrderNotificationItem(
          orderId: order.orderId,
          customerName: _orderNotificationCustomerName(order),
          detectedAt: DateTime.now(),
        ),
      ),
      ...existing,
    ];

    final limited = next.take(50).map((item) => item.toJson()).toList();
    await preferences.setString(_storedNotificationsKey, jsonEncode(limited));
  }

  static String _orderSignature(OrderRecord order) {
    return [
      order.createdAt?.toIso8601String() ?? '',
      order.totalCost.toStringAsFixed(2),
      order.itemName,
      order.customerName,
      order.companyName,
      order.quantity.toString(),
    ].join('|');
  }

  static String _orderDisplayName(OrderRecord order) {
    final customer = order.customerName.trim();
    if (customer.isNotEmpty) {
      return customer;
    }

    final company = order.companyName.trim();
    if (company.isNotEmpty) {
      return company;
    }

    return order.itemName.trim().isEmpty ? 'A new order' : order.itemName;
  }

  static String _orderNotificationCustomerName(OrderRecord order) {
    final customer = order.customerName.trim();
    if (customer.isNotEmpty) {
      return customer;
    }

    return 'Unknown customer';
  }

  static String _notificationDisplayName({
    required String customerName,
    required String companyName,
    required String itemName,
  }) {
    final customer = customerName.trim();
    if (customer.isNotEmpty) {
      return customer;
    }

    final company = companyName.trim();
    if (company.isNotEmpty) {
      return company;
    }

    final item = itemName.trim();
    if (item.isNotEmpty) {
      return item;
    }

    return 'Unknown customer';
  }

  static bool _setEquals(Set<String> first, Set<String> second) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (final value in first) {
      if (!second.contains(value)) {
        return false;
      }
    }
    return true;
  }
}

class _OrderSyncResult {
  const _OrderSyncResult({
    required this.hasChanges,
    required this.hasNewOrders,
    required this.newOrders,
  });

  final bool hasChanges;
  final bool hasNewOrders;
  final List<OrderRecord> newOrders;
}
