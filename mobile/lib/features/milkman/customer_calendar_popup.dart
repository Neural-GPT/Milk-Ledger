import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

Future<void> showCustomerCalendarPopup(BuildContext context, String customerId, String customerName) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _CustomerCalendarSheet(customerId: customerId, customerName: customerName),
  );
}

class _CustomerCalendarSheet extends StatefulWidget {
  final String customerId;
  final String customerName;
  const _CustomerCalendarSheet({required this.customerId, required this.customerName});

  @override
  State<_CustomerCalendarSheet> createState() => _CustomerCalendarSheetState();
}

class _CustomerCalendarSheetState extends State<_CustomerCalendarSheet> {
  List<dynamic> _entries = [];
  bool _loading = true;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiClient.instance.dio.get('/milk-entries/customer/${widget.customerId}');
    setState(() {
      _entries = res.data;
      _loading = false;
    });
  }

  Map<int, dynamic> _entriesForVisibleMonth() {
    final map = <int, dynamic>{};
    for (final e in _entries) {
      final date = DateTime.parse(e['delivery_date']);
      if (date.year == _visibleMonth.year && date.month == _visibleMonth.month) {
        map[date.day] = e;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final entriesByDay = _entriesForVisibleMonth();
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;
    final monthLitres = entriesByDay.values.fold<double>(0, (sum, e) => sum + (e['quantity_litres'] as num).toDouble());

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(widget.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
            ),
            Text('${_monthNames[_visibleMonth.month]} ${_visibleMonth.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
            ),
          ],
        ),
        Text('Total this month: $monthLitres L', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: _weekdayLabels
              .map((w) => Expanded(
                    child: Center(
                      child: Text(w, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.85),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final entry = entriesByDay[day];
            final isToday = _visibleMonth.year == DateTime.now().year &&
                _visibleMonth.month == DateTime.now().month &&
                day == DateTime.now().day;

            return GestureDetector(
              onTap: entry == null ? null : () => _showDayDetail(day, entry),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: entry != null ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: AppTheme.accent, width: 1.5) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: const TextStyle(fontSize: 12)),
                    if (entry != null)
                      Text('${entry['quantity_litres']}L', style: const TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDayDetail(int day, dynamic entry) {
    final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(longDate(date)),
        content: Text('${entry['quantity_litres']} L \u2022 \u20b9${entry['total_amount']}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
