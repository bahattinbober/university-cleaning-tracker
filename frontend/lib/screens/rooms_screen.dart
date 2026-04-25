import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
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

      final url = Uri.parse('http://10.0.2.2:4000/api/rooms'); // emulator için
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          rooms = data as List;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Oda listesi alınamadı (Kod: ${response.statusCode}).';
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
      appBar: AppBar(
        title: const Text('Oda Listesi'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final name = room['name'] ?? 'İsimsiz oda';
                    final desc = room['description'] ?? '';
                    final locationId = room['location_id'] ?? '-';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${room['id']}'),
                      ),
                      title: Text(name),
                      subtitle: Text('Lokasyon: $locationId\n$desc'),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
