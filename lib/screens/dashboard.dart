import 'dart:async';

import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../models/order_record.dart';
import '../services/currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../services/low_stock_alert_service.dart';
import '../services/order_sync_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/design_loader.dart';

import '../services/currency_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const Color _bgColor = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryContainer = Color(0xFF004D43);
  static const Color _secondaryContainer = Color(0xFFCFE6F2);
  static const Color _secondary = Color(0xFF4C616C);
  static const Color _surfaceLow = Color(0xFFF2F4F1);
  static const Color _surfaceLowest = Color(0xFFFFFFFF);
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _outlineVariant = Color(0xFFBFC9C4);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _tertiary = Color(0xFF5E2414);
  static const Color _tertiarySoft = Color(0xFFF4F0EC);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late Future<_DashboardData> _dashboardFuture;
  String? _lastProcessedInventorySignature;
  bool _isShowingLowStockDialog = false;
  Timer? _orderRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrencySettingsService.changes.addListener(_handleCurrencyChanged);
    _dashboardFuture = _loadDashboardData();
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

  Future<_DashboardData> _loadDashboardData({bool forceRefresh = false}) async {
    final results = await Future.wait([
      GoogleSheetService.instance.fetchInventory(forceRefresh: forceRefresh),
      GoogleSheetService.instance.fetchOrders(forceRefresh: forceRefresh),
    ]);

    return _DashboardData(
      inventoryItems: results[0] as List<InventoryItem>,
      orders: results[1] as List<OrderRecord>,
    );
  }

  Future<void> _refreshDashboard() async {
    final future = _loadDashboardData(forceRefresh: true);
    setState(() {
      _dashboardFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardScreen._bgColor,
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const DesignLoaderView(label: 'Loading dashboard...');
            }

            if (snapshot.hasError) {
              return _DashboardErrorView(
                message: snapshot.error.toString(),
                onRetry: _refreshDashboard,
              );
            }

            final data = snapshot.data ?? const _DashboardData.empty();
            _scheduleLowStockAlert(data.inventoryItems);
            return RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 138),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DashboardTopBar(),
                    const SizedBox(height: 28),
                    _HeroValueCard(data: data),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            label: 'Add Stock',
                            icon: Icons.add,
                            backgroundColor: DashboardScreen._primary,
                            foregroundColor: Colors.white,
                            shadowColor: const Color(0x1A00342D),
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, '/add'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _QuickActionButton(
                            label: 'Sell Items',
                            icon: Icons.sell,
                            backgroundColor:
                                DashboardScreen._secondaryContainer,
                            foregroundColor: DashboardScreen._textSecondary,
                            shadowColor: const Color(0x14000000),
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/sell',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _StatsCard(data: data),
                    const SizedBox(height: 22),
                    _CriticalAlertsCard(data: data),
                    const SizedBox(height: 42),
                    Text(
                      'Recent Orders',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DashboardScreen._textPrimary,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 20),
                    if (data.recentOrders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DashboardScreen._surfaceLow,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text(
                          'No order activity yet.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: DashboardScreen._textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      )
                    else
                      ...data.recentOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _MovementTile(
                            title: order.customerName.isNotEmpty
                                ? order.customerName
                                : (order.companyName.isNotEmpty
                                      ? order.companyName
                                      : order.itemName),
                            subtitle: '${order.orderId} • ${order.itemName}',
                            delta: '-${order.quantity}',
                            age: _formatRelativeTime(order.createdAt),
                            icon: Icons.south_west,
                            iconBackground: const Color(0xFF627A88),
                            deltaColor: DashboardScreen._secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  String _formatRelativeTime(DateTime? value) {
    if (value == null) {
      return 'recently';
    }

    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

  void _scheduleLowStockAlert(List<InventoryItem> items) {
    final signature =
        items
            .map(
              (item) =>
                  '${item.sku.trim().toLowerCase()}|${item.itemName.trim().toLowerCase()}|${item.quantity}',
            )
            .toList()
          ..sort();
    final nextSignature = signature.join('||');
    if (_lastProcessedInventorySignature == nextSignature) {
      return;
    }

    _lastProcessedInventorySignature = nextSignature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLowStockAlert(items);
    });
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

      final future = _loadDashboardData(forceRefresh: true);
      setState(() {
        _dashboardFuture = future;
      });
      await future;
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
  }

  Future<void> _checkLowStockAlert(List<InventoryItem> items) async {
    if (!mounted || _isShowingLowStockDialog) {
      return;
    }

    final lowStockItems =
        await LowStockAlertService.consumeLowStockItemsForPopup(items);
    if (!mounted || lowStockItems.isEmpty) {
      return;
    }

    _isShowingLowStockDialog = true;
    unawaited(LowStockAlertService.playAlertSound());

    final lines = lowStockItems
        .map((item) => '• ${item.itemName} (${item.quantity} left)')
        .join('\n');

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _LowStockAlertDialog(
            threshold: InventoryItem.lowStockThreshold,
            summaryLines: lines,
            itemCount: lowStockItems.length,
          );
        },
      );
    } finally {
      _isShowingLowStockDialog = false;
    }
  }
}

