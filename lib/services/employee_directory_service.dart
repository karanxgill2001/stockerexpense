import 'package:flutter/foundation.dart';

import '../models/employee_record.dart';
import 'google_sheet_service.dart';

class EmployeeDirectoryService {
  EmployeeDirectoryService._();

  static final ValueNotifier<int> _changeCounter = ValueNotifier<int>(0);
  static List<EmployeeRecord>? _employeesCache;
  static Future<List<EmployeeRecord>>? _loadFuture;

  static ValueListenable<int> get changes => _changeCounter;

  static Future<void> preloadStartupData() async {
    try {
      await loadEmployees(forceRefresh: true);
    } catch (_) {
      // Keep using cached finance UI state if employee refresh fails.
    }
  }

  static Future<List<EmployeeRecord>> loadEmployees({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _employeesCache != null) {
      return List<EmployeeRecord>.from(_employeesCache!);
    }

    final inFlightLoad = _loadFuture;
    if (inFlightLoad != null) {
      final employees = await inFlightLoad;
      return List<EmployeeRecord>.from(employees);
    }

    final future = () async {
      try {
        final employees = await GoogleSheetService.instance.fetchEmployees();
        _employeesCache = _sortEmployees(employees);
        return List<EmployeeRecord>.from(_employeesCache!);
      } finally {
        _loadFuture = null;
      }
    }();

    _loadFuture = future;
    final employees = await future;
    return List<EmployeeRecord>.from(employees);
  }

  static Future<void> addEmployee(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Employee name is required.');
    }

    final employee = EmployeeRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalizedName,
      createdAt: DateTime.now(),
    );

    await GoogleSheetService.instance.upsertEmployee(employee);
    final employees = await loadEmployees(forceRefresh: true);
    _employeesCache = employees;
    _changeCounter.value++;
  }

  static Future<void> deleteEmployee(String id) async {
    await GoogleSheetService.instance.deleteEmployee(id);
    final employees = await loadEmployees(forceRefresh: true);
    _employeesCache = employees;
    _changeCounter.value++;
  }

  static List<EmployeeRecord> _sortEmployees(List<EmployeeRecord> employees) {
    final sorted = List<EmployeeRecord>.from(employees)
      ..sort((left, right) => left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    return sorted;
  }
}