import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';
import '../widgets/info_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List<String?>> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    return [prefs.getString('userName'), prefs.getString('userRole')];
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
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
                if (isAdmin) ..._adminSections(context) else ..._staffSections(context),
                _sectionHeader('HESAP'),
                MenuCard(
                  title: 'Şifre Değiştir',
                  icon: Icons.lock_outline,
                  color: AppColors.primary,
                  onTap: () => Navigator.pushNamed(context, '/change-password'),
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
          onTap: () => Navigator.pushNamed(context, '/admin-pending-users'),
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
          onTap: () => Navigator.pushNamed(context, '/admin-all-cleanings'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Haftalık KPI',
          icon: Icons.bar_chart,
          color: AppColors.adminAccent,
          subtitle: 'Personel performansı',
          onTap: () => Navigator.pushNamed(context, '/admin-weekly-kpi'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MenuCard(
          title: 'Planlı Görev Oluştur',
          icon: Icons.add_task,
          color: AppColors.adminAccent,
          onTap: () => Navigator.pushNamed(context, '/admin-scheduled-task'),
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
          onTap: () => Navigator.pushNamed(context, '/my-scheduled-tasks'),
        ),
      ];

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );
}

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
          icon: isAdmin ? Icons.admin_panel_settings : Icons.badge,
        ),
      ],
    );
  }
}
