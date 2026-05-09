class EmployeeRecord {
  const EmployeeRecord({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  EmployeeRecord copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return EmployeeRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeRecord(
      id: (json['id'] ?? json['employeeId'] ?? json['employee id'])
              ?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}