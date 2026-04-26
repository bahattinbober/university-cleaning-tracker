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

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/users'),
        headers: { if (token != null) 'Authorization': 'Bearer $token' },
      );

      if (response.statusCode == 200) {
        setState(() { users = jsonDecode(response.body) as List; isLoading = false; });
      } else {
        setState(() { errorMessage = 'Kullanıcı listesi alınamadı (kod: ${response.statusCode}).'; isLoading = false; });
      }
    } catch (e) {
      setState(() { errorMessage = 'Bir hata oluştu: $e'; isLoading = false; });
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final name = user['name'] ?? 'İsimsiz';
                          final email = user['email'] ?? '';
                          final role = user['role']?.toString();
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          final isAdmin = role == 'admin';

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAdmin
                                    ? AppColors.adminAccent.withValues(alpha: 0.15)
                                    : AppColors.staffAccent.withValues(alpha: 0.15),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? AppColors.adminAccent : AppColors.staffAccent,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(email, style: AppTextStyles.caption),
                              trailing: InfoChip(
                                label: StatusTranslator.userRole(role),
                                color: isAdmin ? AppColors.adminAccent : AppColors.staffAccent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
