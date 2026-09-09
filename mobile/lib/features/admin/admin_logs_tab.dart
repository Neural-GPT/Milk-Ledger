import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({super.key});

  @override
  State<AdminLogsTab> createState() => AdminLogsTabState();
}

class AdminLogsTabState extends State<AdminLogsTab> {
  List<dynamic> _logs = [];
  bool _loading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/admin/audit-logs', queryParameters: {
        'year': _selectedMonth.year,
        'month': _selectedMonth.month,
      });
      setState(() => _logs = res.data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToClipboard() async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/admin/audit-logs/export',
        queryParameters: {'year': _selectedMonth.year, 'month': _selectedMonth.month},
        options: Options(responseType: ResponseType.plain),
      );
      await Clipboard.setData(ClipboardData(text: res.data.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard - paste into Excel/Sheets.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed.')));
      }
    }
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Wipe logs for this month?'),
        content: Text(
          'This permanently deletes all ${_monthNames[_selectedMonth.month]} ${_selectedMonth.year} log entries. '
          'Export them first if you need a record. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiClient.instance.dio.delete('/admin/audit-logs/wipe', queryParameters: {
      'year': _selectedMonth.year,
      'month': _selectedMonth.month,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs wiped for this month.')));
    }
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Logs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
                  reload();
                },
              ),
              Text('${_monthNames[_selectedMonth.month]} ${_selectedMonth.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
                  reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export CSV'),
                  onPressed: _exportToClipboard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  label: const Text('Wipe month', style: TextStyle(color: Colors.redAccent)),
                  onPressed: _confirmWipe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No logs for this month.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ..._logs.map((log) {
              final created = DateTime.parse(log['created_at']).toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(log['action'] ?? ''),
                  subtitle: Text('${longDate(created)} \u2022 ${created.toString().substring(11, 16)}'),
                  dense: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}
