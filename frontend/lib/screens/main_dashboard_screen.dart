import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  bool _isLoading = true;
  String _userName = '';
  String _userRole = '';
  Map<String, dynamic>? _kpiData;
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _last7Days = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    _userName = prefs.getString('userName') ?? 'Kullanıcı';
    _userRole = prefs.getString('userRole') ?? 'staff';
    final userId = prefs.getInt('userId') ?? 0;

    await Future.wait([
      _fetchKpi(token),
      if (_userRole == 'admin') _fetchInventory(token),
      _fetchLast7Days(token, userId),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchKpi(String? token) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/kpi/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        _kpiData = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
  }

  Future<void> _fetchInventory(String? token) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        _inventoryItems = (jsonDecode(response.body) as List)
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  Future<void> _fetchLast7Days(String? token, int userId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://192.168.1.27:4000/api/kpi/trend/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data is List) {
          _last7Days = data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['trend'] is List) {
          _last7Days =
              (data['trend'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs',
      'Haziran', 'Temmuz', 'Ağustos', 'Eylül',
      'Ekim', 'Kasım', 'Aralık',
    ];
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}, '
        '${days[now.weekday - 1]}';
  }

  Future<void> _generateMasterReport() async {
    if (_kpiData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('KPI verisi yok — önce sayfayı yenileyin')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yıllık rapor oluşturuluyor...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      final results = await Future.wait([
        http.get(
            Uri.parse('http://192.168.1.27:4000/api/budget/summary'),
            headers: headers),
        http.get(
            Uri.parse('http://192.168.1.27:4000/api/budget/trend'),
            headers: headers),
      ]);

      if (!mounted) return;

      final budgetSummary = results[0].statusCode == 200
          ? jsonDecode(results[0].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final trendData = results[1].statusCode == 200
          ? jsonDecode(results[1].body) as Map<String, dynamic>
          : <String, dynamic>{};

      final bytes = await PdfReportService.generateMasterReport(
        kpiData: _kpiData!,
        inventoryItems: _inventoryItems,
        budgetSummary: budgetSummary,
        trendData: trendData,
      );

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'yillik_yonetim_raporu.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    await prefs.remove('userId');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadAllData,
          ),
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Yıllık Toplu Rapor',
              onPressed: _generateMasterReport,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _buildWelcome(),
                  const SizedBox(height: AppSpacing.md),
                  _buildKpiCard(),
                  if (_userRole == 'admin') ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildInventoryCard(),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _build7DaysChart(),
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickActions(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }

  // ── Welcome ───────────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
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
                      Text('Hoş geldin,',
                          style: AppTextStyles.caption),
                      Text(
                        _userName,
                        style: AppTextStyles.heading2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatDate(), style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── KPI Card ──────────────────────────────────────────────────────────────

  Widget _buildKpiCard() {
    if (_kpiData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Performans Özetim',
                      style: AppTextStyles.heading2),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text('KPI verisi yüklenemedi',
                    style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      );
    }

    final score =
        (_kpiData!['overall_score'] as num? ?? 0).toDouble();
    final grade = _kpiData!['grade']?.toString() ?? 'N/A';
    final levelMap =
        _kpiData!['level'] as Map<String, dynamic>?;
    final levelName = levelMap?['name']?.toString() ?? '';

    final Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.success;
    } else if (score >= 60) {
      scoreColor = AppColors.primary;
    } else if (score >= 40) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Performans Özetim',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text('/100',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harf Notu: $grade',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: scoreColor,
                        ),
                      ),
                      if (levelName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(levelName,
                            style: AppTextStyles.caption),
                      ],
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 8,
                          backgroundColor:
                              scoreColor.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  scoreColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Detayı Gör'),
                onPressed: () =>
                    Navigator.pushNamed(context, '/kpi-detail'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Inventory Card ────────────────────────────────────────────────────────

  Widget _buildInventoryCard() {
    final normalCount = _inventoryItems
        .where((i) => i['alert_level'] == 'normal')
        .length;
    final reorderCount = _inventoryItems
        .where((i) => i['alert_level'] == 'reorder')
        .length;
    final criticalCount = _inventoryItems
        .where((i) =>
            i['alert_level'] == 'critical' ||
            i['alert_level'] == 'depleted')
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Stok Durumu',
                      style: AppTextStyles.heading2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _inventoryItems.isEmpty
                ? Center(
                    child: Text('Stok verisi yüklenemedi',
                        style: AppTextStyles.caption),
                  )
                : Row(
                    children: [
                      _invStatBox('Normal', normalCount,
                          AppColors.success, Icons.check_circle),
                      const SizedBox(width: AppSpacing.sm),
                      _invStatBox('Sipariş', reorderCount,
                          AppColors.warning,
                          Icons.shopping_cart_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      _invStatBox('Kritik', criticalCount,
                          AppColors.error, Icons.warning),
                    ],
                  ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Stok Yönetimi'),
                onPressed: () =>
                    Navigator.pushNamed(context, '/inventory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invStatBox(
      String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  // ── 7-Day Bar Chart ───────────────────────────────────────────────────────

  Widget _build7DaysChart() {
    const dayLabels = [
      'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
    ];

    if (_last7Days.isEmpty) {
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
                  Text('Son 7 Gün Aktivite',
                      style: AppTextStyles.heading2),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Henüz aktivite verisi yok',
                      style: AppTextStyles.caption),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final counts = _last7Days
        .map((d) => (d['count'] as num? ?? 0).toDouble())
        .toList();
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final total =
        counts.fold<double>(0, (sum, c) => sum + c).toInt();

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
                  child: Text('Son 7 Gün Aktivite',
                      style: AppTextStyles.heading2),
                ),
                Text('Toplam: $total kayıt',
                    style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? maxCount * 1.2 : 5,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 &&
                              i < _last7Days.length) {
                            final dayStr = _last7Days[i]
                                    ['day']
                                ?.toString();
                            if (dayStr != null) {
                              try {
                                final dt =
                                    DateTime.parse(dayStr);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                          top: 4),
                                  child: Text(
                                    dayLabels[
                                        dt.weekday - 1],
                                    style: const TextStyle(
                                        fontSize: 10),
                                  ),
                                );
                              } catch (_) {}
                            }
                            if (i < dayLabels.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(
                                        top: 4),
                                child: Text(
                                  dayLabels[i],
                                  style: const TextStyle(
                                      fontSize: 10),
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(counts.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i],
                          color: AppColors.primary,
                          width: 18,
                          borderRadius: const BorderRadius.only(
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

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on,
                    color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Text('Hızlı Erişim',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _quickButton(
                  icon: Icons.qr_code_scanner,
                  label: 'QR Kayıt',
                  color: AppColors.primary,
                  onTap: () => Navigator.pushNamed(
                      context, '/qr-cleaning'),
                ),
                _quickButton(
                  icon: Icons.analytics,
                  label: 'KPI Detay',
                  color: AppColors.success,
                  onTap: () => Navigator.pushNamed(
                      context, '/kpi-detail'),
                ),
                if (_userRole == 'admin')
                  _quickButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stok',
                    color: AppColors.warning,
                    onTap: () => Navigator.pushNamed(
                        context, '/inventory'),
                  ),
                _quickButton(
                  icon: Icons.grid_4x4,
                  label: 'Yoğunluk',
                  color: AppColors.error,
                  onTap: () =>
                      Navigator.pushNamed(context, '/heatmap'),
                ),
                _quickButton(
                  icon: Icons.compare_arrows,
                  label: 'Karşılaştır',
                  color: AppColors.success,
                  onTap: () => Navigator.pushNamed(
                      context, '/comparison'),
                ),
                if (_userRole == 'admin')
                  _quickButton(
                    icon: Icons.account_balance_wallet,
                    label: 'Bütçe',
                    color: AppColors.adminAccent,
                    onTap: () => Navigator.pushNamed(
                        context, '/budget'),
                  ),
                _quickButton(
                  icon: Icons.apps,
                  label: 'Tüm Menü',
                  color: AppColors.adminAccent,
                  onTap: () =>
                      Navigator.pushNamed(context, '/home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
