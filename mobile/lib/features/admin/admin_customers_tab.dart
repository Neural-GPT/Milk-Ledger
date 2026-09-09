import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class AdminCustomersTab extends StatefulWidget {
  const AdminCustomersTab({super.key});

  @override
  State<AdminCustomersTab> createState() => AdminCustomersTabState();
}

class AdminCustomersTabState extends State<AdminCustomersTab> {
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
      final res = await ApiClient.instance.dio.get('/admin/customers');
      setState(() => _customers = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetDevice(String customerId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Reset device lock?'),
        content: Text('$name will be able to log in from a new phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('RESET')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiClient.instance.dio.post('/admin/customers/$customerId/reset-device');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device lock cleared.')));
    }
    reload();
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
          const Text('Customers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v),
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
                    subtitle: Text('${c['phone_number']} \u2022 via ${c['milkman_name']}'),
                    trailing: c['device_locked'] == true
                        ? TextButton(
                            onPressed: () => _resetDevice(c['id'], c['name'] ?? 'This customer'),
                            child: const Text('Reset lock'),
                          )
                        : const Text('Not locked', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                )),
        ],
      ),
    );
  }
}
