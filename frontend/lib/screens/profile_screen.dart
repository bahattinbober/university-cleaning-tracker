import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';
import '../widgets/info_chip.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        String message = 'Profil yüklenemedi.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Bağlantı hatası: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value != null && value.isNotEmpty ? value : '—',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _fetchProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _fetchProfile,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _userData!;
    final name = (user['name'] as String?) ?? '';
    final email = (user['email'] as String?) ?? '';
    final role = (user['role'] as String?) ?? '';
    final employeeNo = (user['employee_no'] as String?) ?? '';
    final department = (user['department'] as String?) ?? '';
    final approvalStatus = (user['approval_status'] as String?) ?? '';
    final roleColor = role == 'admin' ? AppColors.adminAccent : AppColors.primary;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Üst profil kartı
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(name, style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.xs),
              Text(email, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.sm),
              InfoChip(
                label: StatusTranslator.userRole(role),
                color: roleColor,
              ),
            ],
          ),
        ),

        // Kişisel bilgiler kartı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KİŞİSEL BİLGİLER',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                _infoRow(Icons.email_outlined, 'E-posta', email),
                _infoRow(Icons.badge, 'Sicil No', employeeNo),
                _infoRow(Icons.business, 'Departman', department),
                _infoRow(
                  Icons.verified_user,
                  'Hesap Durumu',
                  StatusTranslator.approvalStatus(approvalStatus),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Aksiyon butonları
        OutlinedButton.icon(
          icon: const Icon(Icons.lock_outline),
          label: const Text('Şifre Değiştir'),
          onPressed: () => Navigator.pushNamed(context, '/change-password'),
        ),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Çıkış Yap'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: _logout,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
