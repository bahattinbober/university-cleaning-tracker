import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() {
          _errorMessage = 'Oturum bulunamadı';
          _isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/admin/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
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
      setState(() {
        _errorMessage = 'Bağlantı hatası: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _fetchDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _fetchDashboard)
              : RefreshIndicator(
                  onRefresh: _fetchDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _KpiGrid(data: _data!),
                      const SizedBox(height: AppSpacing.md),
                      _RoomPieCard(data: _data!),
                      const SizedBox(height: AppSpacing.md),
                      _WeeklyBarCard(data: _data!),
                      const SizedBox(height: AppSpacing.md),
                      _TopPersonnelCard(data: _data!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
    );
  }
}

// ─── KPI Grid ──────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiItem(
        label: 'Bugün Kayıt',
        value: '${data['today_count'] ?? 0}',
        icon: Icons.today,
        color: AppColors.primary,
      ),
      _KpiItem(
        label: 'Bekleyen Görev',
        value: '${data['pending_tasks'] ?? 0}',
        icon: Icons.pending_actions,
        color: AppColors.warning,
      ),
      _KpiItem(
        label: 'Aktif Personel',
        value: '${data['active_personnel'] ?? 0}',
        icon: Icons.people,
        color: AppColors.success,
      ),
      _KpiItem(
        label: 'Bu Hafta',
        value: '${data['weekly_total'] ?? 0}',
        icon: Icons.bar_chart,
        color: AppColors.adminAccent,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

class _KpiItem extends StatelessWidget {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.heading1.copyWith(color: color),
                ),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pie Chart ─────────────────────────────────────────────────────────────

class _RoomPieCard extends StatefulWidget {
  const _RoomPieCard({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_RoomPieCard> createState() => _RoomPieCardState();
}

class _RoomPieCardState extends State<_RoomPieCard> {
  int _touchedIndex = -1;

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    final rooms = (widget.data['room_distribution'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Oda Dağılımı (Son 7 Gün)',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: AppSpacing.md),
            if (rooms.isEmpty)
              const _EmptyData()
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 160,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: rooms.asMap().entries.map((e) {
                            final i = e.key;
                            final count = (e.value['count'] as int?) ?? 0;
                            final total = rooms.fold<int>(
                                0, (s, r) => s + ((r['count'] as int?) ?? 0));
                            final pct =
                                total > 0 ? (count / total * 100) : 0.0;
                            final isTouched = i == _touchedIndex;
                            return PieChartSectionData(
                              color: _colors[i % _colors.length],
                              value: count.toDouble(),
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: isTouched ? 60 : 50,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rooms.asMap().entries.map((e) {
                      final i = e.key;
                      final roomName =
                          e.value['room_name']?.toString() ?? '-';
                      final count = e.value['count'] ?? 0;
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[i % _colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '$roomName ($count)',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Bar Chart ─────────────────────────────────────────────────────────────

class _WeeklyBarCard extends StatelessWidget {
  const _WeeklyBarCard({required this.data});
  final Map<String, dynamic> data;

  static const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  String _dayLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return _dayNames[dt.weekday - 1];
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trend = (data['weekly_trend'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haftalık Aktivite', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.md),
            if (trend.isEmpty)
              const _EmptyData()
            else
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: trend
                            .map((e) =>
                                ((e['count'] as int?) ?? 0).toDouble())
                            .fold(0.0, (a, b) => a > b ? a : b) +
                        1,
                    barGroups: trend.asMap().entries.map((e) {
                      final count = (e.value['count'] as int?) ?? 0;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: count.toDouble(),
                            color: AppColors.primary,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= trend.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _dayLabel(
                                    trend[i]['day']?.toString() ?? ''),
                                style: AppTextStyles.caption,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            if (value % 1 != 0) return const SizedBox.shrink();
                            return Text(
                              value.toInt().toString(),
                              style: AppTextStyles.caption,
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Personnel ─────────────────────────────────────────────────────────

class _TopPersonnelCard extends StatelessWidget {
  const _TopPersonnelCard({required this.data});
  final Map<String, dynamic> data;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final personnel = (data['top_personnel'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('En Aktif Personel', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            if (personnel.isEmpty)
              const _EmptyData()
            else
              ...personnel.asMap().entries.map((e) {
                final i = e.key;
                final name = e.value['name']?.toString() ?? '-';
                final score = e.value['score'] ?? 0;
                final medal = i < _medals.length ? _medals[i] : '•';

                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Text(medal,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$score puan',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
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

// ─── Helpers ───────────────────────────────────────────────────────────────

class _EmptyData extends StatelessWidget {
  const _EmptyData();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text('Henüz veri yok', style: AppTextStyles.caption),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
