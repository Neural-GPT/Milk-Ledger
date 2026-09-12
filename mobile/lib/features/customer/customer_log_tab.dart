import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../auth/auth_controller.dart';

const Map<String, String> _actionLabels = {
  'MILK_ENTRY_CREATED': 'Milk entry added',
  'MILK_ENTRY_UPDATED': 'Milk entry edited',
  'MILK_ENTRY_DELETED': 'Milk entry removed',
  'PRICE_CHANGED': 'Milk rate changed',
  'CUSTOMER_CREATED': 'Your account was created',
};

class CustomerLogTab extends ConsumerStatefulWidget {
  const CustomerLogTab({super.key});

  @override
  ConsumerState<CustomerLogTab> createState() => CustomerLogTabState();
}

class CustomerLogTabState extends ConsumerState<CustomerLogTab> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/audit-logs/me');
      setState(() => _logs = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _describeLog(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final meta = log['metadata_json'] as Map?;
    final label = _actionLabels[action] ?? action;

    if (action == 'MILK_ENTRY_CREATED' && meta?['new'] != null) {
      return '$label: ${meta!['new']['quantity']} L';
    }
    if (action == 'MILK_ENTRY_UPDATED' && meta?['old'] != null && meta?['new'] != null) {
      return '$label: ${meta!['old']['quantity']} L \u2192 ${meta['new']['quantity']} L';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
              ),
              const SizedBox(width: 4),
              const Text('My Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Changes your milkman made to your account', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No activity yet.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ..._logs.map((log) {
              final created = DateTime.parse(log['created_at']).toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(_describeLog(log)),
                  subtitle: Text('${longDate(created)} \u2022 ${created.toString().substring(11, 16)}'),
                ),
              );
            }),
        ],
      ),
    );
  }
}
