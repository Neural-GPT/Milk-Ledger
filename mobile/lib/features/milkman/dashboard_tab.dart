import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../core/weekly_feedback_prompt.dart';
import '../../shared/widgets/feedback_dialog.dart';
import '../auth/auth_controller.dart';
import 'add_customer_screen.dart';

class DashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onCustomersChanged;
  const DashboardTab({super.key, required this.onCustomersChanged});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1.0');

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<dynamic> _recentCustomers = [];
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedCustomer;
  double? _currentPrice;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WeeklyFeedbackPrompt.maybeShow(context);
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.cachedGet('/dashboard/profile'),
        ApiClient.instance.cachedGet('/dashboard/summary'),
        ApiClient.instance.cachedGet('/customers/recent'),
      ]);
      setState(() {
        _profile = results[0].data;
        _summary = results[1].data;
        _recentCustomers = results[2].data;
        _currentPrice = (_summary?['current_price_per_litre'] as num?)?.toDouble();
        _offline = results.any((r) => r.fromCache);
      });
    } catch (_) {
      // No network AND no cache yet - nothing more we can show.
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final res = await ApiClient.instance.dio.get('/customers/search', queryParameters: {'q': query});
    setState(() => _searchResults = res.data);
  }

  Future<void> _saveEntry() async {
    if (_selectedCustomer == null) {
      setState(() => _error = 'Select a customer first.');
      return;
    }
    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    if (_currentPrice == null) {
      setState(() => _error = 'Set a milk rate first (tap the Milk Rate card above).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/milk-entries', data: {
        'customer_id': _selectedCustomer!['id'],
        'delivery_date': _selectedDate.toIso8601String().split('T').first,
        'quantity_litres': qty,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorded ${qty}L for ${_selectedCustomer!['name']}')),
        );
      }
      setState(() {
        _selectedCustomer = null;
        _searchResults = [];
        _searchController.clear();
        _quantityController.text = '1.0';
      });
      _loadAll();
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : null;
      setState(() => _error = detail ?? 'Could not save entry. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSetRateDialog() async {
    final controller = TextEditingController(text: _currentPrice?.toString() ?? '');
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(_currentPrice == null ? 'Set Milk Rate' : 'Change Milk Rate'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Rate per litre (\u20b9)'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Once set, the rate can only be changed once per month.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final rate = double.tryParse(controller.text.trim());
                if (rate == null || rate <= 0) {
                  setDialogState(() => dialogError = 'Enter a valid rate.');
                  return;
                }
                try {
                  await ApiClient.instance.dio.post('/prices', data: {'price_per_litre': rate});
                  if (mounted) Navigator.of(context).pop();
                  _loadAll();
                } on DioException catch (e) {
                  final data = e.response?.data;
                  final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'Could not set rate.';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final businessName = _profile?['business_name'] ?? _profile?['name'] ?? 'Milk Delivery';

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(businessName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.feedback_outlined, color: AppTheme.textSecondary),
                tooltip: 'Give feedback',
                onPressed: () => showFeedbackDialog(context),
              ),
            ],
          ),
          if (_offline) ...[
            const SizedBox(height: 8),
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
          const Text('Quick Summary', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildSummaryRow(),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Customers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add'),
                onPressed: () async {
                  final added = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                  );
                  if (added == true) {
                    _loadAll();
                    widget.onCustomersChanged();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Search customer', prefixIcon: Icon(Icons.search)),
            onChanged: (v) {
              _search(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildCustomerList(),

          const SizedBox(height: 28),
          const Text('RECORD QUICK ENTRY', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedCustomer != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(child: Text('For: ${_selectedCustomer!['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _selectedCustomer = null),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text('Search and tap a customer above to select them.', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _fieldWithCaption('Quantity (L)', TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '1.0'),
                      ))),
                      const SizedBox(width: 12),
                      Expanded(child: _fieldWithCaption('Price/L', Container(
                        height: 52,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                        child: Text(_currentPrice != null ? '\u20b9$_currentPrice' : 'Not set', style: const TextStyle(color: AppTheme.textPrimary)),
                      ))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fieldWithCaption('Date', GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 60)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(longDate(_selectedDate)),
                    ),
                  )),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton(
                    onPressed: _saving ? null : _saveEntry,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('RECORD ENTRY'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldWithCaption(String caption, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _buildSummaryRow() {
    final items = [
      ('Deliveries', '${_summary?['deliveries_this_month'] ?? 0}', Icons.local_shipping_outlined, null),
      ('Total Milk', '${_summary?['total_litres_this_month'] ?? 0}L', Icons.water_drop_outlined, null),
      ('Milk Rate', _currentPrice != null ? '\u20b9$_currentPrice' : 'Set now', Icons.currency_rupee, _openSetRateDialog),
      ('Pending', '${_summary?['pending_today'] ?? 0}', Icons.pending_outlined, null),
    ];
    return SizedBox(
      height: 88,
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: GestureDetector(
                    onTap: item.$4 as VoidCallback?,
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(item.$3 as IconData, size: 16, color: AppTheme.textSecondary),
                            Text(item.$1 as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            Text(item.$2 as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCustomerList() {
    final list = _searchController.text.isNotEmpty ? _searchResults : _recentCustomers;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No customers yet - tap "Add" to create one.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = list[i];
          final hasToday = c['has_entry_today'] == true;
          return GestureDetector(
            onTap: () => setState(() => _selectedCustomer = c),
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: _selectedCustomer?['id'] == c['id'] ? Border.all(color: AppTheme.accent, width: 1.5) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (c['last_quantity_litres'] != null)
                    Text('${c['last_quantity_litres']} L', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: hasToday ? AppTheme.success : AppTheme.warning),
                      const SizedBox(width: 4),
                      Text(hasToday ? 'Done today' : 'Pending', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
