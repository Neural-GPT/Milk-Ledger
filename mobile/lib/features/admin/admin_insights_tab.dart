import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';

class AdminInsightsTab extends StatefulWidget {
  const AdminInsightsTab({super.key});

  @override
  State<AdminInsightsTab> createState() => AdminInsightsTabState();
}

class AdminInsightsTabState extends State<AdminInsightsTab> {
  Map<String, dynamic>? _analysis;
  List<dynamic> _feedback = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get('/admin/analysis'),
        ApiClient.instance.dio.get('/feedback/admin'),
      ]);
      setState(() {
        _analysis = results[0].data;
        _feedback = results[1].data;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Insights', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Usage This Month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (_analysis?['average_rating'] != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppTheme.accent, size: 16),
                    const SizedBox(width: 4),
                    Text('${_analysis!['average_rating']} avg (${_analysis!['feedback_count']})',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_feedback.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No feedback submitted yet.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ..._feedback.map((f) {
              final created = DateTime.parse(f['created_at']).toLocal();
              final rating = f['rating'] as int;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...List.generate(5, (i) => Icon(
                                i < rating ? Icons.star : Icons.star_border,
                                color: AppTheme.accent,
                                size: 16,
                              )),
                          const SizedBox(width: 8),
                          Text((f['role'] ?? '').toString().toLowerCase(),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                      if (f['comment'] != null && (f['comment'] as String).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(f['comment']),
                      ],
                      const SizedBox(height: 4),
                      Text(longDate(created), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final items = [
      ('Milkmen', '${_analysis?['total_milkmen'] ?? 0}', Icons.local_shipping_outlined),
      ('Customers', '${_analysis?['total_customers'] ?? 0}', Icons.people_outline),
      ('Litres', '${_analysis?['litres_this_month'] ?? 0}L', Icons.water_drop_outlined),
      ('Collection', '\u20b9${_analysis?['collection_this_month'] ?? 0}', Icons.currency_rupee),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items
          .map((item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$3, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(height: 4),
                      Text(item.$1, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text(item.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
