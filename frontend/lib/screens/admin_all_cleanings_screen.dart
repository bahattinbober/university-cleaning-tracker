import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../utils/translations.dart';

class AdminAllCleaningsScreen extends StatefulWidget {
  const AdminAllCleaningsScreen({super.key});

  @override
  State<AdminAllCleaningsScreen> createState() => _AdminAllCleaningsScreenState();
}

class _AdminAllCleaningsScreenState extends State<AdminAllCleaningsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
  }

  Future<void> _fetchAllLogs() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() { errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.'; isLoading = false; });
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/cleaning'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { logs = jsonDecode(response.body) as List; isLoading = false; });
      } else {
        setState(() { errorMessage = 'Kayıtlar alınamadı (kod: ${response.statusCode}).'; isLoading = false; });
      }
    } catch (e) {
      setState(() { errorMessage = 'Bir hata oluştu: $e'; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tüm Temizlik Kayıtları')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Kayıt Bulunamadı',
                      message: 'Sistemde henüz temizlik kaydı bulunmuyor.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAllLogs,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final roomName = log['room_name'] ?? 'Oda';
                          final cleanerName = log['user_name'] ?? 'Personel';
                          final status = StatusTranslator.cleaningStatus(log['status']?.toString());
                          final notes = log['notes'] ?? '';
                          final cleanedAt = log['cleaned_at'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.adminAccent.withValues(alpha: 0.12),
                                child: const Icon(Icons.cleaning_services, color: AppColors.adminAccent, size: 20),
                              ),
                              title: Text(
                                '$roomName — $status',
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$cleanedAt · $cleanerName${notes.isNotEmpty ? '\n$notes' : ''}',
                                style: AppTextStyles.caption,
                              ),
                              isThreeLine: notes.isNotEmpty,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
