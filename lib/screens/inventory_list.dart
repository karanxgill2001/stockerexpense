import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/backend_config_service.dart';
import '../services/currency_formatter.dart';
import '../services/currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import '../widgets/design_loader.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  static const Color _bgColor = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryMuted = Color(0xFF0F4A42);
  static const Color _surfaceCard = Color(0xFFFFFFFF);
  static const Color _surfaceSoft = Color(0xFFF1F4F1);
  static const Color _surfaceTint = Color(0xFFE7EFEB);
  static const Color _outline = Color(0xFFD8E1DC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF53615C);
  static const Color _warning = Color(0xFF9A5200);
  static const Color _warningSoft = Color(0xFFFFF1E2);
  static const Color _danger = Color(0xFFB42318);
  static const Color _dangerSoft = Color(0xFFFFEEEC);

  late Future<List<InventoryItem>> _itemsFuture;
  late Future<bool> _backendConfiguredFuture;
  final TextEditingController _searchController = TextEditingController();
  _InventoryFilter _filter = _InventoryFilter.all;

  @override
  void initState() {
    super.initState();
    _backendConfiguredFuture = BackendConfigService.hasStockGoogleScriptUrl();
    _itemsFuture = _loadItems();
    _searchController.addListener(_onSearchChanged);
    CurrencySettingsService.changes.addListener(_handleCurrencyChanged);
  }

  @override
  void dispose() {
    CurrencySettingsService.changes.removeListener(_handleCurrencyChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleCurrencyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<List<InventoryItem>> _loadItems({bool forceRefresh = false}) async {
    if (!await BackendConfigService.hasStockGoogleScriptUrl()) {
      return const [];
    }

    return GoogleSheetService.instance.fetchInventory(
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refreshItems({bool forceRefresh = true}) async {
    final backendConfiguredFuture =
        BackendConfigService.hasStockGoogleScriptUrl();
    final future = _loadItems(forceRefresh: forceRefresh);
    setState(() {
      _backendConfiguredFuture = backendConfiguredFuture;
      _itemsFuture = future;
    });
    await future;
  }

  void _onSearchChanged() {
    setState(() {});
  }

  String _inventoryAlertTitle({
    required int totalItems,
    required int lowStockItems,
    required int outOfStockItems,
  }) {
    if (totalItems == 0) {
      return 'No inventory added yet.';
    }

    if (outOfStockItems == totalItems) {
      return 'All items are out of stock.';
    }

    if (outOfStockItems > 0 && lowStockItems > 0) {
      return '$outOfStockItems items are out of stock.';
    }

    if (outOfStockItems > 0) {
      return '$outOfStockItems items are out of stock.';
    }

    if (lowStockItems > 0) {
      return '$lowStockItems items need attention.';
    }

    return 'Inventory looks healthy.';
  }

  String _inventoryAlertBody({
    required int totalItems,
    required int lowStockItems,
    required int outOfStockItems,
  }) {
    if (totalItems == 0) {
      return 'Add stock items to start tracking availability.';
    }

    if (outOfStockItems == totalItems) {
      return 'Every catalog item is currently unavailable and needs restocking.';
    }

    if (outOfStockItems > 0 && lowStockItems > 0) {
      return '$lowStockItems other item${lowStockItems == 1 ? '' : 's'} ${lowStockItems == 1 ? 'is' : 'are'} also running low.';
    }

    if (outOfStockItems > 0) {
      return 'Restock unavailable items to start selling them again.';
    }

    if (lowStockItems > 0) {
      return 'Items at ${InventoryItem.lowStockThreshold} units or less should be reviewed soon.';
    }

    return 'No items are currently at ${InventoryItem.lowStockThreshold} units or less.';
  }

  Future<void> _openStockDetails(InventoryItem item) async {
    final action = await showModalBottomSheet<_InventoryItemActionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InventoryItemDetailsSheet(item: item),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action.type) {
      case _InventoryItemActionType.edit:
        await _editItem(item);
        break;
      case _InventoryItemActionType.delete:
        await _deleteItem(item);
        break;
    }
  }

  Future<void> _editItem(InventoryItem originalItem) async {
    final updatedItem = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => _EditInventoryItemDialog(
        item: originalItem,
        onSave: (updatedItem) async {
          await GoogleSheetService.instance.updateStock(
            currentItemName: originalItem.itemName,
            currentSku: originalItem.sku,
            item: updatedItem,
          );
        },
      ),
    );

    if (!mounted || updatedItem == null) {
      return;
    }

    try {
      await _refreshItems(forceRefresh: false);
      if (!mounted) {
        return;
      }
      AppMessage.showSuccess(
        context,
        '${updatedItem.itemName} updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessage.showError(context, error.toString());
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isDeleting = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Stock Item'),
              content: Text('Delete ${item.itemName} from the stock sheet?'),
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
                            await GoogleSheetService.instance.deleteStock(
                              itemName: item.itemName,
                              sku: item.sku,
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
      await _refreshItems(forceRefresh: false);
      if (!mounted) {
        return;
      }
      AppMessage.showSuccess(context, '${item.itemName} deleted successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessage.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00342D),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Inventory',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications),
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _backendConfiguredFuture,
        builder: (context, backendSnapshot) {
          if (backendSnapshot.connectionState == ConnectionState.waiting) {
            return const DesignLoaderView(label: 'Checking backend...');
          }

          if (!(backendSnapshot.data ?? false)) {
            return _SetupRequiredView(onRetry: _refreshItems);
          }

          return FutureBuilder<List<InventoryItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const DesignLoaderView(label: 'Loading inventory...');
              }

              if (snapshot.hasError) {
                return _InventoryErrorView(
                  message: snapshot.error.toString(),
                  onRetry: _refreshItems,
                );
              }

              final allItems = snapshot.data ?? const [];
              final items = _applyFilters(allItems);
              final lowStockItems = allItems
                  .where((item) => item.lowStock)
                  .length;
              final outOfStockItems = allItems
                  .where((item) => item.outOfStock)
                  .length;
              final hasOutOfStockItems = outOfStockItems > 0;
              final bannerBackground = hasOutOfStockItems
                  ? _dangerSoft
                  : _warningSoft;
              final bannerBorder = hasOutOfStockItems
                  ? const Color(0xFFF7C9C3)
                  : const Color(0xFFFFD8B0);
              final bannerAccent = hasOutOfStockItems ? _danger : _warning;

              return RefreshIndicator(
                onRefresh: _refreshItems,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                  children: [
                    Text(
                      'STOCK OVERVIEW',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Stock Portfolio',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InventoryHeroCard(
                      totalItems: allItems.length,
                      lowStockItems: lowStockItems,
                      outOfStockItems: outOfStockItems,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: bannerBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: bannerBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: bannerAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              hasOutOfStockItems
                                  ? Icons.error_outline_rounded
                                  : Icons.warning_amber_rounded,
                              color: bannerAccent,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _inventoryAlertTitle(
                                    totalItems: allItems.length,
                                    lowStockItems: lowStockItems,
                                    outOfStockItems: outOfStockItems,
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: bannerAccent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _inventoryAlertBody(
                                    totalItems: allItems.length,
                                    lowStockItems: lowStockItems,
                                    outOfStockItems: outOfStockItems,
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: bannerAccent,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: _surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _outline),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1000342D),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _textSecondary,
                          ),
                          hintText: 'Search catalog by name or SKU...',
                          hintStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: _primaryMuted,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(
                            context,
                            label: 'All Items',
                            filter: _InventoryFilter.all,
                          ),
                          const SizedBox(width: 10),
                          _filterChip(
                            context,
                            label: 'Low Stock',
                            filter: _InventoryFilter.lowStock,
                          ),
                          const SizedBox(width: 10),
                          _filterChip(
                            context,
                            label: 'Out of Stock',
                            filter: _InventoryFilter.outOfStock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _surfaceCard,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: _outline),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1200342D),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Text(
                          _searchController.text.trim().isEmpty &&
                                  _filter == _InventoryFilter.all
                              ? 'No items found in the stock sheet.'
                              : 'No items match the current search and filter.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      )
                    else
                      ...items.map((item) => _inventoryItem(item, context)),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.itemName.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query);

      if (!matchesQuery) {
        return false;
      }

      switch (_filter) {
        case _InventoryFilter.all:
          return true;
        case _InventoryFilter.lowStock:
          return item.lowStock;
        case _InventoryFilter.outOfStock:
          return item.outOfStock;
      }
    }).toList();
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required _InventoryFilter filter,
  }) {
    final isSelected = _filter == filter;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: isSelected
            ? const LinearGradient(colors: [_primary, _primaryMuted])
            : null,
        color: isSelected ? null : _surfaceCard,
        border: Border.all(
          color: isSelected ? Colors.transparent : const Color(0xFF8EA09A),
        ),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0x1800342D),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _filter = filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? Colors.white : const Color(0xFF0B7A74),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inventoryItem(InventoryItem item, BuildContext context) {
    final statusColor = item.outOfStock
        ? _danger
        : (item.lowStock ? _warning : _primaryMuted);
    final statusText = item.outOfStock
        ? 'Out of Stock'
        : (item.lowStock
              ? 'Low Stock (${InventoryItem.lowStockThreshold} or less)'
              : 'In Stock');
    final ratio = item.initialQuantity <= 0
        ? (item.quantity <= 0 ? 0.0 : 1.0)
        : (item.quantity / item.initialQuantity).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1200342D),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openStockDetails(item),
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_surfaceSoft, _surfaceTint],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.outOfStock
                          ? Icons.remove_shopping_cart_rounded
                          : Icons.inventory_2_rounded,
                      color: _primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.formattedPrice,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${item.quantity} left',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SKU ${item.sku}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final statusBadge = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            );
                            final initialQuantityText = Text(
                              '${item.initialQuantity} initial',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            );

                            if (constraints.maxWidth < 340) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  statusBadge,
                                  const SizedBox(height: 8),
                                  initialQuantityText,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: statusBadge,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(child: initialQuantityText),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: ratio,
                            backgroundColor: _surfaceTint,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryHeroCard extends StatelessWidget {
  const _InventoryHeroCard({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
  });

  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00342D), Color(0xFF0F4A42)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200342D),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live inventory snapshot',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFFD5E7E1),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalItems active catalog items',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InventoryMetricTile(
                  label: 'Low Stock',
                  value: '$lowStockItems',
                  accent: const Color(0xFFFFD39A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InventoryMetricTile(
                  label: 'Out of Stock',
                  value: '$outOfStockItems',
                  accent: const Color(0xFFFFB4AB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryMetricTile extends StatelessWidget {
  const _InventoryMetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFD5E7E1),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

enum _InventoryItemActionType { edit, delete }

class _InventoryItemActionResult {
  const _InventoryItemActionResult(this.type);

  final _InventoryItemActionType type;
}

class _InventoryItemDetailsSheet extends StatelessWidget {
  const _InventoryItemDetailsSheet({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = item.outOfStock
        ? theme.colorScheme.error
        : (item.lowStock ? Colors.orange : theme.colorScheme.primary);
    final statusText = item.outOfStock
        ? 'Out of Stock'
        : (item.lowStock
              ? 'Low Stock (${InventoryItem.lowStockThreshold} or less)'
              : 'In Stock');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.itemName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _DetailRow(label: 'SKU', value: item.sku),
            _DetailRow(label: 'Remaining Quantity', value: '${item.quantity}'),
            _DetailRow(
              label: 'Initial Quantity',
              value: '${item.initialQuantity}',
            ),
            _DetailRow(label: 'Cost Price', value: item.formattedPrice),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      const _InventoryItemActionResult(
                        _InventoryItemActionType.delete,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      const _InventoryItemActionResult(
                        _InventoryItemActionType.edit,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditInventoryItemDialog extends StatefulWidget {
  const _EditInventoryItemDialog({required this.item, required this.onSave});

  final InventoryItem item;
  final Future<void> Function(InventoryItem item) onSave;

  @override
  State<_EditInventoryItemDialog> createState() =>
      _EditInventoryItemDialogState();
}

class _EditInventoryItemDialogState extends State<_EditInventoryItemDialog> {
  late final TextEditingController _itemNameController;
  late final TextEditingController _skuController;
  late final TextEditingController _quantityController;
  late final TextEditingController _initialQuantityController;
  late final TextEditingController _costPriceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(text: widget.item.itemName);
    _skuController = TextEditingController(text: widget.item.sku);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _initialQuantityController = TextEditingController(
      text: widget.item.initialQuantity.toString(),
    );
    _costPriceController = TextEditingController(
      text: CurrencyFormatter.formatEditableAmount(widget.item.costPrice),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _initialQuantityController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final itemName = _itemNameController.text.trim();
    final sku = _skuController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    final initialQuantity = int.tryParse(
      _initialQuantityController.text.trim(),
    );
    final costPrice = CurrencyFormatter.parseEnteredAmount(
      _costPriceController.text,
    );

    if (itemName.isEmpty ||
        sku.isEmpty ||
        quantity == null ||
        initialQuantity == null) {
      AppMessage.showError(
        context,
        'Enter item name, SKU, quantity, and initial quantity.',
      );
      return;
    }

    if (quantity < 0 || initialQuantity < 0) {
      AppMessage.showError(context, 'Quantities cannot be negative.');
      return;
    }

    final updatedItem = InventoryItem(
      itemName: itemName,
      quantity: quantity,
      initialQuantity: initialQuantity,
      costPrice: costPrice,
      sku: sku,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(updatedItem);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedItem);
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

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Stock Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: _decoration('Item Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skuController,
              decoration: _decoration('SKU'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Remaining Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initialQuantityController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Initial Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration('Cost Price'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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

enum _InventoryFilter { all, lowStock, outOfStock }

class _SetupRequiredView extends StatelessWidget {
  const _SetupRequiredView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Google Sheets is not configured yet. Set GOOGLE_SCRIPT_URL to your Apps Script web app URL, then reopen the app.',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _InventoryErrorView extends StatelessWidget {
  const _InventoryErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
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
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
