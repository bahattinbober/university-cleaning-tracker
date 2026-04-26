import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'admin_user_logs_screen.dart';

class AdminWeeklyKpiScreen extends StatefulWidget {
  const AdminWeeklyKpiScreen({super.key});

  @override
  State<AdminWeeklyKpiScreen> createState() => _AdminWeeklyKpiScreenState();
}

class _AdminWeeklyKpiScreenState extends State<AdminWeeklyKpiScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> kpiRows = [];
  // Backend henüz hafta filtrelemesi desteklemiyor.
  int _selectedWeek = 0;

  @override
  void initState() {
    super.initState();
    _fetchWeeklyKpi();
  }

  Future<void> _fetchWeeklyKpi() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/admin/weekly-kpi'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          kpiRows = jsonDecode(response.body) as List<dynamic>;
          isLoading = false;
        });
      } else {
        String message =
            'KPI verisi alınamadı (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        setState(() {
          isLoading = false;
          errorMessage = message;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Bir hata oluştu: $e';
      });
    }
  }

  bool get _hasData {
    if (kpiRows.isEmpty) return false;
    return kpiRows.any((row) {
      final r = row as Map<String, dynamic>;
      return ((r['score'] as num?) ?? 0) > 0;
    });
  }

  Color _rankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700);
    if (index == 1) return const Color(0xFFC0C0C0);
    if (index == 2) return const Color(0xFFCD7F32);
    return AppColors.primary;
  }

  Widget _weekChips() {
    const labels = ['Bu Hafta', 'Geçen Hafta', '2 Hafta Önce'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = _selectedWeek == i;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(
                  labels[i],
                  style: TextStyle(
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFE5E7EB),
                ),
                onSelected: (_) => setState(() => _selectedWeek = i),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _summaryBar() {
    final totalStaff = kpiRows.length;
    final totalTasks = kpiRows.fold<int>(0, (sum, row) {
      final r = row as Map<String, dynamic>;
      return sum + ((r['total_tasks'] as num?) ?? 0).toInt();
    });
    final avgScore = kpiRows.isEmpty
        ? 0.0
        : kpiRows.fold<double>(0.0, (sum, row) {
              final r = row as Map<String, dynamic>;
              return sum + ((r['score'] as num?) ?? 0).toDouble();
            }) /
            kpiRows.length;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _summaryItem('$totalStaff', 'Toplam\nPersonel'),
            VerticalDivider(
              thickness: 1,
              color: AppColors.primary.withValues(alpha: 0.2),
              indent: 8,
              endIndent: 8,
            ),
            _summaryItem('$totalTasks', 'Toplam\nGörev'),
            VerticalDivider(
              thickness: 1,
              color: AppColors.primary.withValues(alpha: 0.2),
              indent: 8,
              endIndent: 8,
            ),
            _summaryItem(avgScore.toStringAsFixed(1), 'Ortalama\nPuan'),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(Map<String, dynamic> row, int index) {
    final name = row['name']?.toString() ?? '-';
    final email = row['email']?.toString() ?? '-';
    final score = ((row['score'] as num?) ?? 0).toInt();
    final totalTasks = ((row['total_tasks'] as num?) ?? 0).toInt();
    final completedTasks = ((row['completed_tasks'] as num?) ?? 0).toInt();
    final notedTasks = ((row['noted_tasks'] as num?) ?? 0).toInt();
    final photoTasks = ((row['photo_tasks'] as num?) ?? 0).toInt();
    final onTimeTasks = ((row['on_time_tasks'] as num?) ?? 0).toInt();
    final lateTasks = ((row['late_tasks'] as num?) ?? 0).toInt();
    final rankColor = _rankColor(index);

    final rawUserId = row['user_id'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: userId == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminUserLogsScreen(
                      userId: userId,
                      userName: name,
                    ),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: rankColor,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.heading2),
                        const SizedBox(height: AppSpacing.xs),
                        Text(email, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: index < 3
                          ? rankColor.withValues(alpha: 0.15)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: index < 3
                            ? rankColor
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: index < 3
                            ? rankColor
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Column(
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text('haftalık puan', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _metricGrid([
                _MetricItem(
                  Icons.assignment,
                  AppColors.primary,
                  'Toplam',
                  totalTasks,
                ),
                _MetricItem(
                  Icons.check_circle,
                  AppColors.success,
                  'Tamamlanan',
                  completedTasks,
                ),
                _MetricItem(
                  Icons.note_alt,
                  AppColors.primary,
                  'Notlu',
                  notedTasks,
                ),
                _MetricItem(
                  Icons.camera_alt,
                  AppColors.primary,
                  'Fotoğraflı',
                  photoTasks,
                ),
                _MetricItem(
                  Icons.schedule,
                  AppColors.success,
                  'Zamanında',
                  onTimeTasks,
                ),
                _MetricItem(
                  Icons.warning_amber,
                  AppColors.warning,
                  'Geç',
                  lateTasks,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricGrid(List<_MetricItem> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    // sliver yatay padding (md*2) + kart padding (md*2) + wrap spacing (sm) = 72
    final itemWidth =
        (screenWidth - AppSpacing.md * 4 - AppSpacing.sm) / 2;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        return SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(width: AppSpacing.sm),
                Text(item.label, style: AppTextStyles.caption),
                const Spacer(),
                Text(
                  '${item.value}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık KPI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeeklyKpi,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchWeeklyKpi,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _weekChips()),
                      if (_hasData)
                        SliverToBoxAdapter(child: _summaryBar()),
                      if (!_hasData)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.bar_chart_outlined,
                            title: 'KPI Verisi Yok',
                            message:
                                'Bu hafta için henüz temizlik kaydı bulunmuyor.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, index) => _kpiCard(
                                kpiRows[index] as Map<String, dynamic>,
                                index,
                              ),
                              childCount: kpiRows.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _MetricItem {
  final IconData icon;
  final Color color;
  final String label;
  final int value;

  const _MetricItem(this.icon, this.color, this.label, this.value);
}
