import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'customer_calendar_popup.dart';

const _monthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => AnalysisTabState();
}

class AnalysisTabState extends State<AnalysisTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/dashboard/analysis');
      setState(() => _data = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final monthly = (_data?['monthly_totals'] as List?) ?? [];
    final topCustomers = (_data?['top_customers_this_month'] as List?) ?? [];
    final maxLitres = monthly.fold<double>(1, (max, m) => (m['total_litres'] as num) > max ? (m['total_litres'] as num).toDouble() : max);

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Analysis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Last 6 Months', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: monthly.map<Widget>((m) {
                    final litres = (m['total_litres'] as num).toDouble();
                    final barHeight = maxLitres > 0 ? (litres / maxLitres) * 90 : 0.0;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(litres.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: barHeight < 4 ? 4 : barHeight,
                          decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 6),
                        Text(_monthNames[m['month'] as int], style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Top Customers This Month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (topCustomers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No deliveries recorded this month yet.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...topCustomers.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.surfaceLight,
                    child: Text('${i + 1}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c['name'] ?? ''),
                  trailing: Text('${c['total_litres']} L', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => showCustomerCalendarPopup(context, c['id'], c['name'] ?? ''),
                ),
              );
            }),
        ],
      ),
    );
  }
}
