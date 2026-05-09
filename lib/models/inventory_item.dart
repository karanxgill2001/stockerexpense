import '../services/currency_formatter.dart';

class InventoryItem {
  static const int lowStockThreshold = 5;

  const InventoryItem({
    required this.itemName,
    required this.quantity,
    required this.initialQuantity,
    required this.costPrice,
    required this.sku,
  });

  final String itemName;
  final int quantity;
  final int initialQuantity;
  final double costPrice;
  final String sku;

  bool get outOfStock => quantity <= 0;

  bool get lowStock {
    if (outOfStock) {
      return false;
    }

    return quantity <= lowStockThreshold;
  }

  String get statusLabel {
    if (outOfStock) {
      return 'Out of Stock';
    }
    if (lowStock) {
      return 'Low Stock';
    }
    return 'In Stock';
  }

  String get formattedPrice => CurrencyFormatter.formatAmount(costPrice);

  InventoryItem mergeWith(InventoryItem other) {
    return InventoryItem(
      itemName: itemName.isNotEmpty ? itemName : other.itemName,
      quantity: quantity + other.quantity,
      initialQuantity: initialQuantity + other.initialQuantity,
      costPrice: costPrice > 0 ? costPrice : other.costPrice,
      sku: sku.isNotEmpty ? sku : other.sku,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'costPrice': costPrice,
      'sku': sku,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemName: (json['itemName'] ?? json['item name'] ?? '').toString(),
      quantity: _toInt(json['quantity'] ?? json['remaining quantity']),
      initialQuantity: _toInt(
        json['initialQuantity'] ?? json['initial quantity'],
      ),
      costPrice: _toDouble(json['costPrice'] ?? json['cost price']),
      sku: (json['sku'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
