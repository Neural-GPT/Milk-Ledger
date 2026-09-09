import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'add_customer_screen.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => CustomersTabState();
}

class CustomersTabState extends State<CustomersTab> {
  List<dynamic> _customers = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/customers');
      setState(() => _customers = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _customers
        : _customers.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final phone = (c['phone_number'] ?? '').toString();
            return name.contains(_query.toLowerCase()) || phone.contains(_query);
          }).toList();

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add'),
                onPressed: () async {
                  final added = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                  );
                  if (added == true) reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'Need to reset a customer\'s device lock? That\'s handled by the admin now.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No customers found.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ...filtered.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c['name'] ?? ''),
                    subtitle: Text(c['phone_number'] ?? ''),
                  ),
                )),
        ],
      ),
    );
  }
}
