import 'package:flutter/material.dart';

import '../models/order_notification_item.dart';
import '../services/order_sync_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<OrderNotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = OrderSyncService.fetchStoredNotifications();
  }

  Future<void> _refresh() async {
    final future = OrderSyncService.fetchStoredNotifications();
    setState(() {
      _notificationsFuture = future;
    });
    await future;
  }

  Future<void> _clearAll() async {
    await OrderSyncService.clearStoredNotifications();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: FutureBuilder<List<OrderNotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final notifications = snapshot.data ?? const [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1200342D),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00342D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF00342D),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Alerts',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF191C1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notifications.isEmpty
                                  ? 'No new orders yet.'
                                  : '${notifications.length} new order notifications saved.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF3F4945),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (notifications.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'New generated orders will appear here with customer names.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF3F4945),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...notifications.map(
                    (notification) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDDE6E1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF5F1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Color(0xFF00342D),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.customerName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF191C1B),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'New order generated',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF3F4945),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatTime(notification.detectedAt),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF6A746F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) {
      return 'now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    return '${difference.inDays}d';
  }
}
