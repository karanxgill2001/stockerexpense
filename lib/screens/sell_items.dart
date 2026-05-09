import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../models/order_line_item.dart';
import '../models/sale_record.dart';
import '../services/currency_formatter.dart';
import '../services/currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../services/order_sync_service.dart';
import '../services/tax_settings_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import '../widgets/barcode_scanner_page.dart';

class SellItemsScreen extends StatefulWidget {
  const SellItemsScreen({super.key});

  @override
  State<SellItemsScreen> createState() => _SellItemsScreenState();
}

class _SellItemsScreenState extends State<SellItemsScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _unitPriceController = TextEditingController(
    text: '0.00',
  );
  List<InventoryItem> _inventoryItems = const [];
  List<InventoryItem> _filteredItems = const [];
  List<OrderLineItem> _orderItems = const [];
  InventoryItem? _selectedItem;
  bool _isLoadingInventory = true;
  bool _isSubmitting = false;
  String? _inventoryError;
  double _taxPercentage = 0;

  @override
  void initState() {
    super.initState();
    _shippingCostController.addListener(_rebuildTotals);
    _quantityController.addListener(_rebuildTotals);
    _unitPriceController.addListener(_rebuildTotals);
    CurrencySettingsService.changes.addListener(_handleCurrencyChanged);
    _loadInventory();
    _loadTaxPercentage();
  }

  @override
  void dispose() {
    CurrencySettingsService.changes.removeListener(_handleCurrencyChanged);
    _shippingCostController.removeListener(_rebuildTotals);
    _quantityController.removeListener(_rebuildTotals);
    _unitPriceController.removeListener(_rebuildTotals);
    _companyNameController.dispose();
    _customerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _shippingAddressController.dispose();
    _shippingCostController.dispose();
    _itemNameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  void _handleCurrencyChanged() {
    if (!mounted) {
      return;
    }

    final selectedItem = _selectedItem;
    if (selectedItem != null) {
      _unitPriceController.text = CurrencyFormatter.formatEditableAmount(
        selectedItem.costPrice,
      );
    }

    setState(() {});
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoadingInventory = true;
      _inventoryError = null;
    });

    try {
      final items = await GoogleSheetService.instance.fetchInventory();
      if (!mounted) {
        return;
      }

      setState(() {
        _inventoryItems = items;
        _filteredItems = const [];
        _isLoadingInventory = false;
      });
      _syncSelectedItem();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inventoryItems = const [];
        _isLoadingInventory = false;
        _inventoryError = error.toString();
      });
    }
  }

  Future<void> _loadTaxPercentage() async {
    final localTaxPercentage =
        await TaxSettingsService.getStoredTaxPercentage();
    if (mounted) {
      setState(() {
        _taxPercentage = localTaxPercentage;
      });
    }

    final syncedTaxPercentage =
        await TaxSettingsService.syncTaxPercentageFromServer();
    if (!mounted) {
      return;
    }

    setState(() {
      _taxPercentage = syncedTaxPercentage;
    });
  }

  void _rebuildTotals() {
    setState(() {});
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;
  double get _shippingCost =>
      CurrencyFormatter.parseEnteredAmount(_shippingCostController.text);
  double get _unitPrice =>
      CurrencyFormatter.parseEnteredAmount(_unitPriceController.text);
  double get _subtotal =>
      _orderItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
  double get _taxAmount => _subtotal * (_taxPercentage / 100);
  double get _totalCost => _subtotal + _taxAmount + _shippingCost;

  static const String _inventoryBarcodeNotFoundMessage =
      'This item is not in your inventory.';

  String get _taxLabel {
    if (_taxPercentage == _taxPercentage.roundToDouble()) {
      return 'CALCULATED TAX (${_taxPercentage.toStringAsFixed(0)}%)';
    }

    return 'CALCULATED TAX (${_taxPercentage.toStringAsFixed(2)}%)';
  }

  Future<void> _scanBarcode() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    _barcodeController.text = scannedValue.trim();
    final matched = await _handleBarcodeChanged(scannedValue.trim());
    if (!mounted || matched) {
      return;
    }

    AppMessage.showError(context, _inventoryBarcodeNotFoundMessage);
  }

  void _handleItemQueryChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredItems = const [];
        _selectedItem = _findInventoryItemBySku(_barcodeController.text.trim());
      });
      return;
    }

    final exactMatch = _findInventoryItemByName(value.trim());
    if (exactMatch != null) {
      _applySelectedItem(exactMatch);
      return;
    }

    setState(() {
      _filteredItems = _inventoryItems
          .where(
            (item) =>
                item.itemName.toLowerCase().contains(query) ||
                item.sku.toLowerCase().contains(query),
          )
          .take(6)
          .toList();
    });
  }

  Future<bool> _handleBarcodeChanged(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _selectedItem = null;
        _filteredItems = const [];
      });
      return false;
    }

    final match = _findInventoryItemBySku(trimmed);
    if (match != null) {
      _applySelectedItem(match);
      return true;
    }

    try {
      final refreshedItems = await GoogleSheetService.instance.fetchInventory(
        forceRefresh: true,
      );
      if (!mounted) {
        return false;
      }

      setState(() {
        _inventoryItems = refreshedItems;
      });

      final refreshedMatch = _findInventoryItemBySku(trimmed);
      if (refreshedMatch != null) {
        _applySelectedItem(refreshedMatch);
        return true;
      }
    } catch (_) {
      if (!mounted) {
        return false;
      }
    }

    final query = _normalizeSku(trimmed);
    setState(() {
      _selectedItem = null;
      _filteredItems = _inventoryItems
          .where((item) => _normalizeSku(item.sku).contains(query))
          .take(6)
          .toList();
    });

    return false;
  }

  InventoryItem? _findInventoryItemBySku(String sku) {
    final normalized = _normalizeSku(sku);
    if (normalized.isEmpty) {
      return null;
    }

    for (final item in _inventoryItems) {
      if (_normalizeSku(item.sku) == normalized) {
        return item;
      }
    }

    return null;
  }

  String _normalizeSku(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  InventoryItem? _findInventoryItemByName(String itemName) {
    final normalized = itemName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final item in _inventoryItems) {
      if (item.itemName.trim().toLowerCase() == normalized) {
        return item;
      }
    }

    return null;
  }

  void _syncSelectedItem() {
    final bySku = _findInventoryItemBySku(_barcodeController.text);
    if (bySku != null) {
      _applySelectedItem(bySku);
      return;
    }

    final byName = _findInventoryItemByName(_itemNameController.text);
    if (byName != null) {
      _applySelectedItem(byName);
    }
  }

  void _applySelectedItem(InventoryItem item) {
    setState(() {
      _selectedItem = item;
      _itemNameController.text = item.itemName;
      _barcodeController.text = item.sku;
      _unitPriceController.text = CurrencyFormatter.formatEditableAmount(
        item.costPrice,
      );
      _filteredItems = const [];
    });
  }

  String? _validateOrderFields() {
    if (_companyNameController.text.trim().isEmpty) {
      return 'Enter company name before saving the order.';
    }

    final shippingCostText = _shippingCostController.text.trim();
    if (shippingCostText.isNotEmpty &&
        double.tryParse(shippingCostText) == null) {
      return 'Enter a valid shipping cost before saving the order.';
    }

    return null;
  }

  Future<void> _submitOrder() async {
    final validationError = _validateOrderFields();
    if (validationError != null) {
      AppMessage.showError(context, validationError);
      return;
    }

    if (_orderItems.isEmpty) {
      final added = _addCurrentItemToOrder(showMessage: false);
      if (!added) {
        AppMessage.showError(
          context,
          'Add at least one item to the order before checkout.',
        );
        return;
      }
    }

    final orderItems = List<OrderLineItem>.from(_orderItems);
    final totalQuantity = orderItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final firstItem = orderItems.first;
    final itemSummary = orderItems.length == 1
        ? firstItem.itemName
        : '${firstItem.itemName} +${orderItems.length - 1} more';

    setState(() {
      _isSubmitting = true;
    });

    try {
      await GoogleSheetService.instance.addSale(
        SaleRecord(
          companyName: _companyNameController.text.trim(),
          customerName: _customerNameController.text.trim(),
          phoneNo: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          shippingAddress: _shippingAddressController.text.trim(),
          shippingCost: _shippingCost,
          quantity: totalQuantity,
          sku: firstItem.sku,
          itemName: itemSummary,
          unitPrice: firstItem.unitPrice,
          taxPercentage: _taxPercentage,
          taxAmount: _taxAmount,
          totalCost: _totalCost,
          items: orderItems,
        ),
      );

      await OrderSyncService.recordCompletedOrderNotification(
        customerName: _customerNameController.text.trim(),
        companyName: _companyNameController.text.trim(),
        itemName: itemSummary,
      );

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Order saved and stock updated.');
      _resetOrderForm();
      _loadInventory();
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetOrderForm() {
    setState(() {
      _companyNameController.clear();
      _customerNameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _shippingAddressController.clear();
      _shippingCostController.clear();
      _itemNameController.clear();
      _barcodeController.clear();
      _quantityController.text = '1';
      _unitPriceController.text = '0.00';
      _orderItems = const [];
      _selectedItem = null;
      _filteredItems = const [];
    });
  }

  bool _addCurrentItemToOrder({bool showMessage = true}) {
    final itemName = _itemNameController.text.trim();
    final sku = _barcodeController.text.trim();
    final matchedItem =
        _findInventoryItemBySku(sku) ??
        _findInventoryItemByName(itemName) ??
        _selectedItem;

    if (itemName.isEmpty || sku.isEmpty) {
      if (showMessage) {
        AppMessage.showError(
          context,
          'Enter item name and barcode/SKU before adding.',
        );
      }
      return false;
    }

    if (matchedItem == null) {
      if (showMessage) {
        AppMessage.showError(
          context,
          sku.isNotEmpty
              ? _inventoryBarcodeNotFoundMessage
              : 'Select a valid inventory item before adding.',
        );
      }
      return false;
    }

    if (_quantity <= 0) {
      if (showMessage) {
        AppMessage.showError(
          context,
          'Enter a valid quantity greater than zero.',
        );
      }
      return false;
    }

    final reservedQuantity = _reservedQuantityForSku(matchedItem.sku);
    final availableToAdd = matchedItem.quantity - reservedQuantity;
    if (_quantity > availableToAdd) {
      if (showMessage) {
        AppMessage.showError(
          context,
          'Only $availableToAdd item(s) left to add for ${matchedItem.itemName}.',
        );
      }
      return false;
    }

    final newLineItem = OrderLineItem(
      itemName: matchedItem.itemName,
      sku: matchedItem.sku,
      quantity: _quantity,
      unitPrice: _unitPrice,
    );

    setState(() {
      final updatedItems = List<OrderLineItem>.from(_orderItems);
      final existingIndex = updatedItems.indexWhere(
        (item) =>
            item.sku.trim().toLowerCase() ==
            matchedItem.sku.trim().toLowerCase(),
      );

      if (existingIndex == -1) {
        updatedItems.add(newLineItem);
      } else {
        final existing = updatedItems[existingIndex];
        updatedItems[existingIndex] = OrderLineItem(
          itemName: existing.itemName,
          sku: existing.sku,
          quantity: existing.quantity + newLineItem.quantity,
          unitPrice: newLineItem.unitPrice,
        );
      }

      _orderItems = updatedItems;
      _itemNameController.clear();
      _barcodeController.clear();
      _quantityController.text = '1';
      _unitPriceController.text = '0.00';
      _selectedItem = null;
      _filteredItems = const [];
    });

    if (showMessage) {
      AppMessage.showSuccess(
        context,
        '${matchedItem.itemName} added to order.',
      );
    }
    return true;
  }

  int _reservedQuantityForSku(String sku) {
    final normalizedSku = sku.trim().toLowerCase();
    return _orderItems
        .where((item) => item.sku.trim().toLowerCase() == normalizedSku)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  void _removeOrderItem(OrderLineItem item) {
    setState(() {
      _orderItems = _orderItems
          .where((entry) => entry.sku != item.sku)
          .toList();
    });
  }

  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceHigh = Color(0xFFE7E9E6);
  static const Color _surfaceSection = Color(0xFFF1F3F1);
  static const Color _surfaceCard = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 124),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SellTopBar(onScanTap: _scanBarcode),
              const SizedBox(height: 26),
              Text(
                'NEW TRANSACTION',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sell Items',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 34),
              if (_isLoadingInventory)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: LinearProgressIndicator(),
                ),
              if (_inventoryError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_inventoryError!),
                ),
                const SizedBox(height: 20),
              ],
              const _SectionTitle(title: 'Customer Details'),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'COMPANY NAME',
                hintText: 'e.g. Sterling Exports',
                controller: _companyNameController,
              ),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'CUSTOMER NAME',
                hintText: 'Legal Representative',
                controller: _customerNameController,
              ),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'PHONE NUMBER',
                hintText: '+1 (555) 000-0000',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'EMAIL ADDRESS',
                hintText: 'billing@company.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 34),
              const _SectionTitle(title: 'Shipping'),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'SHIPPING ADDRESS',
                hintText: 'Full delivery destination',
                controller: _shippingAddressController,
              ),
              const SizedBox(height: 18),
              _SellInputField(
                label: 'SHIPPING COST',
                hintText: CurrencyFormatter.currencyHint(),
                controller: _shippingCostController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 34),
              const _SectionTitle(title: 'Item Entry'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: _surfaceSection,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  children: [
                    _ItemEntryField(
                      label: 'ITEM NAME',
                      hintText: 'Search or enter SKU',
                      controller: _itemNameController,
                      onChanged: _handleItemQueryChanged,
                    ),
                    if (_filteredItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InventorySuggestions(
                        items: _filteredItems,
                        onSelect: _applySelectedItem,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _BarcodeEntryRow(
                      controller: _barcodeController,
                      onChanged: _handleBarcodeChanged,
                      onScanTap: _scanBarcode,
                    ),
                    const SizedBox(height: 18),
                    _ItemEntryField(
                      label: 'QUANTITY',
                      hintText: '1',
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _rebuildTotals(),
                    ),
                    const SizedBox(height: 18),
                    _ItemEntryField(
                      label: 'UNIT PRICE',
                      hintText: CurrencyFormatter.currencyHint(),
                      controller: _unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _rebuildTotals(),
                    ),
                    if (_selectedItem != null) ...[
                      const SizedBox(height: 16),
                      _SelectedInventoryInfo(item: _selectedItem!),
                    ],
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isLoadingInventory || _isSubmitting
                            ? null
                            : () => _addCurrentItemToOrder(),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Item'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_orderItems.isNotEmpty) ...[
                const SizedBox(height: 18),
                _OrderItemsPreview(
                  items: _orderItems,
                  onRemove: _removeOrderItem,
                ),
              ],
              const SizedBox(height: 34),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                decoration: BoxDecoration(
                  color: _surfaceCard,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    _summaryRow(
                      context,
                      'SUBTOTAL',
                      CurrencyFormatter.formatAmount(_subtotal),
                    ),
                    const SizedBox(height: 18),
                    _summaryRow(
                      context,
                      _taxLabel,
                      CurrencyFormatter.formatAmount(_taxAmount),
                    ),
                    const SizedBox(height: 18),
                    _summaryRow(
                      context,
                      'SHIPPING',
                      CurrencyFormatter.formatAmount(_shippingCost),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: _outlineVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'TOTAL AMOUNT',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatAmount(_totalCost),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: _primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting) ...[
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _isSubmitting ? 'Saving Order...' : 'Complete Order',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 26),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Finalizing this order will update the master ledger and generate a printable manifest.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Text(
          amount,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SellTopBar extends StatelessWidget {
  const _SellTopBar({required this.onScanTap});

  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Checkout',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _SellItemsScreenState._primary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onScanTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(
            Icons.qr_code_scanner_rounded,
            color: _SellItemsScreenState._primary,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _SellItemsScreenState._outlineVariant.withValues(
              alpha: 0.35,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _SellItemsScreenState._textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _SellInputField extends StatelessWidget {
  const _SellInputField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _SellItemsScreenState._textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _SellItemsScreenState._surfaceHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintText: hintText,
              hintStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF818885)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemEntryField extends StatelessWidget {
  const _ItemEntryField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _SellItemsScreenState._textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintText: hintText,
              hintStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF818885)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarcodeEntryRow extends StatelessWidget {
  const _BarcodeEntryRow({
    required this.controller,
    required this.onChanged,
    required this.onScanTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BARCODE IDENTIFICATION',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _SellItemsScreenState._textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    hintText: 'SCAN_ID_0000',
                    hintStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: const Color(0xFF818885)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              height: 48,
              child: FilledButton(
                onPressed: onScanTap,
                style: FilledButton.styleFrom(
                  backgroundColor: _SellItemsScreenState._primary,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectedInventoryInfo extends StatelessWidget {
  const _SelectedInventoryInfo({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: _SellItemsScreenState._primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Available: ${item.quantity} • ${item.statusLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _SellItemsScreenState._textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            item.formattedPrice,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: _SellItemsScreenState._primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySuggestions extends StatelessWidget {
  const _InventorySuggestions({required this.items, required this.onSelect});

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return ListTile(
            onTap: () => onSelect(item),
            dense: true,
            title: Text(item.itemName),
            subtitle: Text('SKU: ${item.sku} • Qty: ${item.quantity}'),
            trailing: Text(item.formattedPrice),
          );
        }),
      ),
    );
  }
}

class _OrderItemsPreview extends StatelessWidget {
  const _OrderItemsPreview({required this.items, required this.onRemove});

  final List<OrderLineItem> items;
  final ValueChanged<OrderLineItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _SellItemsScreenState._surfaceSection,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER ITEMS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _SellItemsScreenState._textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _SellItemsScreenState._textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item.sku} • Qty: ${item.quantity}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _SellItemsScreenState._textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.formatAmount(item.totalPrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _SellItemsScreenState._primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(item),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