class _LowStockAlertDialog extends StatelessWidget {
  const _LowStockAlertDialog({
    required this.threshold,
    required this.summaryLines,
    required this.itemCount,
  });

  final int threshold;
  final String summaryLines;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FFFD), Color(0xFFEAF5F2)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2200342D),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0x14007867),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFF007867),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Low Stock Alert',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF00342D),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount items are at $threshold or less',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4B5C57),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x1400342D)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    summaryLines,
                    style: theme.textTheme.titleMedium?.copyWith(
                      height: 1.55,
                      color: const Color(0xFF20312D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007867),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({required this.inventoryItems, required this.orders});

  const _DashboardData.empty() : inventoryItems = const [], orders = const [];

  final List<InventoryItem> inventoryItems;
  final List<OrderRecord> orders;

  double get totalInventoryValue => inventoryItems.fold<double>(
    0,
    (sum, item) => sum + (item.quantity * item.costPrice),
  );

  int get totalUnits =>
      inventoryItems.fold<int>(0, (sum, item) => sum + item.quantity);

  int get totalSkus => inventoryItems.length;

  int get lowStockCount =>
      inventoryItems.where((item) => item.lowStock || item.outOfStock).length;

  List<InventoryItem> get criticalItems {
    final items =
        inventoryItems
            .where((item) => item.lowStock || item.outOfStock)
            .toList()
          ..sort((a, b) => a.quantity.compareTo(b.quantity));
    return items;
  }

  List<OrderRecord> get recentOrders {
    final items = List<OrderRecord>.from(orders)
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return items.take(3).toList();
  }

  List<_InventoryBarDatum> get chartBars {
    if (inventoryItems.isEmpty) {
      return const [];
    }

    final items = List<InventoryItem>.from(inventoryItems)
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final maxQuantity = items.fold<int>(
      0,
      (max, item) => item.quantity > max ? item.quantity : max,
    );
    if (maxQuantity <= 0) {
      return items
          .map(
            (item) => _InventoryBarDatum(
              itemName: item.itemName,
              quantity: item.quantity,
              height: 30,
            ),
          )
          .toList();
    }

    return items
        .map(
          (item) => _InventoryBarDatum(
            itemName: item.itemName,
            quantity: item.quantity,
            height: 26 + ((item.quantity / maxQuantity) * 74),
          ),
        )
        .toList();
  }
}

class _InventoryBarDatum {
  const _InventoryBarDatum({
    required this.itemName,
    required this.quantity,
    required this.height,
  });

  final String itemName;
  final int quantity;
  final double height;
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: DashboardScreen._primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Dashboard',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: DashboardScreen._primary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          splashRadius: 22,
          icon: const Icon(
            Icons.notifications,
            color: Color(0xFF5CA899),
            size: 26,
          ),
        ),
      ],
    );
  }
}

