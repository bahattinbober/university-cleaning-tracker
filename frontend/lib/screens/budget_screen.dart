import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _trend;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(
            Uri.parse(
                'http://192.168.1.27:4000/api/budget/summary'),
            headers: headers),
        http.get(
            Uri.parse(
                'http://192.168.1.27:4000/api/budget/trend'),
            headers: headers),
      ]);

      if (!mounted) return;

      if (results[0].statusCode == 200 &&
          results[1].statusCode == 200) {
        setState(() {
          _summary =
              jsonDecode(results[0].body) as Map<String, dynamic>;
          _trend =
              jsonDecode(results[1].body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Veri alınamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Hata: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bütçe / Maliyet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView(
                    padding:
                        const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: AppSpacing.md),
                      _buildTrendCard(),
                      const SizedBox(height: AppSpacing.md),
                      _buildCategoryCard(),
                      const SizedBox(height: AppSpacing.md),
                      _buildTopItemsCard(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final totalValue =
        (_summary!['total_value'] as num? ?? 0).toDouble();
    final consumed =
        (_summary!['consumed_cost'] as num? ?? 0).toDouble();
    final itemCount =
        (_summary!['item_count'] as num? ?? 0).toInt();
    final costedItems =
        (_summary!['costed_items'] as num? ?? 0).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Bütçe Özeti',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$costedItems / $itemCount kalem fiyatlandırılmış',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'Toplam Stok Değeri',
                    '${totalValue.toStringAsFixed(2)} TL',
                    AppColors.primary,
                    Icons.inventory_2,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _statBox(
                    'Son 30 Gün Tüketim',
                    '${consumed.toStringAsFixed(2)} TL',
                    AppColors.warning,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Trend Bar Chart ───────────────────────────────────────────

  Widget _buildTrendCard() {
    final trend = (_trend!['trend'] as List)
        .cast<Map<String, dynamic>>();
    final total =
        (_trend!['total_6mo'] as num? ?? 0).toDouble();
    final avg =
        (_trend!['avg_monthly'] as num? ?? 0).toDouble();

    double maxY = 0;
    for (final t in trend) {
      final v = (t['cost'] as num? ?? 0).toDouble();
      if (v > maxY) maxY = v;
    }
    if (maxY == 0) maxY = 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('6 Aylık Maliyet Trendi',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Toplam: ${total.toStringAsFixed(2)} TL  •  '
              'Ortalama: ${avg.toStringAsFixed(2)} TL/ay',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment:
                      BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  gridData:
                      const FlGridData(show: false),
                  borderData:
                      FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 &&
                              i < trend.length) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                      top: 4),
                              child: Text(
                                trend[i]['label']
                                        ?.toString() ??
                                    '',
                                style: const TextStyle(
                                    fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  barGroups:
                      List.generate(trend.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (trend[i]['cost'] as num? ??
                                  0)
                              .toDouble(),
                          color: AppColors.success,
                          width: 22,
                          borderRadius:
                              const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Pie Chart ────────────────────────────────────────

  Widget _buildCategoryCard() {
    final categories = (_summary!['categories'] as List)
        .cast<Map<String, dynamic>>();

    if (categories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Kategori Dağılımı',
                      style: AppTextStyles.heading2),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Henüz fiyatlandırılmış kalem yok',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    }

    final total = categories.fold<double>(
        0,
        (sum, c) =>
            sum + (c['value'] as num? ?? 0).toDouble());

    const colors = [
      AppColors.primary,
      AppColors.warning,
      AppColors.success,
      AppColors.error,
      AppColors.adminAccent,
      Colors.teal,
      Colors.purple,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Kategori Dağılımı',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: List.generate(
                    categories.length,
                    (i) {
                      final c = categories[i];
                      final value = (c['value'] as num? ?? 0)
                          .toDouble();
                      final pct = total > 0
                          ? (value / total) * 100
                          : 0.0;
                      return PieChartSectionData(
                        value: value,
                        title:
                            '${pct.toStringAsFixed(1)}%',
                        color: colors[i % colors.length],
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(categories.length, (i) {
              final c = categories[i];
              final value =
                  (c['value'] as num? ?? 0).toDouble();
              final count =
                  (c['item_count'] as num? ?? 0).toInt();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius:
                            BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c['category']?.toString() ??
                            'Genel',
                        style: AppTextStyles.body,
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(2)} TL ($count kalem)',
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

  // ── Top 10 Items ──────────────────────────────────────────────

  Widget _buildTopItemsCard() {
    final items = (_summary!['top_items'] as List)
        .cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Fiyatlandırılmış kalem yok',
              style: AppTextStyles.caption),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star,
                    color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Top 10 Maliyetli Kalem',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final value = (item['total_value'] as num? ?? 0)
                  .toDouble();
              final cost =
                  (item['unit_cost'] as num? ?? 0).toDouble();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']?.toString() ?? '-',
                            style: AppTextStyles.body,
                          ),
                          Text(
                            '${item['current_amount']} ${item['unit']} × '
                            '${cost.toStringAsFixed(2)} TL',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(2)} TL',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
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
}
