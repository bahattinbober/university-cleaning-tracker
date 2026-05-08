import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class KpiDetailScreen extends StatefulWidget {
  final int? userId; // null ise kendi KPI'ını getir
  const KpiDetailScreen({super.key, this.userId});

  @override
  State<KpiDetailScreen> createState() => _KpiDetailScreenState();
}

class _KpiDetailScreenState extends State<KpiDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _errorMessage;

  bool _trendLoading = true;
  List<Map<String, dynamic>> _trendData = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchKpi(), _fetchTrend()]);
  }

  Future<void> _fetchKpi() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final url = widget.userId != null
          ? 'http://192.168.1.27:4000/api/kpi/user/${widget.userId}'
          : 'http://192.168.1.27:4000/api/kpi/me';

      final response = await http.get(
        Uri.parse(url),
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
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Hata: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTrend() async {
    if (!mounted) return;
    setState(() => _trendLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uid = widget.userId ?? (prefs.getInt('userId') ?? -1);
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/kpi/trend/$uid'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        setState(() {
          _trendData = list.cast<Map<String, dynamic>>();
          _trendLoading = false;
        });
      } else {
        if (mounted) setState(() => _trendLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _trendLoading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_fetchKpi(), _fetchTrend()]);
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF7C3AED);
    if (score >= 70) return AppColors.success;
    if (score >= 55) return const Color(0xFF3B82F6);
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  void _showBreakdownDialog() {
    if (_data == null) return;
    final breakdown = (_data!['breakdown'] as List?) ?? [];
    final legacyScore = _data!['legacy_score'] as int? ?? 0;
    final legacyMax = _data!['legacy_max'] as int? ?? 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kazanım Detayı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...breakdown.map((item) {
                final m = item as Map<String, dynamic>;
                final points = m['points'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m['label']}: ${m['count']}',
                          style: AppTextStyles.body,
                        ),
                      ),
                      Text(
                        m['formula']?.toString() ?? '',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: points >= 0
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          points >= 0 ? '+$points' : '$points',
                          style: AppTextStyles.caption.copyWith(
                            color: points >= 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ham Puan:',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '$legacyScore / $legacyMax maksimum',
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Bu detay, her davranışın puana katkısını gösterir. '
                        'Final skor Balanced Scorecard formülüyle hesaplanır.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Performans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
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
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.md),
                          _buildOverallScore(),
                          const SizedBox(height: AppSpacing.md),
                          _buildComponents(),
                          const SizedBox(height: AppSpacing.md),
                          _buildBenchmark(),
                          const SizedBox(height: AppSpacing.md),
                          _buildTargetCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildTrendCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildRecommendationsCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildAchievementsCard(),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton.icon(
                            onPressed: _showBreakdownDialog,
                            icon: const Icon(Icons.search),
                            label: const Text('Kazanım Detayını Göster'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final user = _data!['user'] as Map<String, dynamic>;
    final level = _data!['level'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                level['emoji']?.toString() ?? '👤',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name']?.toString() ?? '-',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seviye ${level['number']}: ${level['name']}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildOverallScore() {
    final score = _data!['overall_score'] as int? ?? 0;
    final maxScore = _data!['max_score'] as int? ?? 100;
    final grade = _data!['grade']?.toString() ?? '-';
    final color = _scoreColor(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'GENEL SKOR',
              style: AppTextStyles.caption
                  .copyWith(letterSpacing: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  ' / $maxScore',
                  style: AppTextStyles.body
                      .copyWith(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Not: $grade',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / maxScore,
                minHeight: 12,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponents() {
    final components = _data!['components'] as Map<String, dynamic>;
    const items = ['productivity', 'quality', 'timeliness', 'compliance'];
    const icons = <String, IconData>{
      'productivity': Icons.speed,
      'quality': Icons.star,
      'timeliness': Icons.schedule,
      'compliance': Icons.verified,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bileşen Analizi', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.xs),
            Text('Balanced Scorecard yaklaşımı',
                style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            ...items.map((key) {
              final c = components[key] as Map<String, dynamic>;
              final value = c['value'] as int? ?? 0;
              final weight = c['weight'] as int? ?? 0;
              final label = c['label']?.toString() ?? '';
              final color = _scoreColor(value);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icons[key], color: color, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          label,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Text('(%$weight ağırlık)',
                            style: AppTextStyles.caption),
                        const Spacer(),
                        Text(
                          '$value/100',
                          style: AppTextStyles.body.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value / 100,
                        minHeight: 8,
                        backgroundColor:
                            Colors.grey.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
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

  Widget _buildBenchmark() {
    final benchmark = _data!['benchmark'] as Map<String, dynamic>;
    final stats = _data!['stats'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Karşılaştırma', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            _benchmarkRow(
                'Senin kayıtların:', '${stats['total']}',
                bold: true),
            const SizedBox(height: 4),
            _benchmarkRow('Sistem ortalaması:',
                '${benchmark['system_average_records']}'),
            const SizedBox(height: 4),
            _benchmarkRow(
                'Verimlilik hedefi:',
                '${benchmark['productivity_target']} kayıt'),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard() {
    final benchmark = _data!['benchmark'] as Map<String, dynamic>;
    final stats = _data!['stats'] as Map<String, dynamic>;
    final target = benchmark['target'] as int?;
    final completion = benchmark['target_completion'] as int?;
    final total = stats['total'] as int? ?? 0;

    if (target == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.flag_outlined,
                  color: AppColors.textSecondary, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Haftalık Hedef',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Yöneticin sana henüz hedef atamadı.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pct = (completion ?? 0).clamp(0, 100);
    final color = pct >= 85
        ? AppColors.success
        : pct >= 60
            ? AppColors.warning
            : AppColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Haftalık Hedef Tutturma',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 10,
                        backgroundColor:
                            Colors.grey.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                      ),
                      Center(
                        child: Text(
                          '%$pct',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total / $target',
                      style: AppTextStyles.heading2,
                    ),
                    Text('kayıt / hedef',
                        style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pct >= 100
                            ? 'Hedefe Ulaşıldı!'
                            : '${target - total} kayıt kaldı',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('7 Günlük Trend', style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Günlük temizlik kaydı sayısı',
                style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            if (_trendLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_trendData.isEmpty ||
                _trendData.every((d) => (d['count'] as int? ?? 0) == 0))
              const SizedBox(
                height: 100,
                child: Center(
                  child: Text('Bu hafta henüz kayıt yok.',
                      style: AppTextStyles.caption),
                ),
              )
            else
              SizedBox(height: 200, child: _buildLineChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    double maxY = 1;

    for (int i = 0; i < _trendData.length; i++) {
      final count = (_trendData[i]['count'] as int? ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxY) maxY = count;
    }

    String dayLabel(int index) {
      if (index < 0 || index >= _trendData.length) return '';
      final dateStr = _trendData[index]['date'] as String? ?? '';
      try {
        final dt = DateTime.parse(dateStr);
        const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
        return names[(dt.weekday - 1) % 7];
      } catch (_) {
        return '';
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final label = dayLabel(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style:
                    AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) =>
                  FlDotCirclePainter(
                radius: 4,
                color: AppColors.primary,
                strokeColor: Colors.white,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'trending_up':
        return Icons.trending_up;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'description':
        return Icons.description;
      case 'schedule':
        return Icons.schedule;
      case 'flag':
        return Icons.flag;
      case 'check_circle':
        return Icons.check_circle;
      case 'bolt':
        return Icons.bolt;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildRecommendationsCard() {
    final recommendations =
        (_data!['recommendations'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Gelişim Önerileri',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Karar destek sistemi tabanlı kişisel öneriler',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            ...recommendations.map((r) {
              final rec = r as Map<String, dynamic>;
              final priority = rec['priority'] as String? ?? 'info';
              final color = priority == 'high'
                  ? AppColors.error
                  : priority == 'medium'
                      ? AppColors.warning
                      : AppColors.success;
              final iconData =
                  _iconFromName(rec['icon'] as String? ?? '');

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconData, color: color, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec['title'] as String? ?? '',
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec['message'] as String? ?? '',
                            style: AppTextStyles.caption,
                          ),
                        ],
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

  Widget _buildAchievementsCard() {
    final ach = _data!['achievements'] as Map<String, dynamic>?;
    if (ach == null) return const SizedBox.shrink();

    final items =
        (ach['items'] as List).cast<Map<String, dynamic>>();
    final completedCount = ach['completed_count'] as int? ?? 0;
    final totalCount = ach['total_count'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Başarı Göstergeleri',
                    style: AppTextStyles.heading2),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedCount/$totalCount',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Performans tabanlı kademeli başarı izleme',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final completed = item['completed'] as bool? ?? false;
                final progress = item['progress'] as int? ?? 0;
                final color = completed
                    ? AppColors.primary
                    : AppColors.textSecondary;

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: completed
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _iconFromName(
                            item['icon'] as String? ?? ''),
                        color: color,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              item['name'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: completed
                                    ? Colors.black87
                                    : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              completed
                                  ? 'Tamamlandı'
                                  : '%$progress',
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _benchmarkRow(String label, String value,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Text(
          value,
          style: bold
              ? AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body,
        ),
      ],
    );
  }
}
