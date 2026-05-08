import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String? _errorMessage;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('userRole');
    await _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final list = jsonDecode(response.body) as List;
        setState(() {
          _items = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Veri alinamadi (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Baglanti hatasi: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final amountController = TextEditingController();
    final thresholdController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Malzeme Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Malzeme Adi',
                  hintText: 'Orn: Camasir deterjani',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Birim',
                  hintText: 'litre / paket / adet',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Mevcut Stok',
                  hintText: '5',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: thresholdController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Min. Seviye (alarm)',
                  hintText: '1',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                final response = await http.post(
                  Uri.parse('http://192.168.1.27:4000/api/inventory'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'name': nameController.text,
                    'unit': unitController.text,
                    'current_amount':
                        double.tryParse(amountController.text) ?? 0,
                    'min_threshold':
                        double.tryParse(thresholdController.text) ?? 0,
                  }),
                );
                if (response.statusCode == 201) {
                  navigator.pop();
                  await _fetchInventory();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Malzeme eklendi')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Hata: ${response.body}')),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Hata: $e')),
                );
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(Map<String, dynamic> item) {
    final amountController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item['name']} - Stok Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mevcut: ${item['current_amount']} ${item['unit']}',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Eklenecek Miktar (${item['unit']})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                final response = await http.put(
                  Uri.parse(
                    'http://192.168.1.27:4000/api/inventory/${item['id']}/restock',
                  ),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'amount': double.tryParse(amountController.text) ?? 0,
                  }),
                );
                if (response.statusCode == 200) {
                  navigator.pop();
                  await _fetchInventory();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Stok guncellendi')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Hata: ${response.statusCode}')),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Hata: $e')),
                );
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // ── Alert level helpers ──────────────────────────────────────────────────

  Color _alertColor(String? level) {
    switch (level) {
      case 'depleted':
        return Colors.black87;
      case 'critical':
        return AppColors.error;
      case 'reorder':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _alertLabel(String? level) {
    switch (level) {
      case 'depleted':
        return 'Tukendi';
      case 'critical':
        return 'Kritik';
      case 'reorder':
        return 'Siparis Zamani';
      default:
        return 'Normal';
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin';

    // Section grouping (existing, by status)
    final criticalItems =
        _items.where((i) => i['status'] == 'critical').toList();
    final warningItems =
        _items.where((i) => i['status'] == 'warning').toList();
    final normalItems =
        _items.where((i) => i['status'] == 'normal').toList();

    // Summary chip counts (by alert_level)
    final normalCount =
        _items.where((i) => i['alert_level'] == 'normal').length;
    final reorderCount =
        _items.where((i) => i['alert_level'] == 'reorder').length;
    final criticalAlertCount = _items
        .where((i) =>
            i['alert_level'] == 'critical' || i['alert_level'] == 'depleted')
        .length;

    // Items that need ordering
    final orderItems = _items
        .where((i) =>
            i['alert_level'] == 'reorder' ||
            i['alert_level'] == 'critical' ||
            i['alert_level'] == 'depleted')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Yonetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'ABC Analizi',
            onPressed: () => Navigator.pushNamed(context, '/abc-analysis'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInventory,
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _fetchInventory,
                  child: _items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Henuz malzeme yok\n+ butonu ile ekleyin',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            // Summary chips
                            _buildSummaryChips(
                                normalCount, reorderCount, criticalAlertCount),
                            const SizedBox(height: AppSpacing.md),

                            // Siparis onerileri (only when needed)
                            _buildOrderSuggestions(orderItems),
                            if (orderItems.isNotEmpty)
                              const SizedBox(height: AppSpacing.md),

                            // Existing sections
                            if (criticalItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Kritik Seviyede',
                                count: criticalItems.length,
                                color: AppColors.error,
                                icon: Icons.warning,
                              ),
                              ...criticalItems.map(
                                (item) => _buildItemCard(item, isAdmin),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (warningItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Dikkat',
                                count: warningItems.length,
                                color: AppColors.warning,
                                icon: Icons.info,
                              ),
                              ...warningItems.map(
                                (item) => _buildItemCard(item, isAdmin),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (normalItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Normal Stok',
                                count: normalItems.length,
                                color: AppColors.success,
                                icon: Icons.inventory_2_outlined,
                              ),
                              ...normalItems.map(
                                (item) => _buildItemCard(item, isAdmin),
                              ),
                            ],
                          ],
                        ),
                ),
    );
  }

  // ── Summary chips ────────────────────────────────────────────────────────

  Widget _buildSummaryChips(
      int normalCount, int reorderCount, int criticalCount) {
    return Row(
      children: [
        _chip('Normal: $normalCount', AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        _chip('Siparis: $reorderCount', AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        _chip('Kritik: $criticalCount', AppColors.error),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Siparis onerileri card ───────────────────────────────────────────────

  Widget _buildOrderSuggestions(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    color: AppColors.warning, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Siparis Onerileri (${items.length} urun)',
                    style: AppTextStyles.heading2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wilson EOQ tabanli yeniden siparis noktasi',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            ...items.map((item) {
              final alertLevel = item['alert_level']?.toString();
              final color = _alertColor(alertLevel);
              final daysRemaining = item['days_remaining'];
              final reorderPoint = item['reorder_point'];
              final suggestedOrder = item['suggested_order'];

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: color),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? '-',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mevcut: ${item['current_amount']} ${item['unit']} / ROP: ${reorderPoint ?? item['min_threshold']} ${item['unit']}',
                      style: AppTextStyles.caption,
                    ),
                    if (suggestedOrder != null)
                      Text(
                        'Onerilen siparis: $suggestedOrder ${item['unit']}',
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (daysRemaining != null)
                      Text(
                        'Tahmini bitis: $daysRemaining gun',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Item card ────────────────────────────────────────────────────────────

  Widget _buildItemCard(Map<String, dynamic> item, bool isAdmin) {
    final alertLevel = item['alert_level']?.toString();
    final alertColor = _alertColor(alertLevel);
    final label = _alertLabel(alertLevel);
    final daysRemaining = item['days_remaining'];
    final dailyAvg = item['daily_average'] ?? 0;
    final reorderPoint = item['reorder_point'];
    final suggestedOrder = item['suggested_order'];
    final needsOrder = alertLevel == 'reorder' ||
        alertLevel == 'critical' ||
        alertLevel == 'depleted';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left border strip
            Container(width: 5, color: alertColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: alertColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            item['name']?.toString() ?? '-',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.add_box),
                            color: AppColors.primary,
                            tooltip: 'Stok Ekle',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showRestockDialog(item),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Stock amount
                    Text(
                      'Stokta: ${item['current_amount']} ${item['unit']}',
                      style: AppTextStyles.body.copyWith(
                        color: alertColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    // Days remaining
                    if (daysRemaining != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Tahmini bitis: $daysRemaining gun sonra',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],

                    // Daily avg
                    if ((dailyAvg as num) > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Gunluk ortalama: $dailyAvg ${item['unit']}',
                        style: AppTextStyles.caption,
                      ),
                    ],

                    // Min threshold
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Min. seviye: ${item['min_threshold']} ${item['unit']}',
                      style: AppTextStyles.caption,
                    ),

                    // Reorder point
                    if (reorderPoint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Yeniden siparis seviyesi: $reorderPoint ${item['unit']}',
                        style: AppTextStyles.caption,
                      ),
                    ],

                    // Suggested order (only when needed)
                    if (needsOrder && suggestedOrder != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 14, color: alertColor),
                          const SizedBox(width: 4),
                          Text(
                            'Onerilen siparis: $suggestedOrder ${item['unit']}',
                            style: AppTextStyles.caption.copyWith(
                              color: alertColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: AppTextStyles.heading2.copyWith(color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
