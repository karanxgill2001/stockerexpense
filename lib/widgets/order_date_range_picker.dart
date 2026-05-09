import 'package:flutter/material.dart';

Future<DateTimeRange?> showOrderDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialRange,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _OrderDateRangePickerSheet(initialRange: initialRange),
  );
}

class _OrderDateRangePickerSheet extends StatefulWidget {
  const _OrderDateRangePickerSheet({this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<_OrderDateRangePickerSheet> createState() =>
      _OrderDateRangePickerSheetState();
}

class _OrderDateRangePickerSheetState
    extends State<_OrderDateRangePickerSheet> {
  static const Color _primary = Color(0xFF00342D);
  static const Color _primarySoft = Color(0xFFE0F0EC);
  static const Color _surface = Colors.white;
  static const Color _sheetBackground = Color(0xFFF5F8F7);
  static const Color _textPrimary = Color(0xFF10201D);
  static const Color _textMuted = Color(0xFF5A6A66);
  static const Color _border = Color(0x1F00342D);
  static const double _gridGap = 6;
  static const double _cellHeight = 46;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _dragAnchorDate;
  DateTime? _lastDraggedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange == null
        ? null
        : DateUtils.dateOnly(widget.initialRange!.start);
    _endDate = widget.initialRange == null
        ? null
        : DateUtils.dateOnly(widget.initialRange!.end);
    _visibleMonth = DateTime(
      (_startDate ?? DateTime.now()).year,
      (_startDate ?? DateTime.now()).month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final years = _buildYearOptions();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Material(
          color: _sheetBackground,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4DCD8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select date range',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: _textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose month and year directly for older orders.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SelectorCard<int>(
                          label: 'Month',
                          value: _visibleMonth.month,
                          items: List.generate(
                            _months.length,
                            (index) => DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(_months[index]),
                            ),
                          ),
                          onChanged: (month) {
                            if (month == null) {
                              return;
                            }
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                month,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SelectorCard<int>(
                          label: 'Year',
                          value: _visibleMonth.year,
                          items: years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('$year'),
                                ),
                              )
                              .toList(),
                          onChanged: (year) {
                            if (year == null) {
                              return;
                            }
                            setState(() {
                              _visibleMonth = DateTime(
                                year,
                                _visibleMonth.month,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _sheetBackground,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SelectionSummaryCard(
                            label: 'Start',
                            value: _startDate == null
                                ? 'Tap a date'
                                : _formatDate(_effectiveStart!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SelectionSummaryCard(
                            label: 'End',
                            value: _startDate == null
                                ? 'Tap a date'
                                : _formatDate(_effectiveEnd!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: _weekdays
                        .map(
                          (weekday) => Expanded(
                            child: Center(
                              child: Text(
                                weekday,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _textMuted,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  _CalendarGrid(
                    visibleMonth: _visibleMonth,
                    startDate: _effectiveStart,
                    endDate: _effectiveEnd,
                    onDateSelected: _selectDate,
                    onRangeDragStart: _handleRangeDragStart,
                    onRangeDragUpdate: _handleRangeDragUpdate,
                    onRangeDragEnd: _handleRangeDragEnd,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _rangeLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearRange,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _startDate == null
                              ? null
                              : () {
                                  Navigator.of(context).pop(
                                    DateTimeRange(
                                      start: _effectiveStart!,
                                      end: _effectiveEnd!,
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime? get _effectiveStart {
    if (_startDate == null) {
      return null;
    }

    if (_endDate == null) {
      return _startDate;
    }

    return _startDate!.isBefore(_endDate!) ? _startDate : _endDate;
  }

  DateTime? get _effectiveEnd {
    if (_startDate == null) {
      return null;
    }

    if (_endDate == null) {
      return _startDate;
    }

    return _startDate!.isAfter(_endDate!) ? _startDate : _endDate;
  }

  String get _rangeLabel {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (start == null) {
      return 'Tap a start date, then tap an end date.';
    }

    if (DateUtils.isSameDay(start, end)) {
      return 'Selected: ${_formatDate(start)}';
    }

    return 'Selected: ${_formatDate(start)} -> ${_formatDate(end!)}';
  }

  void _selectDate(DateTime date) {
    setState(() {
      _dragAnchorDate = null;
      _lastDraggedDate = null;
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
        return;
      }

      if (date.isBefore(_startDate!)) {
        _endDate = _startDate;
        _startDate = date;
        return;
      }

      _endDate = date;
    });
  }

  void _handleRangeDragStart(DateTime date) {
    setState(() {
      _dragAnchorDate = date;
      _lastDraggedDate = date;
      _startDate = date;
      _endDate = date;
    });
  }

  void _handleRangeDragUpdate(DateTime date) {
    if (_dragAnchorDate == null ||
        (_lastDraggedDate != null &&
            DateUtils.isSameDay(_lastDraggedDate, date))) {
      return;
    }

    setState(() {
      _lastDraggedDate = date;
      _startDate = _dragAnchorDate;
      _endDate = date;
    });
  }

  void _handleRangeDragEnd() {
    if (_dragAnchorDate == null) {
      return;
    }

    setState(() {
      _dragAnchorDate = null;
      _lastDraggedDate = null;
    });
  }

  void _clearRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _dragAnchorDate = null;
      _lastDraggedDate = null;
    });
  }

  List<int> _buildYearOptions() {
    final now = DateTime.now();
    final selectedYears = {
      now.year,
      _visibleMonth.year,
      if (_startDate != null) _startDate!.year,
      if (_endDate != null) _endDate!.year,
    };
    final minYear = selectedYears.reduce((a, b) => a < b ? a : b) - 20;
    final maxYear = selectedYears.reduce((a, b) => a > b ? a : b) + 1;
    return List<int>.generate(
      maxYear - minYear + 1,
      (index) => minYear + index,
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day} ${_months[value.month - 1].substring(0, 3)} ${value.year}';
  }
}

class _SelectorCard<T> extends StatelessWidget {
  const _SelectorCard({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: _OrderDateRangePickerSheetState._sheetBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _OrderDateRangePickerSheetState._border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: Colors.white,
          style: theme.textTheme.titleMedium?.copyWith(
            color: _OrderDateRangePickerSheetState._textPrimary,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          selectedItemBuilder: (context) {
            return items
                .map(
                  (item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _OrderDateRangePickerSheetState._textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          '${item.value == null ? '' : (item.child as Text).data}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _OrderDateRangePickerSheetState._textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList();
          },
        ),
      ),
    );
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: _OrderDateRangePickerSheetState._textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _OrderDateRangePickerSheetState._textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.startDate,
    required this.endDate,
    required this.onDateSelected,
    required this.onRangeDragStart,
    required this.onRangeDragUpdate,
    required this.onRangeDragEnd,
  });

  final DateTime visibleMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onRangeDragStart;
  final ValueChanged<DateTime> onRangeDragUpdate;
  final VoidCallback onRangeDragEnd;

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridMetrics = _CalendarGridMetrics.fromWidth(
          width: constraints.maxWidth,
          itemCount: days.length,
        );

        DateTime? resolveDate(Offset position) {
          final column =
              position.dx ~/ (gridMetrics.cellWidth + gridMetrics.gap);
          final row = position.dy ~/ (gridMetrics.cellHeight + gridMetrics.gap);

          if (column < 0 ||
              column >= 7 ||
              row < 0 ||
              row >= gridMetrics.rowCount) {
            return null;
          }

          final columnStart =
              column * (gridMetrics.cellWidth + gridMetrics.gap);
          final rowStart = row * (gridMetrics.cellHeight + gridMetrics.gap);
          final withinColumn = position.dx - columnStart;
          final withinRow = position.dy - rowStart;

          if (withinColumn > gridMetrics.cellWidth ||
              withinRow > gridMetrics.cellHeight) {
            return null;
          }

          final index = (row * 7) + column;
          if (index < 0 || index >= days.length) {
            return null;
          }

          return days[index];
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final day = resolveDate(details.localPosition);
            if (day != null) {
              onRangeDragStart(day);
            }
          },
          onPanUpdate: (details) {
            final day = resolveDate(details.localPosition);
            if (day != null) {
              onRangeDragUpdate(day);
            }
          },
          onPanEnd: (_) => onRangeDragEnd(),
          onPanCancel: onRangeDragEnd,
          onTapUp: (details) {
            final day = resolveDate(details.localPosition);
            if (day != null) {
              onDateSelected(day);
            }
          },
          child: SizedBox(
            height: gridMetrics.gridHeight,
            child: IgnorePointer(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: days.length,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: _OrderDateRangePickerSheetState._gridGap,
                  crossAxisSpacing: _OrderDateRangePickerSheetState._gridGap,
                  mainAxisExtent: _OrderDateRangePickerSheetState._cellHeight,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];
                  if (day == null) {
                    return const SizedBox.shrink();
                  }

                  final isStart =
                      startDate != null && DateUtils.isSameDay(day, startDate);
                  final isEnd =
                      endDate != null && DateUtils.isSameDay(day, endDate);
                  final isSameDaySelection = isStart && isEnd;
                  final inRange = _isInRange(day);
                  final isToday = DateUtils.isSameDay(day, DateTime.now());

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: isStart || isEnd
                          ? _OrderDateRangePickerSheetState._primary
                          : inRange
                          ? _OrderDateRangePickerSheetState._primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? _OrderDateRangePickerSheetState._primary
                                  .withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isStart || isEnd
                                  ? Colors.white
                                  : _OrderDateRangePickerSheetState
                                        ._textPrimary,
                              fontWeight: isSameDaySelection || isStart || isEnd
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<DateTime?> _buildDays() {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final totalDays = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final leadingBlanks = firstDay.weekday % 7;
    final items = List<DateTime?>.filled(leadingBlanks, null, growable: true);
    for (var day = 1; day <= totalDays; day += 1) {
      items.add(DateTime(visibleMonth.year, visibleMonth.month, day));
    }
    return items;
  }

  bool _isInRange(DateTime date) {
    if (startDate == null || endDate == null) {
      return false;
    }

    final start = startDate!.isBefore(endDate!) ? startDate! : endDate!;
    final end = startDate!.isAfter(endDate!) ? startDate! : endDate!;

    return date.isAfter(start) && date.isBefore(end);
  }
}

class _CalendarGridMetrics {
  const _CalendarGridMetrics({
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
    required this.rowCount,
    required this.gridHeight,
  });

  factory _CalendarGridMetrics.fromWidth({
    required double width,
    required int itemCount,
  }) {
    const gap = _OrderDateRangePickerSheetState._gridGap;
    const cellHeight = _OrderDateRangePickerSheetState._cellHeight;
    final cellWidth = (width - (gap * 6)) / 7;
    final rowCount = (itemCount / 7).ceil();
    final gridHeight = (rowCount * cellHeight) + ((rowCount - 1) * gap);
    return _CalendarGridMetrics(
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      gap: gap,
      rowCount: rowCount,
      gridHeight: gridHeight,
    );
  }

  final double cellWidth;
  final double cellHeight;
  final double gap;
  final int rowCount;
  final double gridHeight;
}
