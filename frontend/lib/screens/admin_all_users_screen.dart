import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_chip.dart';
import '../utils/translations.dart';

class AdminAllUsersScreen extends StatefulWidget {
  const AdminAllUsersScreen({super.key});

  @override
  State<AdminAllUsersScreen> createState() => _AdminAllUsersScreenState();
}

class _AdminAllUsersScreenState extends State<AdminAllUsersScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> users = [];
  int _currentUserId = -1;
  int? _deletingId;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchUsers();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('userId') ?? -1;
        _token = prefs.getString('token');
      });
    }
  }

  Future<int?> _fetchCurrentTarget(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/kpi/target/$userId'),
        headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['target_value'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showSetTargetDialog(int userId, String name) async {
    final currentTarget = await _fetchCurrentTarget(userId);
    if (!mounted) return;

    final controller = TextEditingController(
      text: currentTarget != null ? '$currentTarget' : '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hedef Ata: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Mevcut hedef: $currentTarget kayıt/hafta',
                  style: AppTextStyles.caption,
                ),
              ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Haftalık hedef (kayıt sayısı)',
                hintText: 'Örn: 20',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > 1000) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('1-1000 arası geçerli bir sayı girin')),
                );
                return;
              }
              try {
                final response = await http.post(
                  Uri.parse('http://192.168.1.27:4000/api/kpi/target'),
                  headers: {
                    if (_token != null) 'Authorization': 'Bearer $_token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(
                      {'user_id': userId, 'target_value': value}),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (response.statusCode == 200 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '$name için haftalık hedef: $value kayıt'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hedef atanamadı'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUsers() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/users'),
        headers: { if (token != null) 'Authorization': 'Bearer $token' },
      );

      if (response.statusCode == 200) {
        setState(() { users = jsonDecode(response.body) as List; isLoading = false; });
      } else {
        setState(() {
          errorMessage = 'Kullanıcı listesi alınamadı (kod: ${response.statusCode}).';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { errorMessage = 'Bir hata oluştu: $e'; isLoading = false; });
    }
  }

  Future<void> _deleteUser(int userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content: Text(
          '$name kullanıcısını silmek istediğinize emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingId = userId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('http://192.168.1.27:4000/api/admin/users/$userId'),
        headers: { if (token != null) 'Authorization': 'Bearer $token' },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı silindi'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchUsers();
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message']?.toString() ?? 'Silme işlemi başarısız',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tüm Kullanıcılar')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : users.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'Kullanıcı Bulunamadı',
                      message: 'Sistemde kayıtlı kullanıcı bulunmuyor.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final userId = user['id'] as int? ?? -1;
                          final name = user['name']?.toString() ?? 'İsimsiz';
                          final email = user['email']?.toString() ?? '';
                          final role = user['role']?.toString();
                          final initial =
                              name.isNotEmpty ? name[0].toUpperCase() : '?';
                          final isAdmin = role == 'admin';
                          final isSelf = userId == _currentUserId;
                          final isDeleting = _deletingId == userId;

                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isAdmin
                                        ? AppColors.adminAccent
                                            .withValues(alpha: 0.15)
                                        : AppColors.staffAccent
                                            .withValues(alpha: 0.15),
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isAdmin
                                            ? AppColors.adminAccent
                                            : AppColors.staffAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          email,
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  InfoChip(
                                    label: StatusTranslator.userRole(role),
                                    color: isAdmin
                                        ? AppColors.adminAccent
                                        : AppColors.staffAccent,
                                  ),
                                  if (!isSelf) ...[
                                    const SizedBox(width: 4),
                                    if (isDeleting)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: AppColors.textSecondary,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _deleteUser(userId, name);
                                          } else if (value == 'set_target') {
                                            _showSetTargetDialog(
                                                userId, name);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem<String>(
                                            value: 'set_target',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.flag_outlined,
                                                  color: AppColors.primary,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Hedef Ata'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  color: AppColors.error,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Sil',
                                                  style: TextStyle(
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
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
