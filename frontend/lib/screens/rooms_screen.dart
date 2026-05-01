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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchRooms();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole');
    if (mounted) setState(() => _isAdmin = role == 'admin');
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
        Uri.parse('http://192.168.1.27:4000/api/rooms'),
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

  Future<void> _createRoom(
    BuildContext dialogContext,
    String name,
    String description,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('http://192.168.1.27:4000/api/rooms'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description.isEmpty ? null : description,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oda başarıyla eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchRooms();
      } else {
        String message = 'Oda eklenemedi';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showAddRoomDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: const Text('Yeni Oda Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Oda Adı',
                      hintText: 'Örn: A101, K339',
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (opsiyonel)',
                      hintText: 'Örn: Toplantı odası',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Oda adı zorunlu'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        setLocalState(() => isSubmitting = true);
                        await _createRoom(
                          ctx,
                          name,
                          descController.text.trim(),
                        );
                        setLocalState(() => isSubmitting = false);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ekle'),
              ),
            ],
          ),
        );
      },
    );

  }

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
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddRoomDialog,
              icon: const Icon(Icons.add),
              label: const Text('Oda Ekle'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
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
