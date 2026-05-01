import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../utils/translations.dart';

class MyScheduledTasksScreen extends StatefulWidget {
  const MyScheduledTasksScreen({super.key});

  @override
  State<MyScheduledTasksScreen> createState() => _MyScheduledTasksScreenState();
}

class _MyScheduledTasksScreenState extends State<MyScheduledTasksScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() { isLoading = false; errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.'; });
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/tasks/my-scheduled'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { tasks = jsonDecode(response.body) as List<dynamic>; isLoading = false; });
      } else {
        String message = 'Görevler alınamadı (Kod: ${response.statusCode})';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planlı Görevlerim')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : tasks.isEmpty
                  ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Görev Yok',
                      message: 'Size atanmış bekleyen planlı görev bulunmuyor.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTasks,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index] as Map<String, dynamic>;
                          final status = StatusTranslator.cleaningStatus(task['status']?.toString());

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.staffAccent.withValues(alpha: 0.12),
                                child: const Icon(Icons.assignment, color: AppColors.staffAccent, size: 20),
                              ),
                              title: Text(
                                task['title']?.toString() ?? '-',
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Oda: ${task['room_name'] ?? task['room_id'] ?? '-'}\n'
                                'Planlanan: ${task['scheduled_for'] ?? '-'}\n'
                                'Durum: $status',
                                style: AppTextStyles.caption,
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
