import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminPendingUsersScreen extends StatefulWidget {
  const AdminPendingUsersScreen({super.key});

  @override
  State<AdminPendingUsersScreen> createState() =>
      _AdminPendingUsersScreenState();
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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Oturum bulunamadı';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/admin/pending-users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          pendingUsers = jsonDecode(response.body) as List<dynamic>;
          isLoading = false;
        });
      } else {
        String message = 'Liste alınamadı (Kod: ${response.statusCode})';
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

  Future<void> _updateUserStatus({
    required int userId,
    required bool approve,
  }) async {
    if (isUpdating) return;

    setState(() => isUpdating = true);
    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Oturum bulunamadı')));
        return;
      }

      final endpoint = approve ? 'approve-user' : 'reject-user';
      final response = await http.put(
        Uri.parse('http://10.0.2.2:4000/api/admin/$endpoint/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Kullanıcı onaylandı' : 'Kullanıcı reddedildi',
            ),
          ),
        );
        await _fetchPendingUsers();
      } else {
        String message = 'İşlem başarısız (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
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
          ? const Center(child: Text('Onay bekleyen kullanıcı yok'))
          : ListView.builder(
              itemCount: pendingUsers.length,
              itemBuilder: (context, index) {
                final user = pendingUsers[index] as Map<String, dynamic>;
                final id = user['id'];
                final name = user['name'] ?? '-';
                final email = user['email'] ?? '-';
                final employeeNo = user['employee_no'] ?? '-';
                final department = user['department'] ?? '-';
                final role = user['role'] ?? '-';
                final userId = int.tryParse(id.toString());

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Email: $email'),
                        Text('Personel No: $employeeNo'),
                        Text('Departman: $department'),
                        Text('Rol: $role'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isUpdating || userId == null
                                    ? null
                                    : () => _updateUserStatus(
                                        userId: userId,
                                        approve: true,
                                      ),
                                child: const Text('Onayla'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isUpdating || userId == null
                                    ? null
                                    : () => _updateUserStatus(
                                        userId: userId,
                                        approve: false,
                                      ),
                                child: const Text('Reddet'),
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
    );
  }
}
