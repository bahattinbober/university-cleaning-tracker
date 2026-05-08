import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _fetchKpi();
  }

  Future<void> _fetchKpi() async {
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
            onPressed: _fetchKpi,
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
                      onRefresh: _fetchKpi,
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
      'quality':      Icons.star,
      'timeliness':   Icons.schedule,
      'compliance':   Icons.verified,
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
                'Senin kayıtların:', '${stats['total']}', bold: true),
            const SizedBox(height: 4),
            _benchmarkRow('Sistem ortalaması:',
                '${benchmark['system_average_records']}'),
            const SizedBox(height: 4),
            _benchmarkRow(
                'Hedef:', '${benchmark['productivity_target']}'),
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
              ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body,
        ),
      ],
    );
  }
}