class _HeroValueCard extends StatelessWidget {
  const _HeroValueCard({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DashboardScreen._primary, DashboardScreen._primaryContainer],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C00342D),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL INVENTORY VALUE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w500,
              letterSpacing: 3.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            CurrencyFormatter.formatAmount(data.totalInventoryValue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${data.totalSkus} SKUs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${data.totalUnits} total units currently in stock',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.shadowColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: foregroundColor == Colors.white
                      ? Colors.white
                      : foregroundColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 18,
                  color: foregroundColor == Colors.white
                      ? DashboardScreen._primary
                      : foregroundColor,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
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

class _StatsCard extends StatefulWidget {
  const _StatsCard({required this.data});

  final _DashboardData data;

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  int _selectedBarIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chartBars = widget.data.chartBars;
    final hasBars = chartBars.isNotEmpty;
    final safeIndex = hasBars
        ? _selectedBarIndex.clamp(0, chartBars.length - 1)
        : 0;
    final selectedBar = hasBars ? chartBars[safeIndex] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: DashboardScreen._surfaceLowest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL ITEMS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: DashboardScreen._textPrimary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.data.totalUnits}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: DashboardScreen._primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DashboardScreen._surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.inventory_2,
                  color: DashboardScreen._primary,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (selectedBar != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: DashboardScreen._surfaceLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: DashboardScreen._primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedBar.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DashboardScreen._textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${selectedBar.quantity} left',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: DashboardScreen._primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _MiniBarChart(
            bars: chartBars,
            selectedIndex: safeIndex,
            onSelect: (index) {
              setState(() {
                _selectedBarIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.bars,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_InventoryBarDatum> bars;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFD0D9DA),
      Color(0xFFB5C5C6),
      Color(0xFF89A19D),
      DashboardScreen._primary,
      Color(0xFF3E6C66),
      Color(0xFF76958F),
    ];

    if (bars.isEmpty) {
      return Container(
        height: 132,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DashboardScreen._surfaceLow,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          'No inventory bars yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: DashboardScreen._textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return SizedBox(
      height: 156,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(bars.length, (index) {
            final bar = bars[index];
            final isSelected = index == selectedIndex;
            final barColor = isSelected
                ? DashboardScreen._primary
                : colors[index % colors.length];
            final quantityColor =
                ThemeData.estimateBrightnessForColor(barColor) ==
                    Brightness.dark
                ? Colors.white
                : DashboardScreen._textPrimary;

            return Padding(
              padding: EdgeInsets.only(
                right: index == bars.length - 1 ? 0 : 10,
              ),
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        height: bar.height,
                        width: 52,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x2600342D),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${bar.quantity}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: quantityColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: DashboardScreen._textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CriticalAlertsCard extends StatefulWidget {
  const _CriticalAlertsCard({required this.data});

  final _DashboardData data;

  @override
  State<_CriticalAlertsCard> createState() => _CriticalAlertsCardState();
}

class _CriticalAlertsCardState extends State<_CriticalAlertsCard> {
  late final PageController _pageController;
  int _currentPage = 0;
  static const int _itemsPerPage = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final criticalItems = data.criticalItems;
    final pageCount = criticalItems.isEmpty
        ? 0
        : (criticalItems.length / _itemsPerPage).ceil();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        color: DashboardScreen._tertiarySoft,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0x22A78B80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DashboardScreen._tertiary,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.lowStockCount} Critical Alerts',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: DashboardScreen._tertiary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Items at ${InventoryItem.lowStockThreshold} units or less',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DashboardScreen._textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (data.criticalItems.isEmpty)
            Text(
              'No low-stock items right now.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DashboardScreen._textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            SizedBox(
              height: 380,
              child: PageView.builder(
                controller: _pageController,
                itemCount: pageCount,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final start = index * _itemsPerPage;
                  final end = (start + _itemsPerPage).clamp(
                    0,
                    criticalItems.length,
                  );
                  final pageItems = criticalItems.sublist(start, end);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        for (
                          var itemIndex = 0;
                          itemIndex < pageItems.length;
                          itemIndex += 1
                        ) ...[
                          _AlertProgressItem(
                            title: pageItems[itemIndex].itemName,
                            remaining: '${pageItems[itemIndex].quantity} left',
                            progress: pageItems[itemIndex].initialQuantity <= 0
                                ? (pageItems[itemIndex].quantity <=
                                          InventoryItem.lowStockThreshold
                                      ? pageItems[itemIndex].quantity /
                                            InventoryItem.lowStockThreshold
                                      : 1)
                                : (pageItems[itemIndex].quantity /
                                          pageItems[itemIndex].initialQuantity)
                                      .clamp(0, 1),
                          ),
                          if (itemIndex != pageItems.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            if (pageCount > 1) ...[
              const SizedBox(height: 14),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(pageCount, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(
                        right: index == pageCount - 1 ? 0 : 8,
                      ),
                      width: isActive ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? DashboardScreen._tertiary
                            : DashboardScreen._outlineVariant.withValues(
                                alpha: 0.65,
                              ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/inventory'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: DashboardScreen._tertiary,
            ),
            label: Text(
              'REVIEW INVENTORY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: DashboardScreen._tertiary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AlertProgressItem extends StatelessWidget {
  const _AlertProgressItem({
    required this.title,
    required this.remaining,
    required this.progress,
  });

  final String title;
  final String remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DashboardScreen._textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                remaining,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DashboardScreen._tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress.clamp(0, 1),
              backgroundColor: DashboardScreen._outlineVariant.withValues(
                alpha: 0.35,
              ),
              valueColor: const AlwaysStoppedAnimation<Color>(
                DashboardScreen._tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.title,
    required this.subtitle,
    required this.delta,
    required this.age,
    required this.icon,
    required this.iconBackground,
    required this.deltaColor,
  });

  final String title;
  final String subtitle;
  final String delta;
  final String age;
  final IconData icon;
  final Color iconBackground;
  final Color deltaColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: DashboardScreen._surfaceLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DashboardScreen._textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DashboardScreen._textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                delta,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                age,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DashboardScreen._textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({required this.message, required this.onRetry});

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
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(message),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
