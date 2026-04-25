import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<String?> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userName");
  }

  Future<String?> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userRole");
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('userRole');

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ana Sayfa")),
      body: FutureBuilder(
        future: Future.wait([_getUserName(), _getUserRole()]),
        builder: (context, snapshot) {
          String name = "";
          String role = "";

          if (snapshot.hasData) {
            name = snapshot.data![0] ?? "";
            role = snapshot.data![1] ?? "";
          }

          final isAdmin = role == 'admin';

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Hoş geldin $name",
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 30),

                  // Oda listesi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/rooms');
                      },
                      child: const Text('Oda Listesi'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // QR ile temizlik (personel + admin)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/qr-cleaning');
                      },
                      child: const Text('QR ile Temizlik Kaydı'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Kendi kayıtlarım
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/my-cleanings');
                      },
                      child: const Text('Temizlik Kayıtlarım'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/my-scheduled-tasks');
                      },
                      child: const Text('Planlı Görevlerim'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // SADECE ADMIN butonları
                  if (isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                       Navigator.pushNamed(context, '/admin-scheduled-task');
                   },
                            child: const Text('Planlı Görev Oluştur'),
                      ),
                       ),
                     const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/admin-weekly-kpi');
                        },
                        child: const Text('Haftalık KPI Karşılaştırması'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/admin-pending-users');
                        },
                        child: const Text('Onay Bekleyen Kullanıcılar'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/admin-all-cleanings');
                        },
                        child: const Text('Tüm Temizlik Kayıtları (Admin)'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/admin-users');
                        },
                        child: const Text('Tüm Kullanıcılar (Admin)'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Çıkış
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _logout(context),
                      child: const Text('Çıkış Yap'),
                    ),
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
