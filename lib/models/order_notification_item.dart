class OrderNotificationItem {
  const OrderNotificationItem({
    required this.orderId,
    required this.customerName,
    required this.detectedAt,
  });

  final String orderId;
  final String customerName;
  final DateTime detectedAt;

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'customerName': customerName,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  factory OrderNotificationItem.fromJson(Map<String, dynamic> json) {
    return OrderNotificationItem(
      orderId: (json['orderId'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      detectedAt:
          DateTime.tryParse((json['detectedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
