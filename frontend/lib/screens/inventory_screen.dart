import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';
import 'forecast_screen.dart';

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

  Future<void> _generatePdfReport() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok listesi boş, önce yükleme yapın')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF oluşturuluyor...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final abcResponse = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/inventory/abc-analysis'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (abcResponse.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ABC verisi alınamadı')),
          );
        }
        return;
      }
      final abcData =
          jsonDecode(abcResponse.body) as Map<String, dynamic>;
      await PdfReportService.generateInventoryReport(
        inventoryItems: _items,
        abcData: abcData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
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

  // ── Cost dialog ──────────────────────────────────────────────────────────

  void _showCostDialog(Map<String, dynamic> item) {
    final costController = TextEditingController(
      text: (item['unit_cost'] as num? ?? 0).toString(),
    );
    final categoryController = TextEditingController(
      text: item['category']?.toString() ?? 'Genel',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Maliyet: ${item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costController,
              decoration: const InputDecoration(
                labelText: 'Birim Maliyet (TL)',
                hintText: 'Örn: 50.00',
                prefixText: '₺ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'Örn: Temizlik Sıvısı',
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
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final newCost =
                  double.tryParse(costController.text);
              if (newCost == null || newCost < 0) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Geçerli maliyet girin')),
                );
                return;
              }
              final prefs =
                  await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              final response = await http.put(
                Uri.parse(
                    'http://192.168.1.27:4000/api/inventory/${item['id']}/cost'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'unit_cost': newCost,
                  'category':
                      categoryController.text.trim(),
                }),
              );
              if (response.statusCode == 200) {
                navigator.pop();
                await _fetchInventory();
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Maliyet güncellendi')),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                      content:
                          Text('Güncelleme başarısız')),
                );
              }
            },
            child: const Text('Kaydet'),
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
        return 'Tükendi';
      case 'critical':
        return 'Kritik';
      case 'reorder':
        return 'Sipariş Zamanı';
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
        title: const Text('Stok Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF Rapor',
            onPressed: _generatePdfReport,
          ),
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Envanter Metodolojisi',
            onPressed: () =>
                Navigator.pushNamed(context, '/inventory-methodology'),
          ),
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
        _chip('Sipariş: $reorderCount', AppColors.warning),
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
                    'Sipariş Önerileri (${items.length} ürün)',
                    style: AppTextStyles.heading2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wilson EOQ tabanlı yeniden sipariş noktası',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            ...items.map((item) {
              final alertLevel = item['alert_level']?.toString();
              final color = _alertColor(alertLevel);
              final daysRemaining = item['days_remaining'];
              final reorderPoint = item['reorder_point'];
              final suggestedOrder = item['suggested_order'];
              final eoqOrder = item['eoq_optimal_order'];

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
                        'Önerilen sipariş: $suggestedOrder ${item['unit']}',
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (eoqOrder != null && (eoqOrder as num) > 0)
                      Text(
                        'EOQ optimum: $eoqOrder ${item['unit']}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (daysRemaining != null)
                      Text(
                        'Tahmini bitiş: $daysRemaining gün',
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
    final eoq = item['eoq_optimal_order'];
    final daysBetween = item['days_between_orders'];
    final unitCost =
        (item['unit_cost'] as num? ?? 0).toDouble();
    final estimatedValue =
        (item['estimated_value'] as num? ?? 0).toDouble();
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
                        if ((item['daily_average'] as num? ?? 0) > 0)
                          IconButton(
                            icon: const Icon(Icons.trending_up),
                            color: AppColors.warning,
                            tooltip: 'Talep Tahmini',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForecastScreen(
                                  itemId: item['id'] as int,
                                  itemName:
                                      item['name']?.toString() ?? '-',
                                  itemUnit:
                                      item['unit']?.toString() ?? '',
                                ),
                              ),
                            ),
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
                            'Tahmini bitiş: $daysRemaining gün sonra',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],

                    // Daily avg
                    if ((dailyAvg as num) > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Günlük ortalama: $dailyAvg ${item['unit']}',
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
                        'Yeniden sipariş seviyesi: $reorderPoint ${item['unit']}',
                        style: AppTextStyles.caption,
                      ),
                    ],

                    // EOQ
                    if (eoq != null && (eoq as num) > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Optimum sipariş (EOQ): $eoq ${item['unit']}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                    if (daysBetween != null && (daysBetween as num) > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sipariş aralığı: $daysBetween gün',
                        style: AppTextStyles.caption,
                      ),
                    ],

                    // Birim maliyet (admin only)
                    if (isAdmin) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              unitCost > 0
                                  ? 'Birim: ${unitCost.toStringAsFixed(2)} TL  •  '
                                    'Değer: ${estimatedValue.toStringAsFixed(2)} TL'
                                  : 'Maliyet girilmemiş (tıkla)',
                              style: AppTextStyles.caption.copyWith(
                                color: unitCost > 0
                                    ? Colors.grey
                                    : AppColors.warning,
                                fontStyle: unitCost > 0
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showCostDialog(item),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit,
                                  size: 14,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
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
                            'Önerilen sipariş: $suggestedOrder ${item['unit']}',
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
