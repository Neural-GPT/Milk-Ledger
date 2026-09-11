import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

const Map<String, String> _actionLabels = {
  'MILK_ENTRY_CREATED': 'Entry added',
  'MILK_ENTRY_UPDATED': 'Entry edited',
  'MILK_ENTRY_DELETED': 'Entry removed',
  'PRICE_CHANGED': 'Milk rate changed',
  'CUSTOMER_CREATED': 'Customer added',
};

class MilkmanLogTab extends StatefulWidget {
  const MilkmanLogTab({super.key});

  @override
  State<MilkmanLogTab> createState() => MilkmanLogTabState();
}

class MilkmanLogTabState extends State<MilkmanLogTab> {
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
      final res = await ApiClient.instance.dio.get('/audit-logs/milkman');
      final today = DateTime.now();
      final todayLogs = (res.data as List).where((log) {
        final created = DateTime.parse(log['created_at']).toLocal();
        return created.year == today.year && created.month == today.month && created.day == today.day;
      }).toList();
      setState(() => _logs = todayLogs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editEntry(Map<String, dynamic> log) async {
    final controller = TextEditingController(
      text: (log['metadata_json']?['new']?['quantity'] ?? '').toString(),
    );
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Edit Today\'s Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'New quantity (L)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'The customer will be notified of this change.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(controller.text.trim());
                if (qty == null || qty <= 0) {
                  setDialogState(() => dialogError = 'Enter a valid quantity.');
                  return;
                }
                try {
                  await ApiClient.instance.dio.patch(
                    '/milk-entries/${log['entity_id']}',
                    data: {'quantity_litres': qty},
                  );
                  if (mounted) Navigator.of(context).pop();
                  reload();
                } on DioException catch (e) {
                  final data = e.response?.data;
                  final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'Could not update entry.';
                  setDialogState(() => dialogError = detail);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  String _describeLog(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final meta = log['metadata_json'] as Map?;
    final customerName = log['customer_name'] as String?;

    if (action == 'MILK_ENTRY_CREATED' && meta?['new'] != null) {
      final qty = meta!['new']['quantity'];
      return '${qty}L${customerName != null ? '    $customerName' : ''}';
    }
    if (action == 'MILK_ENTRY_UPDATED' && meta?['old'] != null && meta?['new'] != null) {
      final oldQty = meta!['old']['quantity'];
      final newQty = meta['new']['quantity'];
      return '$oldQty L \u2192 ${newQty}L${customerName != null ? '    $customerName' : ''}';
    }
    if (action == 'PRICE_CHANGED' && meta?['new'] != null) {
      return 'Milk rate changed: \u20b9${meta!['new']['price']}/L';
    }
    return _actionLabels[action] ?? action;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('My Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Today\'s entries and edits', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Nothing logged today yet.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ..._logs.map((log) {
              final canEdit = log['action'] == 'MILK_ENTRY_CREATED' || log['action'] == 'MILK_ENTRY_UPDATED';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(_describeLog(log)),
                  subtitle: Text(DateTime.parse(log['created_at']).toLocal().toString().substring(11, 16)),
                  trailing: canEdit
                      ? IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editEntry(log))
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
