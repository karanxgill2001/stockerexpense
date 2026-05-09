import 'dart:convert';

import '../services/currency_formatter.dart';
import 'order_line_item.dart';

class OrderRecord {
  const OrderRecord({
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
    required this.orderId,
    required this.createdAt,
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
  final String orderId;
  final DateTime? createdAt;
  final List<OrderLineItem> items;

  String get formattedTotal => CurrencyFormatter.formatAmount(totalCost);

  String get formattedDate {
    final value = createdAt;
    if (value == null) {
      return 'Recent order';
    }

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

  Map<String, dynamic> toJson() {
    return {
      'company name': companyName,
      'customer name': customerName,
      'phone no': phoneNo,
      'email': email,
      'shipping address': shippingAddress,
      'shipping cost': shippingCost,
      'quantity': quantity,
      'sku': sku,
      'item name': itemName,
      'unit price': unitPrice,
      'tax percentage': taxPercentage,
      'tax amount': taxAmount,
      'total cost': totalCost,
      'order id': orderId,
      'created at': createdAt?.toIso8601String() ?? '',
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory OrderRecord.fromJson(Map<String, dynamic> json, int index) {
    final generatedOrderId = 'ord-${index + 1}';

    return OrderRecord(
      companyName: (json['company name'] ?? '').toString(),
      customerName: (json['customer name'] ?? '').toString(),
      phoneNo: (json['phone no'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      shippingAddress: (json['shipping address'] ?? '').toString(),
      shippingCost: _toDouble(json['shipping cost']),
      quantity: _toInt(json['quantity']),
      sku: (json['sku'] ?? '').toString(),
      itemName: (json['item name'] ?? '').toString(),
      unitPrice: _toDouble(json['unit price']),
      taxPercentage: _toDouble(json['tax percentage']),
      taxAmount: _toDouble(json['tax amount']),
      totalCost: _toDouble(json['total cost']),
      orderId: (json['order id']?.toString().trim().isNotEmpty ?? false)
          ? json['order id'].toString()
          : generatedOrderId,
      createdAt: _toDateTime(json['created at']),
      items: _parseItems(json),
    );
  }

  static List<OrderLineItem> _parseItems(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map(
            (item) => OrderLineItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    if (rawItems is String && rawItems.trim().isNotEmpty) {
      final decoded = jsonDecode(rawItems);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => OrderLineItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    }

    return [
      OrderLineItem(
        itemName: (json['item name'] ?? '').toString(),
        sku: (json['sku'] ?? '').toString(),
        quantity: _toInt(json['quantity']),
        unitPrice: _toDouble(json['unit price']),
      ),
    ];
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

  static DateTime? _toDateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
