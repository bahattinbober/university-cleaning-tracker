import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // şu an backend bu tokeni kontrol etmiyor ama ileride ekleriz

      // Token boşa gitmesin, header'a koyuyoruz
      final url = Uri.parse('http://10.0.2.2:4000/api/users');
      final response = await http.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = data as List;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Kullanıcı listesi alınamadı (kod: ${response.statusCode}).';
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
      appBar: AppBar(title: const Text('Tüm Kullanıcılar (Admin)')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : users.isEmpty
                  ? const Center(child: Text('Hiç kullanıcı bulunamadı.'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final id = user['id'] ?? '-';
                        final name = user['name'] ?? 'İsimsiz';
                        final email = user['email'] ?? '';
                        final role = user['role'] ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('$id'),
                          ),
                          title: Text(name),
                          subtitle: Text('$email\nRol: $role'),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}
