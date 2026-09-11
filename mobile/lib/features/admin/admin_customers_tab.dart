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
  final Set<String> _expanded = {};

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

  Map<String, List<dynamic>> _groupByMilkman(List<dynamic> customers) {
    final grouped = <String, List<dynamic>>{};
    for (final c in customers) {
      final key = c['milkman_name'] ?? 'Unknown';
      grouped.putIfAbsent(key, () => []).add(c);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _customers
        : _customers.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final phone = (c['phone_number'] ?? '').toString();
            final milkman = (c['milkman_name'] ?? '').toString().toLowerCase();
            return name.contains(_query.toLowerCase()) || phone.contains(_query) || milkman.contains(_query.toLowerCase());
          }).toList();

    final grouped = _groupByMilkman(filtered);
    final milkmanNames = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Customers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Search by name, phone, or milkman', prefixIcon: Icon(Icons.search)),
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
            ...milkmanNames.map((milkmanName) {
              final customers = grouped[milkmanName]!;
              final isExpanded = _expanded.contains(milkmanName);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (open) {
                      setState(() {
                        if (open) {
                          _expanded.add(milkmanName);
                        } else {
                          _expanded.remove(milkmanName);
                        }
                      });
                    },
                    leading: const Icon(Icons.folder_outlined, color: AppTheme.accent),
                    title: Text(milkmanName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${customers.length} customer${customers.length == 1 ? '' : 's'}'),
                    children: customers.map<Widget>((c) => ListTile(
                          title: Text(c['name'] ?? ''),
                          subtitle: Text(c['phone_number'] ?? ''),
                          trailing: c['device_locked'] == true
                              ? TextButton(
                                  onPressed: () => _resetDevice(c['id'], c['name'] ?? 'This customer'),
                                  child: const Text('Reset lock'),
                                )
                              : const Text('Not locked', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        )).toList(),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
