import 'package:flutter/material.dart';

class CommunityCalendar extends StatefulWidget {
  const CommunityCalendar({super.key});

  @override
  State<CommunityCalendar> createState() => _CommunityCalendarState();
}

class _CommunityCalendarState extends State<CommunityCalendar> {
  late DateTime _focusedMonth;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    // System current date: June 1, 2026
    _today = DateTime(2026, 6, 1);
    _focusedMonth = DateTime(2026, 6, 1);
  }

  // Helper list of months
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Helper list of weekdays
  final List<String> _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Hijri Mock Date Mapper
  String _getHijriLabel(DateTime date) {
    if (date.year == 2026 && date.month == 6) {
      if (date.day <= 15) {
        final dayNum = date.day + 14;
        return 'ذو الحجة $dayNum';
      } else {
        final dayNum = date.day - 15;
        return 'محرم $dayNum';
      }
    } else if (date.year == 2026 && date.month == 5) {
      // May 2026 Mock
      if (date.day <= 17) {
        final dayNum = date.day + 13;
        return 'ذو القعدة $dayNum';
      } else {
        final dayNum = date.day - 17;
        return 'ذو الحجة $dayNum';
      }
    }
    // General mock calculation for other months
    final dayNum = (date.day + 8) % 29 + 1;
    return 'هجري $dayNum';
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime(_today.year, _today.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate grid details
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    
    // Day of the week first day falls on (0 = Sunday, 6 = Saturday)
    // DateTime.weekday returns 1 = Mon, 7 = Sun. Convert to 0 = Sun.
    final startWeekdayOffset = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;

    // Previous month days to fill start of grid
    final prevMonthYear = _focusedMonth.month == 1 ? _focusedMonth.year - 1 : _focusedMonth.year;
    final prevMonthVal = _focusedMonth.month == 1 ? 12 : _focusedMonth.month - 1;
    final daysInPrevMonth = DateTime(prevMonthYear, prevMonthVal + 1, 0).day;

    final totalGridCells = startWeekdayOffset + daysInMonth;
    final rowCount = (totalGridCells / 7).ceil();
    final gridItemCount = rowCount * 7;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Calendar Header: Month Name, Today Button, Arrow Buttons
            Row(
              children: [
                Text(
                  '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                
                // Today Button
                ElevatedButton(
                  onPressed: _goToToday,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.08),
                    foregroundColor: theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                
                // Navigation Chevrons
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _prevMonth,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.primary,
                      ),
                      Container(width: 1, height: 20, color: theme.colorScheme.outline.withOpacity(0.2)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _nextMonth,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Weekday Headers (Sun, Mon, Tue, etc.)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 16),
            
            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gridItemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                DateTime cellDate;
                bool isCurrentMonth = true;

                if (index < startWeekdayOffset) {
                  // Prev Month Day
                  final dayVal = daysInPrevMonth - startWeekdayOffset + index + 1;
                  cellDate = DateTime(prevMonthYear, prevMonthVal, dayVal);
                  isCurrentMonth = false;
                } else if (index < startWeekdayOffset + daysInMonth) {
                  // Current Month Day
                  final dayVal = index - startWeekdayOffset + 1;
                  cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayVal);
                } else {
                  // Next Month Day
                  final nextMonthYear = _focusedMonth.month == 12 ? _focusedMonth.year + 1 : _focusedMonth.year;
                  final nextMonthVal = _focusedMonth.month == 12 ? 1 : _focusedMonth.month + 1;
                  final dayVal = index - (startWeekdayOffset + daysInMonth) + 1;
                  cellDate = DateTime(nextMonthYear, nextMonthVal, dayVal);
                  isCurrentMonth = false;
                }

                final isToday = cellDate.year == _today.year &&
                    cellDate.month == _today.month &&
                    cellDate.day == _today.day;

                return Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.yellow.shade100 // Light yellow highlight for today
                        : Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.06),
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Gregorian Day Number
                      Text(
                        cellDate.day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentMonth
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      
                      // Hijri Label
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _getHijriLabel(cellDate),
                            style: TextStyle(
                              fontSize: 8,
                              color: isCurrentMonth
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.3),
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
