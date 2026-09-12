import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../shared/models/milk_entry.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class CustomerCalendarTab extends StatefulWidget {
  const CustomerCalendarTab({super.key});

  @override
  State<CustomerCalendarTab> createState() => CustomerCalendarTabState();
}

class CustomerCalendarTabState extends State<CustomerCalendarTab> {
  List<MilkEntry> _entries = [];
  bool _loading = true;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final res = await ApiClient.instance.cachedGet('/milk-entries/me');
    setState(() {
      _entries = (res.data as List).map((e) => MilkEntry.fromJson(e)).toList();
      _loading = false;
    });
  }

  Map<int, MilkEntry> _entriesForVisibleMonth() {
    final map = <int, MilkEntry>{};
    for (final e in _entries) {
      if (e.deliveryDate.year == _visibleMonth.year && e.deliveryDate.month == _visibleMonth.month) {
        map[e.deliveryDate.day] = e;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final entriesByDay = _entriesForVisibleMonth();
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7; // Monday = 0

    final monthLitres = entriesByDay.values.fold<double>(0, (sum, e) => sum + e.quantityLitres);

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
              ),
              Text(
                '${_monthNames[_visibleMonth.month]} ${_visibleMonth.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                        Text('${entry.quantityLitres}L', style: const TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDayDetail(int day, MilkEntry entry) {
    final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(longDate(date)),
        content: Text('${entry.quantityLitres} L \u2022 \u20b9${entry.totalAmount}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
