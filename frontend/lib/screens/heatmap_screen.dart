import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
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
        Uri.parse('http://192.168.1.27:4000/api/cleaning/heatmap'),
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
        title: const Text('Yoğunluk Haritası'),
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
                          _buildSummaryCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildHeatmapCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildLegendCard(),
                          const SizedBox(height: AppSpacing.md),
                          _buildInsightsCard(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard() {
    final total = (_data!['total'] as num? ?? 0).toInt();
    final periodDays = (_data!['period_days'] as num? ?? 30).toInt();
    final avgPerDay =
        periodDays > 0 ? (total / periodDays).toStringAsFixed(1) : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Yoğunluk Analizi',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Son $periodDays günlük temizlik aktivitesi',
                style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'Toplam Kayıt',
                    '$total',
                    AppColors.primary,
                    Icons.list_alt,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _statBox(
                    'Günlük Ortalama',
                    avgPerDay,
                    AppColors.success,
                    Icons.calendar_today,
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.heading2.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    final grid =
        (_data!['grid'] as List).map((row) => row as List).toList();
    final dayLabels =
        (_data!['day_labels'] as List).cast<String>();
    final slotLabels =
        (_data!['slot_labels'] as List).cast<String>();
    final maxValue = (_data!['max_value'] as num? ?? 1).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_4x4, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Gün × Saat Dilimi',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saat dilimi başlıkları
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      ...slotLabels.map((label) => SizedBox(
                            width: 56,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                label,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 9),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )),
                    ],
                  ),
                  // Gün satırları
                  ...List.generate(grid.length, (dayIdx) {
                    final row = grid[dayIdx];
                    return Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            dayLabels[dayIdx],
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...row.map((cell) {
                          final value = (cell as num).toInt();
                          final intensity =
                              maxValue > 0 ? value / maxValue : 0.0;
                          final color = _intensityColor(intensity);
                          return Container(
                            width: 52,
                            height: 36,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              value > 0 ? '$value' : '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: intensity > 0.5
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _intensityColor(double intensity) {
    if (intensity == 0) return Colors.grey.shade100;
    if (intensity < 0.25) return AppColors.primary.withValues(alpha: 0.2);
    if (intensity < 0.5) return AppColors.primary.withValues(alpha: 0.4);
    if (intensity < 0.75) return AppColors.primary.withValues(alpha: 0.7);
    return AppColors.primary;
  }

  Widget _buildLegendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Renk Açıklaması', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _legendBox(Colors.grey.shade100, 'Yok'),
                _legendBox(
                    AppColors.primary.withValues(alpha: 0.2), 'Az'),
                _legendBox(
                    AppColors.primary.withValues(alpha: 0.4), 'Orta'),
                _legendBox(
                    AppColors.primary.withValues(alpha: 0.7), 'Çok'),
                _legendBox(AppColors.primary, 'En Yoğun'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendBox(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 9)),
      ],
    );
  }

  Widget _buildInsightsCard() {
    final peak = _data!['peak'] as Map<String, dynamic>?;
    final dayLabels =
        (_data!['day_labels'] as List).cast<String>();
    final slotLabels =
        (_data!['slot_labels'] as List).cast<String>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Text('İçgörüler', style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (peak != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: const Border(
                    left: BorderSide(
                        color: AppColors.warning, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'En yoğun zaman dilimi',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dayLabels[(peak['day'] as num).toInt()]} '
                      '${slotLabels[(peak['slot'] as num).toInt()]} '
                      '— ${peak['value']} kayıt',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ] else
              Text('Henüz yeterli veri yok',
                  style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color:
                    AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Bu görsel, GitHub stili commit grafiğinin temizlik '
                'kayıtlarına uyarlanmış halidir. Renk yoğunluğu, ilgili '
                'zaman dilimindeki kayıt sayısını yansıtır.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
