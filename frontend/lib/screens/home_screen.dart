import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';
import '../widgets/info_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pendingTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<List<String?>> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    return [prefs.getString('userName'), prefs.getString('userRole')];
  }

  Future<void> _logout(BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    await prefs.remove('userId');
    if (ctx.mounted) {
      Navigator.pushReplacementNamed(ctx, '/login');
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/tasks/my-scheduled'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final tasks = jsonDecode(response.body) as List;
        setState(() => _pendingTaskCount = tasks.length);
      }
    } catch (_) {}
  }

  Future<void> _showNotifications() async {
    List<dynamic> tasks = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        final response = await http.get(
          Uri.parse('http://192.168.1.27:4000/api/tasks/my-scheduled'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          tasks = jsonDecode(response.body) as List;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _NotificationSheet(
        tasks: tasks,
        pendingCount: _pendingTaskCount,
        onViewAll: () {
          Navigator.pop(sheetCtx);
          Navigator.pushNamed(context, '/my-scheduled-tasks');
        },
      ),
    );

    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Bildirimler',
                onPressed: _showNotifications,
              ),
              if (_pendingTaskCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _pendingTaskCount > 99 ? '99+' : '$_pendingTaskCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Şifre Değiştir',
            onPressed: () => Navigator.pushNamed(context, '/change-password'),
          ),
        ],
      ),
      body: FutureBuilder<List<String?>>(
        future: _loadUser(),
        builder: (context, snapshot) {
          final name = snapshot.data?[0] ?? '';
          final role = snapshot.data?[1] ?? '';
          final isAdmin = role == 'admin';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeHeader(name: name, isAdmin: isAdmin),
                const SizedBox(height: AppSpacing.lg),
                if (isAdmin)
                  ..._adminSections(context)
                else
                  ..._staffSections(context),
                _sectionHeader('HESAP'),
                MenuCard(
                  title: 'Kişisel Bilgilerim',
                  subtitle: 'Hesap detaylarını görüntüle',
                  icon: Icons.account_circle_outlined,
                  color: AppColors.primary,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuCard(
                  title: 'Şifre Değiştir',
                  icon: Icons.lock_outline,
                  color: AppColors.primary,
                  onTap: () =>
                      Navigator.pushNamed(context, '/change-password'),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuCard(
                  title: 'Çıkış Yap',
                  icon: Icons.logout,
                  color: AppColors.error,
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _adminSections(BuildContext context) => [
        _sectionHeader('YÖNETİM'),
        MenuCard(
          title: 'Onay Bekleyen Kullanıcılar',
          icon: Icons.pending_actions,
          color: AppColors.adminAccent,
          subtitle: 'Yeni kayıtları onayla',
          onTap: () =>
              Navigator.pushNamed(context, '/admin-pending-users'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Tüm Kullanıcılar',
          icon: Icons.people,
          color: AppColors.adminAccent,
          onTap: () => Navigator.pushNamed(context, '/admin-users'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Tüm Temizlik Kayıtları',
          icon: Icons.cleaning_services,
          color: AppColors.adminAccent,
          onTap: () =>
              Navigator.pushNamed(context, '/admin-all-cleanings'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Haftalık KPI',
          icon: Icons.bar_chart,
          color: AppColors.adminAccent,
          subtitle: 'Personel performansı',
          onTap: () =>
              Navigator.pushNamed(context, '/admin-weekly-kpi'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Planlı Görev Oluştur',
          icon: Icons.add_task,
          color: AppColors.adminAccent,
          onTap: () =>
              Navigator.pushNamed(context, '/admin-scheduled-task'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionHeader('PERSONEL İŞLEMLERİ'),
        ..._staffCards(context),
        const SizedBox(height: AppSpacing.lg),
      ];

  List<Widget> _staffSections(BuildContext context) => [
        _sectionHeader('İŞLEMLER'),
        ..._staffCards(context),
        const SizedBox(height: AppSpacing.lg),
      ];

  List<Widget> _staffCards(BuildContext context) => [
        MenuCard(
          title: 'Oda Listesi',
          icon: Icons.meeting_room,
          color: AppColors.staffAccent,
          onTap: () => Navigator.pushNamed(context, '/rooms'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'QR ile Temizlik Kaydı',
          icon: Icons.qr_code_scanner,
          color: AppColors.staffAccent,
          onTap: () => Navigator.pushNamed(context, '/qr-cleaning'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Temizlik Kayıtlarım',
          icon: Icons.history,
          color: AppColors.staffAccent,
          onTap: () => Navigator.pushNamed(context, '/my-cleanings'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Planlı Görevlerim',
          icon: Icons.assignment,
          color: AppColors.staffAccent,
          onTap: () =>
              Navigator.pushNamed(context, '/my-scheduled-tasks'),
        ),
      ];

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(
            top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );
}

// ─── Notification Bottom Sheet ─────────────────────────────────────────────

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.tasks,
    required this.pendingCount,
    required this.onViewAll,
  });

  final List<dynamic> tasks;
  final int pendingCount;
  final VoidCallback onViewAll;

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw.trim().replaceAll(' ', 'T'));
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d.$m.${dt.year} $h:$min';
    } catch (_) {
      return raw.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.notifications,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Bildirimler', style: AppTextStyles.heading2),
                const Spacer(),
                if (pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendingCount bekleyen',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg),
              child: Column(
                children: [
                  const Icon(Icons.notifications_none_outlined,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text('Yeni Bildirim Yok',
                      style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text('Bekleyen göreviniz bulunmuyor.',
                      style: AppTextStyles.caption),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                shrinkWrap: true,
                itemCount: tasks.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final task =
                      tasks[i] as Map<String, dynamic>;
                  final title =
                      task['title']?.toString() ?? 'Görev';
                  final roomName =
                      task['room_name']?.toString() ?? '';
                  final scheduledFor = _formatDate(
                      task['scheduled_for']?.toString());
                  final description =
                      task['description']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment,
                                color: AppColors.primary,
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextStyles.body
                                    .copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (roomName.isNotEmpty) ...[
                              const Icon(
                                  Icons.meeting_room,
                                  size: 14,
                                  color: AppColors
                                      .textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(roomName,
                                    style:
                                        AppTextStyles.caption),
                              ),
                              const SizedBox(width: 12),
                            ],
                            const Icon(Icons.schedule,
                                size: 14,
                                color:
                                    AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(scheduledFor,
                                  style:
                                      AppTextStyles.caption),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: AppTextStyles.caption
                                .copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md),
            child: FilledButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.list_alt),
              label: const Text('Tüm Planlı Görevler'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ─── Welcome Header ────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String name;
  final bool isAdmin;

  const _WelcomeHeader({required this.name, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hoş geldin,', style: AppTextStyles.caption),
              Text(
                name.isNotEmpty ? name : '—',
                style: AppTextStyles.heading2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        InfoChip(
          label: isAdmin ? 'Yönetici' : 'Personel',
          color: isAdmin ? AppColors.adminAccent : AppColors.staffAccent,
          icon: isAdmin
              ? Icons.admin_panel_settings
              : Icons.badge,
        ),
      ],
    );
  }
}
