import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ForecastScreen extends StatefulWidget {
  final int itemId;
  final String itemName;
  final String itemUnit;

  const ForecastScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.itemUnit,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
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
        Uri.parse(
            'http://192.168.1.27:4000/api/inventory/${widget.itemId}/forecast'),
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
          _errorMessage = 'Veri alinamadi (${response.statusCode})';
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
        title: Text('Tahmin: ${widget.itemName}'),
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
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final hasData = summary['has_data'] as bool;

    if (!hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              const SizedBox(height: AppSpacing.md),
              Text(
                summary['message'] as String,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSummaryCard(summary),
          const SizedBox(height: AppSpacing.md),
          _buildChart(),
          const SizedBox(height: AppSpacing.md),
          _buildMethodsCard(),
          const SizedBox(height: AppSpacing.md),
          _buildForecastTable(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final avgDaily = summary['avg_daily_usage'];
    final total7 = summary['total_7day_forecast'] as num;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Talep Tahmini', style: AppTextStyles.heading1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(summary['message'] as String, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'Gunluk Ortalama',
                    '$avgDaily ${widget.itemUnit}',
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _statBox(
                    '7 Gun Tahmini',
                    '${total7.toStringAsFixed(1)} ${widget.itemUnit}',
                    AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChart() {
    final historical =
        (_data!['historical'] as List).cast<Map<String, dynamic>>();
    final forecast =
        (_data!['forecast'] as List).cast<Map<String, dynamic>>();

    final histPoints = <FlSpot>[];
    for (int i = 0; i < historical.length; i++) {
      histPoints.add(
          FlSpot(i.toDouble(), (historical[i]['usage'] as num).toDouble()));
    }

    final forePoints = <FlSpot>[];
    if (histPoints.isNotEmpty) {
      forePoints.add(histPoints.last);
    }
    final foreStart = historical.length;
    for (int i = 0; i < forecast.length; i++) {
      forePoints.add(FlSpot(
        (foreStart + i).toDouble(),
        (forecast[i]['forecast'] as num).toDouble(),
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30 Gun Gecmis + 7 Gun Tahmin',
                style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i == 0) {
                            return const Text('30g\nonce',
                                style: TextStyle(fontSize: 9));
                          }
                          if (i == 15) {
                            return const Text('15g\nonce',
                                style: TextStyle(fontSize: 9));
                          }
                          if (i == 30) {
                            return const Text('Bugun',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold));
                          }
                          if (i == 37) {
                            return const Text('+7g',
                                style: TextStyle(fontSize: 9));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: histPoints,
                      isCurved: false,
                      color: AppColors.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: forePoints,
                      isCurved: true,
                      color: AppColors.warning,
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _legendDot(AppColors.primary, 'Gecmis kullanim'),
                const SizedBox(width: AppSpacing.md),
                _legendDot(AppColors.warning, 'Tahmin (7 gun)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // ── Methods ───────────────────────────────────────────────────────────────

  Widget _buildMethodsCard() {
    final methods = _data!['methods'] as Map<String, dynamic>;
    final ma = methods['moving_average'];
    final es = methods['exponential_smoothing'];
    final lt = methods['linear_trend_slope'] as num;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tahmin Yontemleri', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            _methodRow('Moving Average (5 gun)', '$ma ${widget.itemUnit}/gun'),
            _methodRow(
                'Exponential Smoothing (a=0.3)', '$es ${widget.itemUnit}/gun'),
            _methodRow(
              'Linear Trend (egim)',
              lt > 0
                  ? '+${lt.toStringAsFixed(2)} (artan)'
                  : '${lt.toStringAsFixed(2)} (azalan)',
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Tahmin, uc yontemin ortalamasidir. Linear trend, '
                'gelecek gunler icin hafifce artar/azalir.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodRow(String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(name, style: AppTextStyles.body)),
          Text(value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildForecastTable() {
    final forecast =
        (_data!['forecast'] as List).cast<Map<String, dynamic>>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7 Gunluk Detay', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            Table(
              border:
                  TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08)),
                  children: [
                    _th('Tarih'),
                    _th('Tahmin'),
                  ],
                ),
                ...forecast.map((f) {
                  final date = DateTime.parse(f['day'] as String);
                  final dateStr = '${date.day}.${date.month}';
                  final val = (f['forecast'] as num).toStringAsFixed(1);
                  return TableRow(
                    children: [
                      _td(dateStr),
                      _td('$val ${widget.itemUnit}'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _td(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: AppTextStyles.body),
      );
}
