enum FinanceEntryType { expense, salary, credit, balance }

extension FinanceEntryTypePresentation on FinanceEntryType {
  String get storageValue {
    switch (this) {
      case FinanceEntryType.expense:
        return 'expense';
      case FinanceEntryType.salary:
        return 'salary';
      case FinanceEntryType.credit:
        return 'credit';
      case FinanceEntryType.balance:
        return 'balance';
    }
  }

  String get label {
    switch (this) {
      case FinanceEntryType.expense:
        return 'Expense';
      case FinanceEntryType.salary:
        return 'Salary';
      case FinanceEntryType.credit:
        return 'Credit';
      case FinanceEntryType.balance:
        return 'Balance';
    }
  }

  static FinanceEntryType fromStorage(String? value) {
    return FinanceEntryType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => FinanceEntryType.expense,
    );
  }
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.displayAmount,
    required this.currencyCode,
    required this.occurredOn,
    required this.createdAt,
    this.employeeName = '',
    this.employeeBreakdown = '',
    this.accountName = '',
    this.accountEmail = '',
    this.note = '',
  });

  final String id;
  final FinanceEntryType type;
  final String title;
  final double amount;
  final double displayAmount;
  final String currencyCode;
  final DateTime occurredOn;
  final DateTime createdAt;
  final String employeeName;
  final String employeeBreakdown;
  final String accountName;
  final String accountEmail;
  final String note;

  String get occurredOnStorageValue => _formatDateOnly(occurredOn);

  FinanceEntry copyWith({
    String? id,
    FinanceEntryType? type,
    String? title,
    double? amount,
    double? displayAmount,
    String? currencyCode,
    DateTime? occurredOn,
    DateTime? createdAt,
    String? employeeName,
    String? employeeBreakdown,
    String? accountName,
    String? accountEmail,
    String? note,
  }) {
    return FinanceEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      displayAmount: displayAmount ?? this.displayAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      occurredOn: occurredOn ?? this.occurredOn,
      createdAt: createdAt ?? this.createdAt,
      employeeName: employeeName ?? this.employeeName,
      employeeBreakdown: employeeBreakdown ?? this.employeeBreakdown,
      accountName: accountName ?? this.accountName,
      accountEmail: accountEmail ?? this.accountEmail,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entryId': id,
      'type': type.storageValue,
      'title': title,
      'amount': amount,
      'displayAmount': displayAmount,
      'currencyCode': currencyCode,
      'occurredOn': occurredOnStorageValue,
      'createdAt': createdAt.toIso8601String(),
      'employeeName': employeeName,
      'employee name': employeeName,
      'employeeBreakdown': employeeBreakdown,
      'employee breakdown': employeeBreakdown,
      'accountName': accountName,
      'name': accountName,
      'accountEmail': accountEmail,
      'note': note,
    };
  }

  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    final amountValue = _toDouble(json['amount']);
    final rawDisplayAmount = json['displayAmount'] ?? json['display amount'];
    final displayAmount = _toDouble(rawDisplayAmount);
    final storedAmount = displayAmount == 0 ? amountValue : displayAmount;
    final rawCurrencyCode =
        (json['currencyCode'] ?? json['currency code'])?.toString() ?? '';
    final rawCreatedAt =
        (json['createdAt'] ?? json['created at'])?.toString() ?? '';

    return FinanceEntry(
      id: (json['id'] ?? json['entry id'] ?? json['entryId'])?.toString() ?? '',
      type: FinanceEntryTypePresentation.fromStorage(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      amount: storedAmount,
      displayAmount: storedAmount,
      currencyCode: _normalizeCurrencyCode(rawCurrencyCode),
      occurredOn: _parseOccurredOn(
        (json['occurredOn'] ?? json['occurred on'])?.toString(),
      ),
      createdAt: _parseCreatedAt(
        createdAtValue: rawCreatedAt,
        legacyCurrencyValue: rawCurrencyCode,
      ),
      employeeName:
          (json['employeeName'] ?? json['employee name'])?.toString() ?? '',
        employeeBreakdown:
          (json['employeeBreakdown'] ?? json['employee breakdown'])
            ?.toString() ??
          '',
      accountName:
          (json['accountName'] ?? json['name'])?.toString() ?? '',
      accountEmail:
          (json['accountEmail'] ?? json['account email'])?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseCreatedAt({
    required String createdAtValue,
    required String legacyCurrencyValue,
  }) {
    final normalizedCreatedAt = createdAtValue.trim();
    final parsedCreatedAt = DateTime.tryParse(normalizedCreatedAt);
    if (parsedCreatedAt != null) {
      return parsedCreatedAt;
    }

    final normalizedLegacyCurrency = legacyCurrencyValue.trim();
    final parsedLegacyCreatedAt = DateTime.tryParse(normalizedLegacyCurrency);
    if (parsedLegacyCreatedAt != null) {
      return parsedLegacyCreatedAt;
    }

    return DateTime.now();
  }

  static String _normalizeCurrencyCode(String rawValue) {
    final normalized = rawValue.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      return normalized;
    }

    return 'USD';
  }

  static DateTime _parseOccurredOn(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (dateOnlyMatch != null) {
      return DateTime(
        int.parse(dateOnlyMatch.group(1)!),
        int.parse(dateOnlyMatch.group(2)!),
        int.parse(dateOnlyMatch.group(3)!),
      );
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateTime(local.year, local.month, local.day);
  }

  static String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
