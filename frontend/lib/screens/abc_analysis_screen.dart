import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class AbcAnalysisScreen extends StatefulWidget {
  const AbcAnalysisScreen({super.key});

  @override
  State<AbcAnalysisScreen> createState() => _AbcAnalysisScreenState();
}

class _AbcAnalysisScreenState extends State<AbcAnalysisScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
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
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/inventory/abc-analysis'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
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

  Color _classColor(String cls) {
    switch (cls) {
      case 'A':
        return AppColors.error;
      case 'B':
        return AppColors.warning;
      case 'C':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABC Analizi'),
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
              : _data == null
                  ? const Center(child: Text('Veri yok'))
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.md),
                          _buildPieChart(),
                          const SizedBox(height: AppSpacing.md),
                          _buildSummary(),
                          const SizedBox(height: AppSpacing.md),
                          _buildItemsList(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final totalItems = summary['total_items'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Pareto Tabanlı Sınıflandırma',
                    style: AppTextStyles.heading1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$totalItems stok kalemi son 30 günlük kullanım hacmine göre sınıflandırıldı.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '80/20 Yasası: A sınıfı kalemler, toplam stok hareketinin %80\'ini oluşturur ve öncelikli takip gerektirir.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final aPct = (summary['a_percentage'] as num?)?.toDouble() ?? 0;
    final bPct = (summary['b_percentage'] as num?)?.toDouble() ?? 0;
    final cPct = (summary['c_percentage'] as num?)?.toDouble() ?? 0;

    if (aPct + bPct + cPct == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Henüz yeterli kullanım verisi yok\n(Son 30 günde stok hareketi olmalı)',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text('Toplam Kullanım Dağılımı',
                style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (aPct > 0)
                      PieChartSectionData(
                        value: aPct,
                        title: '%${aPct.toStringAsFixed(0)}',
                        color: AppColors.error,
                        radius: 60,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (bPct > 0)
                      PieChartSectionData(
                        value: bPct,
                        title: '%${bPct.toStringAsFixed(0)}',
                        color: AppColors.warning,
                        radius: 55,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (cPct > 0)
                      PieChartSectionData(
                        value: cPct,
                        title: '%${cPct.toStringAsFixed(0)}',
                        color: AppColors.success,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              children: [
                _legend('A', AppColors.error, 'Kritik'),
                _legend('B', AppColors.warning, 'Orta'),
                _legend('C', AppColors.success, 'Düşük'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color, String desc) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label - $desc', style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildSummary() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final aCount = summary['a_count'] as int;
    final bCount = summary['b_count'] as int;
    final cCount = summary['c_count'] as int;
    final aPct = summary['a_percentage'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sınıf Özeti', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.md),
            _classRow('A', AppColors.error, aCount, 'Yüksek değerli, kritik kalemler'),
            const SizedBox(height: AppSpacing.sm),
            _classRow('B', AppColors.warning, bCount, 'Orta değerli kalemler'),
            const SizedBox(height: AppSpacing.sm),
            _classRow('C', AppColors.success, cCount, 'Düşük değerli kalemler'),
            if (aCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: AppColors.error, width: 3),
                  ),
                ),
                child: Text(
                  'A sınıfı $aCount kalem, toplam kullanımın %$aPct\'sini oluşturuyor. Bu kalemler için yakın takip ve sürekli stok kontrolü önerilir.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _classRow(String cls, Color color, int count, String desc) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            cls,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sinif $cls — $count kalem',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(desc, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    final items =
        (_data!['items'] as List).cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text('Henüz stok kalemi yok',
                style: AppTextStyles.caption),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sınıflandırılmış Liste', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.xs),
            Text('Kullanım hacmine göre azalan sırada',
                style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            ...items.map((item) {
              final cls = item['abc_class'] as String;
              final color = _classColor(cls);
              final usage = (item['total_usage'] as num).toDouble();
              final pct = (item['percentage'] as num).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cls,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']?.toString() ?? '',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Kullanim: ${usage.toStringAsFixed(1)} ${item['unit'] ?? ''}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '%${pct.toStringAsFixed(1)}',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          'toplam',
                          style:
                              AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ],
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
