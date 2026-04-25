import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyCleaningsScreen extends StatefulWidget {
  const MyCleaningsScreen({super.key});

  @override
  State<MyCleaningsScreen> createState() => _MyCleaningsScreenState();
}

class _MyCleaningsScreenState extends State<MyCleaningsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    _fetchMyLogs();
  }

  Future<void> _fetchMyLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.';
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse('http://10.0.2.2:4000/api/cleaning/my');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          logs = data as List;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Kayıtlar alınamadı (kod: ${response.statusCode}).';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Bir hata oluştu: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temizlik Kayıtlarım')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : logs.isEmpty
                  ? const Center(child: Text('Henüz temizlik kaydınız yok.'))
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final roomName = log['room_name'] ?? 'Oda';
                        final status = log['status'] ?? '-';
                        final notes = log['notes'] ?? '';
                        final cleanedAt = log['cleaned_at'] ?? '';

                        return ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text('$roomName - $status'),
                          subtitle: Text('$cleanedAt\n$notes'),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}
