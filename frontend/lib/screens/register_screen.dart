import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final employeeNoController = TextEditingController();
  final departmentController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscure = true;

  static const String _allowedDomain = '@pau.edu.tr';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    employeeNoController.dispose();
    departmentController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final employeeNo = employeeNoController.text.trim();
    final department = departmentController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || employeeNo.isEmpty || department.isEmpty) {
      return 'Lütfen tüm alanları doldurun';
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin';
    }

    if (!email.endsWith(_allowedDomain)) {
      return 'Sadece $_allowedDomain uzantılı e-posta kabul edilir';
    }

    if (password.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }

    return null;
  }

  Future<void> _register() async {
    final validationMessage = _validateInputs();
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:4000/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text.trim(),
          'employee_no': employeeNoController.text.trim(),
          'department': departmentController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıt alındı, admin onayı bekleniyor')),
        );
        Navigator.pop(context);
      } else {
        String message = 'Kayıt oluşturulamadı';
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
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.cleaning_services, color: Colors.white, size: 40),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              const Text(
                'Hesap Oluştur',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading1,
              ),

              const SizedBox(height: AppSpacing.xs),

              const Text(
                'Hızlı kayıt sonrası admin onayı bekleyecek',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Ad Soyad
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // E-posta
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  hintText: 'ornek@pau.edu.tr',
                  prefixIcon: Icon(Icons.email_outlined),
                  helperText: '@pau.edu.tr ile bitmelidir',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Sicil No
              TextField(
                controller: employeeNoController,
                decoration: const InputDecoration(
                  labelText: 'Sicil No',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Departman
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Departman',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Şifre
              TextField(
                controller: passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Bilgi kutusu
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Hesabınız admin onayı sonrası aktifleşecektir',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Kayıt ol butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Kayıt Ol'),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Giriş yap linki
              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Zaten hesabın var mı? ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: 'Giriş Yap',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
