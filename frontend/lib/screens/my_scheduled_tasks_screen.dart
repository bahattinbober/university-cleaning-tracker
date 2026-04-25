import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
        Uri.parse('http://10.0.2.2:4000/api/tasks/my-scheduled'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          tasks = jsonDecode(response.body) as List<dynamic>;
          isLoading = false;
        });
      } else {
        String message = 'Görevler alınamadı (Kod: ${response.statusCode})';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planlı Görevlerim')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : tasks.isEmpty
          ? const Center(child: Text('Bekleyen planlı göreviniz yok'))
          : RefreshIndicator(
              onRefresh: _fetchTasks,
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index] as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${task['id'] ?? '-'}')),
                    title: Text(task['title']?.toString() ?? '-'),
                    subtitle: Text(
                      'Oda: ${task['room_name'] ?? task['room_id'] ?? '-'}\n'
                      'Planlanan: ${task['scheduled_for'] ?? '-'}\n'
                      'Durum: ${task['status'] ?? '-'}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
    );
  }
}
