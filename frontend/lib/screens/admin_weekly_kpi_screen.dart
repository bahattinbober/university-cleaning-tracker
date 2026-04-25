import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
        String message = 'KPI verisi alınamadı (Kod: ${response.statusCode})';
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

  IconData? _rankIcon(int index) {
    if (index == 0) return Icons.workspace_premium;
    if (index == 1) return Icons.star;
    if (index == 2) return Icons.star_border;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık KPI Karşılaştırması')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : kpiRows.isEmpty
          ? const Center(child: Text('Bu hafta için kayıt bulunamadı'))
          : RefreshIndicator(
              onRefresh: _fetchWeeklyKpi,
              child: ListView.builder(
                itemCount: kpiRows.length,
                itemBuilder: (context, index) {
                  final row = kpiRows[index] as Map<String, dynamic>;
                  final rankIcon = _rankIcon(index);

                  final rawUserId = row['user_id'];
                  final userId = rawUserId is int
                      ? rawUserId
                      : int.tryParse(rawUserId?.toString() ?? '');

                  return InkWell(
                    onTap: userId == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminUserLogsScreen(
                                  userId: userId,
                                  userName: row['name']?.toString(),
                                ),
                              ),
                            );
                          },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row['name']?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (rankIcon != null)
                                  Icon(
                                    rankIcon,
                                    size: 18,
                                    color: Colors.amber[700],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(row['email']?.toString() ?? '-'),
                            const Divider(height: 18),
                            Text('Toplam görev: ${row['total_tasks'] ?? 0}'),
                            Text(
                              'Tamamlanan görev: ${row['completed_tasks'] ?? 0}',
                            ),
                            Text('Not eklenen görev: ${row['noted_tasks'] ?? 0}'),
                            Text(
                              'Fotoğraflı görev: ${row['photo_tasks'] ?? row['photoTasks'] ?? 0}',
                            ),
                            Text('Zamanında görev: ${row['on_time_tasks'] ?? 0}'),
                            Text(
                              'Geç tamamlanan görev: ${row['late_tasks'] ?? 0}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Haftalık skor: ${row['score'] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
