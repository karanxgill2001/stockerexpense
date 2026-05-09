import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order_line_item.dart';
import '../models/order_record.dart';
import '../services/currency_formatter.dart';
import '../services/currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../services/invoice_download_service.dart';
import '../services/order_sync_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import '../widgets/design_loader.dart';
import '../widgets/order_date_range_picker.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryContainer = Color(0xFF004D43);
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _surfaceLowest = Colors.white;
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  late Future<List<OrderRecord>> _ordersFuture;
  DateTimeRange? _selectedDateRange;
  Timer? _orderRefreshTimer;
  final Set<String> _invoiceJobs = <String>{};
  final Map<String, int> _invoiceCountdowns = <String, int>{};
  bool _invoiceLoaderVisible = false;
  String? _invoiceLoaderOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrencySettingsService.changes.addListener(_handleCurrencyChanged);
    _ordersFuture = GoogleSheetService.instance.fetchOrders();
    _startOrderRefreshPolling();
  }

  @override
  void dispose() {
    CurrencySettingsService.changes.removeListener(_handleCurrencyChanged);
    WidgetsBinding.instance.removeObserver(this);
    _orderRefreshTimer?.cancel();
    super.dispose();
  }

  void _handleCurrencyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfOrdersChanged();
    }
  }

  Future<void> _refreshOrders({bool forceRefresh = true}) async {
    final future = GoogleSheetService.instance.fetchOrders(
      forceRefresh: forceRefresh,
    );
    setState(() {
      _ordersFuture = future;
    });
    await future;
  }

  void _startOrderRefreshPolling() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshIfOrdersChanged(),
    );
  }

  Future<void> _refreshIfOrdersChanged() async {
    try {
      final hasChanges = await OrderSyncService.syncForegroundOrders();
      if (!mounted || !hasChanges) {
        return;
      }

      await _refreshOrders();
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: FutureBuilder<List<OrderRecord>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const DesignLoaderView(label: 'Loading orders...');
                }

                if (snapshot.hasError) {
                  return _OrdersErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refreshOrders,
                  );
                }

                final orders = snapshot.data ?? const <OrderRecord>[];
                final filteredOrders = _applyDateFilter(orders);
                final annualRevenue = filteredOrders.fold<double>(
                  0,
                  (sum, order) => sum + order.totalCost,
                );
                final totalVolume = filteredOrders.fold<int>(
                  0,
                  (sum, order) => sum + order.quantity,
                );
                final fulfillment = filteredOrders.isEmpty ? 0.0 : 100.0;

                return RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 120),
                    children: [
                      const _OrdersTopBar(),
                      const SizedBox(height: 28),
                      _RevenueCard(annualRevenue: annualRevenue),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Total Volume',
                              value: '$totalVolume',
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _MetricCard(
                              label: 'Fulfillment',
                              value: '${fulfillment.toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transaction History',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openDateFilter,
                            child: Text(
                              _selectedDateRange == null
                                  ? 'Filter By Date'
                                  : 'Change Filter',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedDateRange != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _surfaceLowest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _outlineVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _formatSelectedRange(_selectedDateRange!),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDateRange = null;
                                });
                              },
                              child: Text(
                                'Clear',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: _primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (filteredOrders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            _selectedDateRange == null
                                ? 'No completed orders yet.'
                                : 'No orders found in the selected date range.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        )
                      else
                        ...filteredOrders.map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _OrderCard(
                              order: order,
                              onTap: () => _showOrderDetails(order),
                              onDownloadInvoice: () => _downloadInvoice(order),
                              isPreparingInvoice: _invoiceJobs.contains(
                                order.orderId,
                              ),
                              countdownSeconds:
                                  _invoiceCountdowns[order.orderId],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
        ),
        if (_invoiceLoaderVisible && _invoiceLoaderOrderId != null)
          Positioned.fill(
            child: _InvoicePreparingOverlay(orderId: _invoiceLoaderOrderId!),
          ),
      ],
    );
  }

  void _showOrderDetails(OrderRecord order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(
        order: order,
        onEdit: () => _editOrder(order),
        onDelete: () => _deleteOrder(order),
        onDownloadInvoice: () => _downloadInvoice(order),
        isPreparingInvoice: _invoiceJobs.contains(order.orderId),
        countdownSeconds: _invoiceCountdowns[order.orderId],
      ),
    );
  }

  Future<void> _downloadInvoice(OrderRecord order) async {
    final orderId = order.orderId;
    if (_invoiceJobs.isNotEmpty) {
      return;
    }

    setState(() {
      _invoiceJobs.add(orderId);
      _invoiceCountdowns[orderId] = InvoiceDownloadService.preparationSeconds;
    });
    _startInvoiceCountdown(orderId);
    _showInvoiceLoader(orderId);

    try {
      final file = await InvoiceDownloadService.generateInvoice(order);

      if (!mounted) {
        return;
      }

      setState(() {
        _invoiceJobs.remove(orderId);
        _invoiceCountdowns.remove(orderId);
      });
      _hideInvoiceLoader();

      await Share.shareXFiles(
        [XFile(file.filePath)],
        subject: 'Invoice ${order.orderId}',
        text: 'Invoice ${order.orderId} is ready.',
      );

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Invoice saved and share sheet opened.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _hideInvoiceLoader();
      AppMessage.showError(context, 'Failed to create invoice: $error');
    } finally {
      if (mounted) {
        setState(() {
          _invoiceJobs.remove(orderId);
          _invoiceCountdowns.remove(orderId);
        });
      }

      _hideInvoiceLoader();
    }
  }

  void _showInvoiceLoader(String orderId) {
    if (_invoiceLoaderVisible || !mounted) {
      return;
    }

    setState(() {
      _invoiceLoaderVisible = true;
      _invoiceLoaderOrderId = orderId;
    });
  }

  void _hideInvoiceLoader() {
    if (!_invoiceLoaderVisible || !mounted) {
      return;
    }

    setState(() {
      _invoiceLoaderVisible = false;
      _invoiceLoaderOrderId = null;
    });
  }

  void _startInvoiceCountdown(String orderId) {
    Future<void>(() async {
      for (
        var remaining = InvoiceDownloadService.preparationSeconds - 1;
        remaining >= 0;
        remaining--
      ) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted || !_invoiceJobs.contains(orderId)) {
          return;
        }

        setState(() {
          _invoiceCountdowns[orderId] = remaining;
        });
      }
    });
  }

  Future<void> _openDateFilter() async {
    final range = await showOrderDateRangePicker(
      context,
      initialRange: _selectedDateRange,
    );

    if (!mounted || range == null) {
      return;
    }

    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateUtils.dateOnly(range.start),
        end: DateUtils.dateOnly(range.end),
      );
    });
  }

  List<OrderRecord> _applyDateFilter(List<OrderRecord> orders) {
    final range = _selectedDateRange;
    if (range == null) {
      return orders;
    }

    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);

    return orders.where((order) {
      final createdAt = order.createdAt;
      if (createdAt == null) {
        return false;
      }

      final orderDate = DateUtils.dateOnly(createdAt);
      return !orderDate.isBefore(start) && !orderDate.isAfter(end);
    }).toList();
  }

  String _formatSelectedRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    if (DateUtils.isSameDay(start, end)) {
      return 'Showing ${_formatShortDate(start)}';
    }

    return 'Showing ${_formatShortDate(start)} - ${_formatShortDate(end)}';
  }

  String _formatShortDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  Future<void> _editOrder(OrderRecord order) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditOrderDialog(
        order: order,
        onSave:
            ({
              required String companyName,
              required String customerName,
              required String phoneNo,
              required String email,
              required String shippingAddress,
              required double shippingCost,
            }) async {
              await GoogleSheetService.instance.updateOrder(
                orderId: order.orderId,
                companyName: companyName,
                customerName: customerName,
                phoneNo: phoneNo,
                email: email,
                shippingAddress: shippingAddress,
                shippingCost: shippingCost,
              );
            },
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    try {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      AppMessage.showSuccess(context, 'Order updated.');
      await _refreshOrders(forceRefresh: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessage.showError(context, error.toString());
    }
  }

  Future<void> _deleteOrder(OrderRecord order) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isDeleting = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Order'),
              content: Text(
                'Delete ${order.orderId}? Stock will be restored for the deleted order.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          try {
                            await GoogleSheetService.instance.deleteOrder(
                              order.orderId,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop(true);
                          } catch (error) {
                            if (dialogContext.mounted) {
                              AppMessage.showError(
                                dialogContext,
                                error.toString(),
                              );
                            }

                            setDialogState(() {
                              isDeleting = false;
                            });
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.1),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (deleted != true || !mounted) {
      return;
    }

    try {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      AppMessage.showSuccess(context, 'Order deleted.');
      await _refreshOrders(forceRefresh: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessage.showError(context, error.toString());
    }
  }
}

class _OrdersTopBar extends StatelessWidget {
  const _OrdersTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Orders',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _OrdersScreenState._primary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          splashRadius: 20,
          icon: const Icon(
            Icons.search_rounded,
            color: _OrdersScreenState._textSecondary,
            size: 26,
          ),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.annualRevenue});

  final double annualRevenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _OrdersScreenState._primaryContainer,
            _OrdersScreenState._primary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ANNUAL REVENUE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatAmount(annualRevenue),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+12.4% VS LY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _OrdersScreenState._surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _OrdersScreenState._textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _OrdersScreenState._primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onDownloadInvoice,
    required this.isPreparingInvoice,
    required this.countdownSeconds,
  });

  final OrderRecord order;
  final VoidCallback onTap;
  final VoidCallback onDownloadInvoice;
  final bool isPreparingInvoice;
  final int? countdownSeconds;

  @override
  Widget build(BuildContext context) {
    final title = order.companyName.isEmpty
        ? order.itemName
        : order.companyName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: _OrdersScreenState._surfaceLowest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: _OrdersScreenState._textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.formattedDate,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _OrdersScreenState._textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _OrdersScreenState._surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.orderId,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _OrdersScreenState._textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 1,
                color: _OrdersScreenState._outlineVariant.withValues(
                  alpha: 0.18,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _avatarColor(title),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initial(title),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      order.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _OrdersScreenState._textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    order.formattedTotal,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _OrdersScreenState._primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isPreparingInvoice ? null : onDownloadInvoice,
                  style: FilledButton.styleFrom(
                    backgroundColor: _OrdersScreenState._primaryContainer,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isPreparingInvoice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _invoiceActionLabel(
                      isPreparing: isPreparingInvoice,
                      countdownSeconds: countdownSeconds,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'O';
    }
    return trimmed[0].toUpperCase();
  }

  static Color _avatarColor(String seed) {
    const palette = [
      Color(0xFF0D5C50),
      Color(0xFF145C63),
      Color(0xFF3CA9A0),
      Color(0xFF326B62),
      Color(0xFF257C74),
    ];

    return palette[seed.length % palette.length];
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({
    required this.order,
    required this.onEdit,
    required this.onDelete,
    required this.onDownloadInvoice,
    required this.isPreparingInvoice,
    required this.countdownSeconds,
  });

  final OrderRecord order;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDownloadInvoice;
  final bool isPreparingInvoice;
  final int? countdownSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customerTitle = order.customerName.isEmpty
        ? (order.companyName.isEmpty ? 'Customer Details' : order.companyName)
        : order.customerName;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _OrdersScreenState._surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _OrdersScreenState._outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isPreparingInvoice ? null : onDownloadInvoice,
                  icon: isPreparingInvoice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.1),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _invoiceActionLabel(
                      isPreparing: isPreparingInvoice,
                      countdownSeconds: countdownSeconds,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customerTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: _OrdersScreenState._primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _OrdersScreenState._surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.orderId,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _OrdersScreenState._textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.formattedDate,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _OrdersScreenState._textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDelete,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DetailSection(
                title: 'Customer Information',
                children: [
                  _DetailRow(
                    label: 'Customer Name',
                    value: _display(order.customerName),
                  ),
                  _DetailRow(
                    label: 'Company Name',
                    value: _display(order.companyName),
                  ),
                  _DetailRow(label: 'Phone', value: _display(order.phoneNo)),
                  _DetailRow(label: 'Email', value: _display(order.email)),
                  _DetailRow(
                    label: 'Shipping Address',
                    value: _display(order.shippingAddress),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailSection(
                title: 'Ordered Items',
                children: [
                  ...order.items.map((item) => _OrderItemDetailRow(item: item)),
                ],
              ),
              const SizedBox(height: 18),
              _DetailSection(
                title: 'Order Information',
                children: [
                  _DetailRow(
                    label: 'Items Count',
                    value: '${order.items.length}',
                  ),
                  _DetailRow(
                    label: 'Total Quantity',
                    value: '${order.quantity}',
                  ),
                  _DetailRow(
                    label: 'Tax Rate',
                    value: _taxRate(order.taxPercentage),
                  ),
                  _DetailRow(
                    label: 'Tax Amount',
                    value: _currency(order.taxAmount),
                  ),
                  _DetailRow(
                    label: 'Shipping Cost',
                    value: _currency(order.shippingCost),
                  ),
                  _DetailRow(
                    label: 'Total Cost',
                    value: order.formattedTotal,
                    emphasize: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _display(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  static String _currency(double value) => CurrencyFormatter.formatAmount(value);

  static String _taxRate(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)}%';
    }

    return '${value.toStringAsFixed(2)}%';
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _OrdersScreenState._surfaceLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _OrdersScreenState._primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _OrdersScreenState._textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: emphasize
                    ? _OrdersScreenState._primary
                    : _OrdersScreenState._textPrimary,
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemDetailRow extends StatelessWidget {
  const _OrderItemDetailRow({required this.item});

  final OrderLineItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _OrdersScreenState._surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _OrdersScreenState._textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku} • Qty: ${item.quantity}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _OrdersScreenState._textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.formatAmount(item.totalPrice),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _OrdersScreenState._primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditOrderDialog extends StatefulWidget {
  const _EditOrderDialog({required this.order, required this.onSave});

  final OrderRecord order;
  final Future<void> Function({
    required String companyName,
    required String customerName,
    required String phoneNo,
    required String email,
    required String shippingAddress,
    required double shippingCost,
  })
  onSave;

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

String _invoiceActionLabel({
  required bool isPreparing,
  required int? countdownSeconds,
}) {
  if (!isPreparing) {
    return 'Download Invoice';
  }

  final remaining = countdownSeconds ?? 0;
  if (remaining > 0) {
    return 'Preparing Invoice (${remaining}s)';
  }

  return 'Finalizing Invoice...';
}

class _InvoicePreparingOverlay extends StatefulWidget {
  const _InvoicePreparingOverlay({required this.orderId});

  final String orderId;

  @override
  State<_InvoicePreparingOverlay> createState() =>
      _InvoicePreparingOverlayState();
}

class _InvoicePreparingOverlayState extends State<_InvoicePreparingOverlay> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = InvoiceDownloadService.preparationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds <= 0) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        1 - (_remainingSeconds / InvoiceDownloadService.preparationSeconds);

    return Material(
      color: Colors.black.withValues(alpha: 0.52),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF072F29),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _InvoiceOrbitSpinner(),
              const SizedBox(height: 24),
              Text(
                'Preparing Invoice',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gathering customer, item, tax, shipping, and branding details for ${widget.orderId}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _remainingSeconds > 0
                          ? '${_remainingSeconds}s remaining'
                          : 'Finalizing invoice...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF9DE2D1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Timer matches the invoice preparation window',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFCDE6E0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceOrbitSpinner extends StatefulWidget {
  const _InvoiceOrbitSpinner();

  @override
  State<_InvoiceOrbitSpinner> createState() => _InvoiceOrbitSpinnerState();
}

class _InvoiceOrbitSpinnerState extends State<_InvoiceOrbitSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: value * math.pi * 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitDot(
                      radius: 34,
                      angle: 0,
                      color: const Color(0xFF7CF0D0),
                    ),
                    _orbitDot(
                      radius: 34,
                      angle: math.pi * 2 / 3,
                      color: const Color(0xFF3DD4FF),
                    ),
                    _orbitDot(
                      radius: 34,
                      angle: math.pi * 4 / 3,
                      color: const Color(0xFFFFD166),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42 + (math.sin(value * math.pi * 2) * 4),
                height: 42 + (math.sin(value * math.pi * 2) * 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F5C4F), Color(0xFF18A085)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18A085).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orbitDot({
    required double radius,
    required double angle,
    required Color color,
  }) {
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  late final TextEditingController _companyController;
  late final TextEditingController _customerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _shippingCostController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController(text: widget.order.companyName);
    _customerController = TextEditingController(
      text: widget.order.customerName,
    );
    _phoneController = TextEditingController(text: widget.order.phoneNo);
    _emailController = TextEditingController(text: widget.order.email);
    _addressController = TextEditingController(
      text: widget.order.shippingAddress,
    );
    _shippingCostController = TextEditingController(
      text: CurrencyFormatter.formatEditableAmount(widget.order.shippingCost),
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _customerController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _shippingCostController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(
        companyName: _companyController.text.trim(),
        customerName: _customerController.text.trim(),
        phoneNo: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        shippingAddress: _addressController.text.trim(),
        shippingCost: CurrencyFormatter.parseEnteredAmount(
          _shippingCostController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditOrderField(
              controller: _customerController,
              label: 'Customer Name',
            ),
            const SizedBox(height: 12),
            _EditOrderField(
              controller: _companyController,
              label: 'Company Name',
            ),
            const SizedBox(height: 12),
            _EditOrderField(controller: _phoneController, label: 'Phone'),
            const SizedBox(height: 12),
            _EditOrderField(controller: _emailController, label: 'Email'),
            const SizedBox(height: 12),
            _EditOrderField(
              controller: _addressController,
              label: 'Shipping Address',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _EditOrderField(
              controller: _shippingCostController,
              label: 'Shipping Cost',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.1),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _OrdersErrorView extends StatelessWidget {
  const _OrdersErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(message),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _EditOrderField extends StatelessWidget {
  const _EditOrderField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
