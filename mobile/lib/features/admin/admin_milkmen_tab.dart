import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class AdminMilkmenTab extends StatefulWidget {
  const AdminMilkmenTab({super.key});

  @override
  State<AdminMilkmenTab> createState() => AdminMilkmenTabState();
}

class AdminMilkmenTabState extends State<AdminMilkmenTab> {
  List<dynamic> _milkmen = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/admin/milkmen');
      setState(() => _milkmen = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddMilkmanDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final businessController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add Milkman'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone number')),
              const SizedBox(height: 10),
              TextField(controller: businessController, decoration: const InputDecoration(hintText: 'Business name (optional)')),
              const SizedBox(height: 8),
              const Text(
                'They log in with this exact name and phone number.',
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
                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = 'Name and phone number are required.');
                  return;
                }
                try {
                  await ApiClient.instance.dio.post('/admin/milkmen', data: {
                    'name': nameController.text.trim(),
                    'phone_number': phoneController.text.trim(),
                    'business_name': businessController.text.trim().isEmpty ? null : businessController.text.trim(),
                  });
                  if (mounted) Navigator.of(context).pop();
                  reload();
                } on DioException catch (e) {
                  final data = e.response?.data;
                  final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'Could not add milkman.';
                  setDialogState(() => dialogError = detail);
                }
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Milkmen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: _openAddMilkmanDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_milkmen.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No milkmen yet - tap Add to create one.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ..._milkmen.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(m['name'] ?? ''),
                    subtitle: Text('${m['phone_number']}${m['business_name'] != null ? ' \u2022 ${m['business_name']}' : ''}'),
                    trailing: Icon(
                      m['is_active'] == true ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      color: m['is_active'] == true ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
