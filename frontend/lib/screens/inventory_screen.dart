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
          _errorMessage = 'Veri alınamadı (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Bağlantı hatası: $e';
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
                  labelText: 'Malzeme Adı',
                  hintText: 'Örn: Çamaşır deterjanı',
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
            child: const Text('İptal'),
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
            child: const Text('İptal'),
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
                    const SnackBar(content: Text('Stok güncellendi')),
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

  Color _statusColor(String? s) {
    switch (s) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'critical':
        return Icons.warning;
      case 'warning':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin';
    final criticalItems =
        _items.where((i) => i['status'] == 'critical').toList();
    final warningItems =
        _items.where((i) => i['status'] == 'warning').toList();
    final normalItems =
        _items.where((i) => i['status'] == 'normal').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Yönetimi'),
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
                              'Henüz malzeme yok\n+ butonu ile ekleyin',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            if (criticalItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: '🚨 Kritik Seviyede',
                                count: criticalItems.length,
                                color: AppColors.error,
                              ),
                              ...criticalItems.map(
                                (item) => _buildItemCard(item, isAdmin),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (warningItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: '⚠️ Dikkat',
                                count: warningItems.length,
                                color: AppColors.warning,
                              ),
                              ...warningItems.map(
                                (item) => _buildItemCard(item, isAdmin),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (normalItems.isNotEmpty) ...[
                              _SectionHeader(
                                title: '📦 Normal Stok',
                                count: normalItems.length,
                                color: AppColors.success,
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

  Widget _buildItemCard(Map<String, dynamic> item, bool isAdmin) {
    final color = _statusColor(item['status']?.toString());
    final daysRemaining = item['days_remaining'];
    final dailyAvg = item['daily_average'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(item['status']?.toString()), color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item['name']?.toString() ?? '-',
                    style: AppTextStyles.heading2,
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.add_box),
                    color: AppColors.primary,
                    tooltip: 'Stok Ekle',
                    onPressed: () => _showRestockDialog(item),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Stokta: ${item['current_amount']} ${item['unit']}',
              style: AppTextStyles.body.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (daysRemaining != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Tahmini bitiş: $daysRemaining gün sonra',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
            if ((dailyAvg as num) > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Günlük ortalama: $dailyAvg ${item['unit']}',
                style: AppTextStyles.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Min. seviye: ${item['min_threshold']} ${item['unit']}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
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
