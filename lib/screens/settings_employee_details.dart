import 'package:flutter/material.dart';

import '../models/employee_record.dart';
import '../services/employee_directory_service.dart';
import '../widgets/app_message.dart';

class SettingsEmployeeDetailsScreen extends StatefulWidget {
  const SettingsEmployeeDetailsScreen({super.key});

  @override
  State<SettingsEmployeeDetailsScreen> createState() =>
      _SettingsEmployeeDetailsScreenState();
}

class _SettingsEmployeeDetailsScreenState
    extends State<SettingsEmployeeDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);

  List<EmployeeRecord> _employees = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await EmployeeDirectoryService.loadEmployees(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      AppMessage.showError(context, error.toString());
    }
  }

  Future<void> _addEmployee() async {
    final employeeName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddEmployeeSheet(),
    );

    if (!mounted || employeeName == null || employeeName.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await EmployeeDirectoryService.addEmployee(employeeName);
      if (!mounted) {
        return;
      }

      await _loadEmployees(forceRefresh: true);
      if (!mounted) {
        return;
      }
      AppMessage.showSuccess(context, 'Employee added.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteEmployee(EmployeeRecord employee) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await EmployeeDirectoryService.deleteEmployee(employee.id);
      if (!mounted) {
        return;
      }

      await _loadEmployees(forceRefresh: true);
      if (!mounted) {
        return;
      }
      AppMessage.showInfo(context, '${employee.name} removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            backgroundColor: _surface,
            foregroundColor: _primary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text('Employees'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isSaving ? null : _addEmployee,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add Employee'),
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadEmployees(forceRefresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _surfaceLowest,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1200342D),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salary Employees',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Employees added here can be selected in salary entries across the finance workspace.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_employees.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD6D1C7)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 36,
                          color: _primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No employees added yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first employee to use the custom employee picker in salary entries.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._employees.map(
                    (employee) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _surfaceLowest,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFD6D1C7)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.badge_outlined,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                employee.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _deleteEmployee(employee),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFF8B8F89),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isSaving)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddEmployeeSheet extends StatefulWidget {
  const _AddEmployeeSheet();

  @override
  State<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<_AddEmployeeSheet> {
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textSecondary = Color(0xFF3F4945);

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1CBC2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Add employee',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This employee will appear in salary entry forms.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Employee name',
                  hintText: 'Enter employee name',
                  filled: true,
                  fillColor: _surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _primary, width: 1.4),
                  ),
                ),
                onSubmitted: (value) {
                  Navigator.of(context).pop(value.trim());
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(_controller.text.trim());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Save Employee'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}