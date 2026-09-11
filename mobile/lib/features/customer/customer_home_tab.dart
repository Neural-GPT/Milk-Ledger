import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../core/weekly_feedback_prompt.dart';
import '../../shared/models/milk_entry.dart';
import '../../shared/widgets/feedback_dialog.dart';

class CustomerHomeTab extends ConsumerStatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  ConsumerState<CustomerHomeTab> createState() => CustomerHomeTabState();
}

class CustomerHomeTabState extends ConsumerState<CustomerHomeTab> {
  List<MilkEntry> _entries = [];
  String? _milkmanName;
  Map<String, dynamic>? _latestUnreadNotification;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WeeklyFeedbackPrompt.maybeShow(context);
    });
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.cachedGet('/milk-entries/me'),
        ApiClient.instance.cachedGet('/customers/me'),
        ApiClient.instance.cachedGet('/notifications/me'),
      ]);
      final notifications = results[2].data as List;
      final unread = notifications.where((n) => n['is_read'] == false).toList();

      setState(() {
        _entries = (results[0].data as List).map((e) => MilkEntry.fromJson(e)).toList();
        _milkmanName = results[1].data['milkman_business_name'] ?? results[1].data['milkman_name'];
        _latestUnreadNotification = unread.isNotEmpty ? unread.first : null;
        _offline = results.any((r) => r.fromCache);
      });
    } catch (_) {
      // No network AND no cache yet - nothing more we can show.
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismissPill() async {
    final notif = _latestUnreadNotification;
    if (notif == null) return;
    setState(() => _latestUnreadNotification = null);
    if (!_offline) {
      await ApiClient.instance.dio.post('/notifications/${notif['id']}/read');
    }
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Milk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  if (_milkmanName != null)
                    Text('via $_milkmanName', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.feedback_outlined, color: AppTheme.textSecondary),
                tooltip: 'Give feedback',
                onPressed: () => showFeedbackDialog(context),
              ),
            ],
          ),
          if (_latestUnreadNotification != null) ...[
            const SizedBox(height: 12),
            _NotificationPill(
              message: _latestUnreadNotification!['message'] ?? '',
              onDismiss: _dismissPill,
            ),
          ],
          if (_offline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: AppTheme.warning),
                  SizedBox(width: 8),
                  Expanded(child: Text('Offline - showing saved data', style: TextStyle(fontSize: 12, color: AppTheme.warning))),
                ],
              ),
            ),
          ],
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

class _NotificationPill extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _NotificationPill({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_drink_rounded, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
