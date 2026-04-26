import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';

// ---------------------------------------------------------------------------
// QR Tarayıcı Ekranı
// ---------------------------------------------------------------------------

class QRCleaningScreen extends StatefulWidget {
  const QRCleaningScreen({super.key});

  @override
  State<QRCleaningScreen> createState() => _QRCleaningScreenState();
}

class _QRCleaningScreenState extends State<QRCleaningScreen> {
  bool isProcessing = false;
  bool hasNavigatedToForm = false;
  String? lastMessage;

  Future<void> _handleCode(String? rawValue, [BarcodeType? _]) async {
    await _openFormAfterScan(rawValue);
  }

  Future<void> _openFormAfterScan(String? rawValue) async {
    if (rawValue == null || isProcessing || hasNavigatedToForm) return;

    setState(() {
      isProcessing = true;
      lastMessage = null;
    });

    int? roomId;
    try {
      roomId = int.parse(rawValue.trim());
    } catch (_) {
      setState(() {
        lastMessage =
            'QR beklenen formatta değil (sadece oda ID olmalı). Okunan: $rawValue';
        isProcessing = false;
      });
      return;
    }

    setState(() {
      hasNavigatedToForm = true;
      isProcessing = false;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CleaningLogFormScreen(roomId: roomId!),
      ),
    );

    if (!mounted) return;
    setState(() {
      hasNavigatedToForm = false;
      lastMessage = 'Yeni kayıt için tekrar QR okutabilirsiniz.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR ile Temizlik Kaydı')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                _handleCode(barcode.rawValue, barcode.type);
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: AppColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.all(AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: isProcessing
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  const Expanded(
                                    child: Text(
                                      'Bir oda QR kodunu kameraya gösterin.',
                                      style: AppTextStyles.body,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Text(
                                'QR içeriği oda ID olmalı (örnek: 1, 2, 3 ...)',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                  ),
                  if (lastMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        lastMessage!,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  const Spacer(),
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _handleCode('1'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: const Text('DEBUG: Manual Test'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Temizlik Kaydı Formu
// ---------------------------------------------------------------------------

class CleaningLogFormScreen extends StatefulWidget {
  const CleaningLogFormScreen({super.key, required this.roomId});

  final int roomId;

  @override
  State<CleaningLogFormScreen> createState() => _CleaningLogFormScreenState();
}

class _CleaningLogFormScreenState extends State<CleaningLogFormScreen> {
  final TextEditingController notesController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  bool isSubmitting = false;
  bool isLoadingRoomName = true;
  String roomName = '';
  String userName = '';
  int? userId;
  String? token;
  File? pickedImage;

  // Backend sadece 'completed' kabul eder; seçim KPI gösterimi için UI mock.
  String _selectedStatus = 'completed';

  @override
  void initState() {
    super.initState();
    _prepareForm();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _prepareForm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
      userName = prefs.getString('userName') ?? '';
      userId = prefs.getInt('userId');
    });

    await _loadRoomName();
  }

  Future<void> _loadRoomName() async {
    if (token == null) {
      setState(() {
        roomName = 'Oda #${widget.roomId}';
        isLoadingRoomName = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/rooms'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final rooms = jsonDecode(response.body) as List<dynamic>;
        final found = rooms.cast<Map<String, dynamic>>().firstWhere(
          (room) => room['id'] == widget.roomId,
          orElse: () => <String, dynamic>{},
        );
        setState(() {
          roomName = (found['name'] as String?) ?? 'Oda #${widget.roomId}';
          isLoadingRoomName = false;
        });
      } else {
        setState(() {
          roomName = 'Oda #${widget.roomId}';
          isLoadingRoomName = false;
        });
      }
    } catch (_) {
      setState(() {
        roomName = 'Oda #${widget.roomId}';
        isLoadingRoomName = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (image == null) return;
    setState(() => pickedImage = File(image.path));
  }

  Future<String?> _imageToBase64() async {
    if (pickedImage == null) return null;
    final bytes = await pickedImage!.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitCleaningLog() async {
    if (isSubmitting) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı, tekrar giriş yapınız.'),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    final statusLabel = StatusTranslator.cleaningStatus(_selectedStatus);

    try {
      final imageBase64 = await _imageToBase64();
      final response = await http.post(
        Uri.parse('http://10.0.2.2:4000/api/cleaning-logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'room_id': widget.roomId,
          'status': 'completed', // Backend sadece 'completed' kabul eder
          'notes': notesController.text.trim(),
          'image': imageBase64,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Temizlik kaydı başarıyla eklendi ($statusLabel).',
            ),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        String message =
            'Kayıt oluşturulamadı (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget _infoCard(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$label: $value',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label, IconData icon) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
      ),
      onSelected: (_) => setState(() => _selectedStatus = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temizlik Kaydı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              Icons.meeting_room,
              AppColors.staffAccent,
              'Oda',
              isLoadingRoomName ? 'Yükleniyor...' : roomName,
            ),
            const SizedBox(height: AppSpacing.md),
            _infoCard(
              Icons.person,
              AppColors.primary,
              'Personel',
              userName.isEmpty ? 'Yükleniyor...' : userName,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Temizlik Türü',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _statusChip('completed', 'Tamamlandı', Icons.check_circle),
                _statusChip('on_time', 'Zamanında', Icons.schedule),
                _statusChip('late', 'Geç', Icons.warning_amber),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Fotoğraf Ekle'),
                ),
                if (pickedImage != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      pickedImage!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                hintText:
                    'Yapılan işler, dikkat edilmesi gereken noktalar...',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitCleaningLog,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Temizlik Yapıldı'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
