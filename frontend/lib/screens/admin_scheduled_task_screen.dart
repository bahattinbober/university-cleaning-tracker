import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

const _baseUrl = 'http://192.168.1.27:4000';

const _monthNames = [
  '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String _formatDisplay(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_monthNames[dt.month]} ${dt.year} - $h:$m';
}

String _formatForApi(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}:00';

class AdminScheduledTaskScreen extends StatefulWidget {
  const AdminScheduledTaskScreen({super.key});

  @override
  State<AdminScheduledTaskScreen> createState() => _AdminScheduledTaskScreenState();
}

class _AdminScheduledTaskScreenState extends State<AdminScheduledTaskScreen> {
  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Dropdown state
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _staffUsers = [];
  int? _selectedRoomId;
  int? _selectedUserId;
  DateTime? _selectedDateTime;

  // Screen state
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  String? _token;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    if (_token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı, tekrar giriş yapınız.')),
      );
      Navigator.pop(context);
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    try {
      // Odalar ve kullanıcılar paralel çekiliyor
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/rooms'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/users'), headers: headers),
      ]);

      if (!mounted) return;

      final roomsRes = results[0];
      final usersRes = results[1];

      if (roomsRes.statusCode == 200) {
        final list = jsonDecode(roomsRes.body) as List<dynamic>;
        _rooms = list.cast<Map<String, dynamic>>();
      }

      if (usersRes.statusCode == 200) {
        final list = jsonDecode(usersRes.body) as List<dynamic>;
        _staffUsers = list
            .cast<Map<String, dynamic>>()
            .where((u) => u['role'] == 'staff')
            .toList();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veriler yüklenirken bir hata oluştu')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String? _validateInputs() {
    if (_selectedRoomId == null) return 'Lütfen bir oda seçin';
    if (_titleController.text.trim().isEmpty) return 'Görev başlığı zorunlu';
    if (_selectedDateTime == null) return 'Tarih ve saat seçin';
    if (_selectedDateTime!.isBefore(DateTime.now())) return 'Geçmiş tarih seçilemez';
    return null;
  }

  Future<void> _createScheduledTask() async {
    final error = _validateInputs();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/scheduled-tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'room_id': _selectedRoomId,
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'scheduled_for': _formatForApi(_selectedDateTime!),
          'assigned_user_id': _selectedUserId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görev başarıyla oluşturuldu')),
        );
        Navigator.pop(context);
      } else {
        String message = 'Görev oluşturulamadı (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planlı Görev Oluştur')),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.adminAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add_task, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Planlı Görev Oluştur',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Personele atanacak görevi planlayın',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Oda Seç
                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoomId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Oda Seç',
                        prefixIcon: Icon(Icons.meeting_room),
                        hintText: 'Oda seçin',
                      ),
                      items: _rooms.map((r) {
                        final loc = r['location_name'] as String? ?? '';
                        final label = loc.isNotEmpty ? '${r['name']} — $loc' : '${r['name']}';
                        return DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRoomId = v),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Başlık
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Görev Başlığı',
                        hintText: 'ör: Toplantı odası temizliği',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Açıklama
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Tarih / Saat picker
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tarih ve Saat',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDateTime != null
                              ? _formatDisplay(_selectedDateTime!)
                              : 'Tarih ve saat seçin',
                          style: _selectedDateTime != null
                              ? AppTextStyles.body
                              : AppTextStyles.caption,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Personel Seç (opsiyonel)
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedUserId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Personel',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Personel seçin (opsiyonel)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Atama yapılmasın',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._staffUsers.map((u) => DropdownMenuItem<int?>(
                              value: u['id'] as int,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${u['name']} — ${u['email']}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedUserId = v),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _createScheduledTask,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Görev Oluştur'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
    );
  }
}
