import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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

      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/rooms'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          rooms = jsonDecode(response.body) as List;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Oda listesi alınamadı (Kod: ${response.statusCode}).';
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

  // Sadece sayıdan oluşan veya boş/eksik location_name değerlerini filtreler.
  // Eski kayıtlarda location_name yerine location_id sayısı gelebilir.
  bool _isValidLocationName(String? value) {
    if (value == null || value.isEmpty || value == '-') return false;
    if (RegExp(r'^\d+$').hasMatch(value)) return false;
    return true;
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final name = room['name']?.toString() ?? 'İsimsiz Oda';
    final locationName = room['location_name']?.toString();
    final description = room['description']?.toString();

    final showLocation = _isValidLocationName(locationName);
    final showDescription =
        description != null && description.isNotEmpty && description != '-';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.staffAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.meeting_room,
                color: AppColors.staffAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.heading2),
                  if (showLocation || showDescription)
                    const SizedBox(height: AppSpacing.xs),
                  if (showLocation)
                    _infoRow(
                      Icons.location_on,
                      'Konum: $locationName',
                    ),
                  if (showLocation && showDescription)
                    const SizedBox(height: 2),
                  if (showDescription)
                    _infoRow(
                      Icons.info_outline,
                      description,
                      maxLines: 2,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oda Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              : rooms.isEmpty
                  ? const EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: 'Henüz Oda Yok',
                      message: 'Sistemde tanımlı oda bulunmuyor.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRooms,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) => _roomCard(
                          rooms[index] as Map<String, dynamic>,
                        ),
                      ),
                    ),
    );
  }
}
