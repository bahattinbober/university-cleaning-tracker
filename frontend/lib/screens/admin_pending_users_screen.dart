import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_chip.dart';
import '../utils/translations.dart';

class AdminPendingUsersScreen extends StatefulWidget {
  const AdminPendingUsersScreen({super.key});

  @override
  State<AdminPendingUsersScreen> createState() => _AdminPendingUsersScreenState();
}

class _AdminPendingUsersScreenState extends State<AdminPendingUsersScreen> {
  bool isLoading = true;
  bool isUpdating = false;
  String? errorMessage;
  List<dynamic> pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchPendingUsers() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() { isLoading = false; errorMessage = 'Oturum bulunamadı'; });
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/admin/pending-users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { pendingUsers = jsonDecode(response.body) as List<dynamic>; isLoading = false; });
      } else {
        String message = 'Liste alınamadı (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) message = body['message'] as String;
        } catch (_) {}
        setState(() { isLoading = false; errorMessage = message; });
      }
    } catch (e) {
      setState(() { isLoading = false; errorMessage = 'Bir hata oluştu: $e'; });
    }
  }

  Future<void> _updateUserStatus({ required int userId, required bool approve }) async {
    if (isUpdating) return;
    setState(() => isUpdating = true);
    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oturum bulunamadı')));
        return;
      }

      final endpoint = approve ? 'approve-user' : 'reject-user';
      final response = await http.put(
        Uri.parse('http://192.168.1.27:4000/api/admin/$endpoint/$userId'),
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer $token' },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Kullanıcı onaylandı' : 'Kullanıcı reddedildi')),
        );
        await _fetchPendingUsers();
      } else {
        String message = 'İşlem başarısız (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) message = body['message'] as String;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onay Bekleyen Kullanıcılar')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : pendingUsers.isEmpty
                  ? const EmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Bekleyen Başvuru Yok',
                      message: 'Onay bekleyen yeni kullanıcı kaydı bulunmuyor.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPendingUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: pendingUsers.length,
                        itemBuilder: (context, index) {
                          final user = pendingUsers[index] as Map<String, dynamic>;
                          final id = user['id'];
                          final name = user['name']?.toString() ?? '-';
                          final email = user['email']?.toString() ?? '-';
                          final employeeNo = user['employee_no']?.toString() ?? '-';
                          final department = user['department']?.toString() ?? '-';
                          final role = user['role']?.toString();
                          final userId = int.tryParse(id.toString());
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Üst satır: avatar + isim/email + rol chip
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.staffAccent.withValues(alpha: 0.15),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.staffAccent,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(email, style: AppTextStyles.caption),
                                          ],
                                        ),
                                      ),
                                      InfoChip(
                                        label: StatusTranslator.userRole(role),
                                        color: AppColors.staffAccent,
                                        icon: Icons.badge,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: AppSpacing.sm),
                                  const Divider(),
                                  const SizedBox(height: AppSpacing.xs),

                                  // Detay satırları
                                  Row(
                                    children: [
                                      const Icon(Icons.badge_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text('Sicil No: $employeeNo', style: AppTextStyles.caption),
                                      const SizedBox(width: AppSpacing.md),
                                      const Icon(Icons.business_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          'Departman: $department',
                                          style: AppTextStyles.caption,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: AppSpacing.md),

                                  // Onayla / Reddet butonları
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: isUpdating || userId == null
                                              ? null
                                              : () => _updateUserStatus(userId: userId, approve: true),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Onayla'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isUpdating || userId == null
                                              ? null
                                              : () => _updateUserStatus(userId: userId, approve: false),
                                          icon: const Icon(Icons.close, size: 18),
                                          label: const Text('Reddet'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
