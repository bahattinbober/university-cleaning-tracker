import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
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
            'http://192.168.1.27:4000/api/cleaning/comparison'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _data =
              jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Veri alınamadı (${response.statusCode})';
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
        title: const Text('Karşılaştırmalı Analiz'),
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
                        padding:
                            const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _buildPeriodCard(
                            title: 'Bu Hafta vs Geçen Hafta',
                            data: _data!['week']
                                as Map<String, dynamic>,
                            thisLabel: 'Bu Hafta',
                            lastLabel: 'Geçen Hafta',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildPeriodCard(
                            title: 'Bu Ay vs Geçen Ay',
                            data: _data!['month']
                                as Map<String, dynamic>,
                            thisLabel: 'Bu Ay (30 gün)',
                            lastLabel: 'Geçen Ay (30 gün)',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildDailyChart(),
                          const SizedBox(height: AppSpacing.md),
                          _buildInsightsCard(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
    );
  }

  // ── Period Card ───────────────────────────────────────────────

  Widget _buildPeriodCard({
    required String title,
    required Map<String, dynamic> data,
    required String thisLabel,
    required String lastLabel,
  }) {
    final thisValue = (data['this'] as num? ?? 0).toInt();
    final lastValue = (data['last'] as num? ?? 0).toInt();
    final changePct =
        (data['change_pct'] as num? ?? 0).toDouble();
    final trend = data['trend']?.toString() ?? 'stable';

    final Color trendColor;
    final IconData trendIcon;
    final String trendText;
    if (trend == 'up') {
      trendColor = AppColors.success;
      trendIcon = Icons.trending_up;
      trendText = 'Artış';
    } else if (trend == 'down') {
      trendColor = AppColors.error;
      trendIcon = Icons.trending_down;
      trendText = 'Azalış';
    } else {
      trendColor = AppColors.warning;
      trendIcon = Icons.trending_flat;
      trendText = 'Sabit';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _periodBox(
                      thisLabel, thisValue, AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _periodBox(
                      lastLabel, lastValue, Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: trendColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(trendIcon, color: trendColor, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          trendText,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: trendColor,
                          ),
                        ),
                        Text(
                          changePct > 0
                              ? '+${changePct.toStringAsFixed(1)}% değişim'
                              : '${changePct.toStringAsFixed(1)}% değişim',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text('kayıt',
              style:
                  AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  // ── Daily Bar Chart ───────────────────────────────────────────

  Widget _buildDailyChart() {
    final daily = (_data!['daily_comparison'] as List)
        .cast<Map<String, dynamic>>();

    if (daily.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Günlük karşılaştırma verisi yok',
              style: AppTextStyles.caption),
        ),
      );
    }

    double maxY = 0;
    for (final d in daily) {
      final t =
          (d['this_week'] as num? ?? 0).toDouble();
      final l =
          (d['last_week'] as num? ?? 0).toDouble();
      if (t > maxY) maxY = t;
      if (l > maxY) maxY = l;
    }
    if (maxY == 0) maxY = 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Günlük Detay (7 gün)',
                      style: AppTextStyles.heading2),
                ),
              ],
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
                              i < daily.length) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                      top: 4),
                              child: Text(
                                daily[i]['day_label']
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
                  barGroups: List.generate(
                    daily.length,
                    (i) {
                      final t = (daily[i]['this_week']
                                  as num? ??
                              0)
                          .toDouble();
                      final l = (daily[i]['last_week']
                                  as num? ??
                              0)
                          .toDouble();
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: l,
                            color: Colors.grey,
                            width: 8,
                            borderRadius:
                                const BorderRadius.only(
                              topLeft:
                                  Radius.circular(2),
                              topRight:
                                  Radius.circular(2),
                            ),
                          ),
                          BarChartRodData(
                            toY: t,
                            color: AppColors.primary,
                            width: 8,
                            borderRadius:
                                const BorderRadius.only(
                              topLeft:
                                  Radius.circular(2),
                              topRight:
                                  Radius.circular(2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _legendDot(Colors.grey, 'Geçen Hafta'),
                const SizedBox(width: AppSpacing.md),
                _legendDot(
                    AppColors.primary, 'Bu Hafta'),
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
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // ── Insights Card ─────────────────────────────────────────────

  Widget _buildInsightsCard() {
    final week = _data!['week'] as Map<String, dynamic>;
    final month = _data!['month'] as Map<String, dynamic>;
    final weekChange =
        (week['change_pct'] as num? ?? 0).toDouble();
    final monthChange =
        (month['change_pct'] as num? ?? 0).toDouble();

    final String summary;
    if (weekChange > 10 && monthChange > 10) {
      summary =
          'Performansınız sürekli artıyor. Mevcut tempoyu koruyun.';
    } else if (weekChange < -10 && monthChange < -10) {
      summary =
          'Aktivitede belirgin azalış var. Sebepleri inceleyin.';
    } else if (weekChange > 0 && monthChange > 0) {
      summary = 'Kademeli iyileşme gözleniyor.';
    } else if (weekChange < 0 && monthChange > 0) {
      summary =
          'Aylık trend pozitif ama bu hafta geriledi.';
    } else if (weekChange > 0 && monthChange < 0) {
      summary =
          'Bu hafta toparlanıyorsunuz. Devamı için tempo koruyun.';
    } else {
      summary = 'Performans dengeli, büyük değişim yok.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Text('Yorum',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(summary,
                  style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}
