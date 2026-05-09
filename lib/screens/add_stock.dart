import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../services/currency_formatter.dart';
import '../services/currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import '../widgets/barcode_scanner_page.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final FocusNode _skuFocusNode = FocusNode();
  List<InventoryItem> _inventoryItems = const [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _skuController.addListener(_handleSkuChanged);
    CurrencySettingsService.changes.addListener(_handleCurrencyChanged);
    _loadInventoryItems();
  }

  @override
  void dispose() {
    CurrencySettingsService.changes.removeListener(_handleCurrencyChanged);
    _skuController.removeListener(_handleSkuChanged);
    _skuFocusNode.dispose();
    _itemNameController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  void _handleCurrencyChanged() {
    if (!mounted) {
      return;
    }

    _applyExistingItemDetails(_skuController.text);
    setState(() {});
  }

  Future<void> _loadInventoryItems() async {
    try {
      final items = await GoogleSheetService.instance.fetchInventory();
      if (!mounted) {
        return;
      }

      setState(() {
        _inventoryItems = items;
      });
      _applyExistingItemDetails(_skuController.text);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inventoryItems = const [];
      });
    }
  }

  void _handleSkuChanged() {
    _applyExistingItemDetails(_skuController.text);
  }

  void _applyExistingItemDetails(String rawSku) {
    final sku = rawSku.trim().toLowerCase();
    if (sku.isEmpty) {
      return;
    }

    InventoryItem? matchedItem;
    for (final item in _inventoryItems) {
      if (item.sku.trim().toLowerCase() == sku) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return;
    }

    final nextItemName = matchedItem.itemName;
    final nextCostPrice = CurrencyFormatter.formatEditableAmount(
      matchedItem.costPrice,
    );

    if (_itemNameController.text != nextItemName) {
      _itemNameController.text = nextItemName;
    }

    if (_costPriceController.text != nextCostPrice) {
      _costPriceController.text = nextCostPrice;
    }
  }

  Future<void> _scanBarcode() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    setState(() {
      _skuController.text = scannedValue.trim();
    });
    _applyExistingItemDetails(scannedValue);
  }

  Future<void> _saveItem() async {
    final itemName = _itemNameController.text.trim();
    final sku = _skuController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final costPrice = CurrencyFormatter.parseEnteredAmount(
      _costPriceController.text,
    );

    if (itemName.isEmpty || sku.isEmpty || quantity < 0) {
      AppMessage.showError(
        context,
        'Enter item name, SKU, and a valid quantity.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await GoogleSheetService.instance.addStock(
        InventoryItem(
          itemName: itemName,
          quantity: quantity,
          initialQuantity: quantity,
          costPrice: costPrice,
          sku: sku,
        ),
      );

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Saved $itemName to the stock sheet.');
      Navigator.pushReplacementNamed(context, '/inventory');
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

  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryContainer = Color(0xFF004D43);
  static const Color _surfaceLow = Color(0xFFF2F4F1);
  static const Color _surfaceLowest = Colors.white;
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outline = Color(0xFF7C8782);
  static const Color _tertiary = Color(0xFF4E2013);
  static const Color _tertiarySoft = Color(0xFFF4ECE7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AddStockTopBar(),
              const SizedBox(height: 34),
              _ScanBarcodeCard(onTap: _scanBarcode),
              const SizedBox(height: 42),
              Text(
                'Item Details',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _AddStockScreenState._primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 22),
              _AddStockField(
                label: 'ITEM NAME',
                hintText: 'e.g. Heritage Leather Satchel',
                controller: _itemNameController,
                filledColor: _AddStockScreenState._surfaceLowest,
                shadowed: true,
              ),
              const SizedBox(height: 18),
              _SkuBarcodeField(
                controller: _skuController,
                focusNode: _skuFocusNode,
                inventoryItems: _inventoryItems,
                onSelected: _applyExistingItemDetails,
                onScanTap: _scanBarcode,
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactMetricField(
                      label: 'INITIAL\nQUANTITY',
                      controller: _quantityController,
                      suffix: 'UNITS',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CompactMetricField(
                      label: 'COST\nPRICE',
                      controller: _costPriceController,
                      suffix: null,
                      prefix: CurrencySettingsService.currentCurrency.symbol,
                      hintText: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: _AddStockScreenState._tertiarySoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x33A07D71)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: _AddStockScreenState._tertiary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stock level warnings will be triggered if inventory falls below 15% of initial quantity.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _AddStockScreenState._tertiary,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _saveItem,
                style: FilledButton.styleFrom(
                  backgroundColor: _AddStockScreenState._primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 0,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 28),
                label: Text(
                  _isSubmitting ? 'Saving...' : 'Save Item',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _AddStockTopBar extends StatelessWidget {
  const _AddStockTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _AddStockScreenState._primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Add Stock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _AddStockScreenState._primary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(
            Icons.notifications,
            color: _AddStockScreenState._primary,
            size: 26,
          ),
        ),
      ],
    );
  }
}

class _ScanBarcodeCard extends StatelessWidget {
  const _ScanBarcodeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _AddStockScreenState._primary,
                _AddStockScreenState._primaryContainer,
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1800342D),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: CustomPaint(painter: _BarcodeStripePainter()),
                  ),
                ),
              ),
              Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Scan Barcode',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quickly capture SKU and product details',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkuBarcodeField extends StatelessWidget {
  const _SkuBarcodeField({
    required this.controller,
    required this.focusNode,
    required this.inventoryItems,
    required this.onSelected,
    required this.onScanTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<InventoryItem> inventoryItems;
  final ValueChanged<String> onSelected;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      decoration: BoxDecoration(
        color: _AddStockScreenState._surfaceLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SKU / BARCODE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _AddStockScreenState._textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RawAutocomplete<InventoryItem>(
                  textEditingController: controller,
                  focusNode: focusNode,
                  displayStringForOption: (option) => option.sku,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return const Iterable<InventoryItem>.empty();
                    }

                    final seenSkus = <String>{};
                    final matches = inventoryItems.where((item) {
                      final sku = item.sku.trim();
                      if (sku.isEmpty) {
                        return false;
                      }

                      final normalizedSku = sku.toLowerCase();
                      if (!seenSkus.add(normalizedSku)) {
                        return false;
                      }

                      return normalizedSku.contains(query) ||
                          item.itemName.trim().toLowerCase().contains(query);
                    }).toList(growable: false)
                      ..sort((left, right) {
                        final leftSku = left.sku.trim().toLowerCase();
                        final rightSku = right.sku.trim().toLowerCase();
                        final leftStarts = leftSku.startsWith(query);
                        final rightStarts = rightSku.startsWith(query);
                        if (leftStarts != rightStarts) {
                          return leftStarts ? -1 : 1;
                        }

                        return leftSku.compareTo(rightSku);
                      });

                    return matches.take(6);
                  },
                  onSelected: (option) {
                    controller.value = TextEditingValue(
                      text: option.sku,
                      selection: TextSelection.collapsed(
                        offset: option.sku.length,
                      ),
                    );
                    onSelected(option.sku);
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    fieldFocusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'EL-2024-001',
                        hintStyle: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFFC7CFCA),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: _AddStockScreenState._textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    );
                  },
                  optionsViewBuilder: (context, onOptionSelected, options) {
                    final optionList = options.toList(growable: false);
                    if (optionList.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 116,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            color: _AddStockScreenState._surfaceLowest,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0x1400342D),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 16,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: optionList.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final option = optionList[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  option.sku,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color:
                                            _AddStockScreenState._textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                subtitle: Text(
                                  option.itemName,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _AddStockScreenState
                                            ._textSecondary,
                                      ),
                                ),
                                onTap: () => onOptionSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onScanTap,
                style: FilledButton.styleFrom(
                  backgroundColor: _AddStockScreenState._primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddStockField extends StatelessWidget {
  const _AddStockField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.filledColor,
    this.shadowed = false,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final Color filledColor;
  final bool shadowed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: shadowed ? const Color(0xFFF1F3F0) : Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        boxShadow: shadowed
            ? const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        decoration: BoxDecoration(
          color: filledColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _AddStockScreenState._textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFC7CFCA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _AddStockScreenState._textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetricField extends StatelessWidget {
  const _CompactMetricField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.hintText,
    this.prefix,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final String hintText;
  final String? prefix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: _AddStockScreenState._surfaceLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _AddStockScreenState._textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (prefix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Text(
                    prefix!,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _AddStockScreenState._outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(
                          color: const Color(0xFFC7CFCA),
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: label == 'COST PRICE'
                        ? _AddStockScreenState._outline
                        : Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _AddStockScreenState._outline,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarcodeStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const stripeWidth = 4.0;
    const gap = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeWidth, size.height), paint);
      x += stripeWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
