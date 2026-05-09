class OrderLineItem {
  const OrderLineItem({
    required this.itemName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
  });

  final String itemName;
  final String sku;
  final int quantity;
  final double unitPrice;

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'sku': sku,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      itemName: (json['itemName'] ?? json['item name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unitPrice'] ?? json['unit price']),
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
