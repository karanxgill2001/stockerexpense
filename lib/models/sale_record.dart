import 'order_line_item.dart';

class SaleRecord {
  const SaleRecord({
    required this.companyName,
    required this.customerName,
    required this.phoneNo,
    required this.email,
    required this.shippingAddress,
    required this.shippingCost,
    required this.quantity,
    required this.sku,
    required this.itemName,
    required this.unitPrice,
    required this.taxPercentage,
    required this.taxAmount,
    required this.totalCost,
    required this.items,
  });

  final String companyName;
  final String customerName;
  final String phoneNo;
  final String email;
  final String shippingAddress;
  final double shippingCost;
  final int quantity;
  final String sku;
  final String itemName;
  final double unitPrice;
  final double taxPercentage;
  final double taxAmount;
  final double totalCost;
  final List<OrderLineItem> items;

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'customerName': customerName,
      'phoneNo': phoneNo,
      'email': email,
      'shippingAddress': shippingAddress,
      'shippingCost': shippingCost,
      'quantity': quantity,
      'sku': sku,
      'itemName': itemName,
      'unitPrice': unitPrice,
      'taxPercentage': taxPercentage,
      'taxAmount': taxAmount,
      'totalCost': totalCost,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
