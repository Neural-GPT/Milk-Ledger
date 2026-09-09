import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../shared/models/milk_entry.dart';
import '../auth/auth_controller.dart';

class CustomerHomeTab extends ConsumerStatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  ConsumerState<CustomerHomeTab> createState() => CustomerHomeTabState();
}

class CustomerHomeTabState extends ConsumerState<CustomerHomeTab> {
  List<MilkEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final res = await ApiClient.instance.dio.get('/milk-entries/me');
    setState(() {
      _entries = (res.data as List).map((e) => MilkEntry.fromJson(e)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final thisMonth = _entries.where((e) => e.deliveryDate.month == now.month && e.deliveryDate.year == now.year);
    final monthlyLitres = thisMonth.fold<double>(0, (sum, e) => sum + e.quantityLitres);
    final monthlyTotal = thisMonth.fold<double>(0, (sum, e) => sum + e.totalAmount);
    final today = _entries.where((e) =>
        e.deliveryDate.day == now.day && e.deliveryDate.month == now.month && e.deliveryDate.year == now.year);

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Milk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          today.isEmpty ? 'No entry yet' : '${today.first.quantityLitres} L',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (today.isNotEmpty)
                          Text('\u20b9${today.first.totalAmount}', style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This Month', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('$monthlyLitres L', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('\u20b9$monthlyTotal', style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No deliveries recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ..._entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${e.quantityLitres} L'),
                    subtitle: Text(longDate(e.deliveryDate)),
                    trailing: Text('\u20b9${e.totalAmount}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )),
        ],
      ),
    );
  }
}
