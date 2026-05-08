import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KpiMethodologyScreen extends StatelessWidget {
  const KpiMethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Metodolojisi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAŞLIK
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'KPI Hesaplama Metodolojisi',
                            style: AppTextStyles.heading1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Bu sistem, performans değerlendirmesini akademik literatüre dayalı bir metodoloji ile yapar. '
                      'Aşağıda hesaplama detayları ve bilimsel temeli yer almaktadır.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 1: BALANCED SCORECARD
            _sectionCard(
              icon: Icons.balance,
              title: 'Yaklaşım: Balanced Scorecard',
              content:
                  'Sistemin temelinde, Robert S. Kaplan ve David P. Norton tarafından 1992 yılında geliştirilen '
                  'Balanced Scorecard (Dengeli Karne) metodolojisi yer alır.\n\n'
                  'Bu yaklaşım, performansı tek bir metrik üzerinden değil, çoklu boyutlar üzerinden ölçer. '
                  'Sistem 4 ana bileşen kullanır.',
            ),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 2: 4 BİLEŞEN
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.donut_small,
                            color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('4 Bileşen ve Formüller',
                            style: AppTextStyles.heading2),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _componentBlock(
                      number: '1',
                      title: 'Verimlilik',
                      weight: '%40',
                      color: AppColors.primary,
                      formula: 'kayit_sayisi / hedef × 100',
                      target: 'hedef = ortalama × 1.5',
                      reason:
                          'Personelin temel görevi temizlik kayıtlarını sisteme girmektir. '
                          'Bu nedenle verimlilik en yüksek ağırlığa sahiptir.',
                    ),
                    _componentBlock(
                      number: '2',
                      title: 'Kalite',
                      weight: '%30',
                      color: AppColors.success,
                      formula: '(fotograf + not) / (toplam × 2) × 100',
                      target: 'maksimum: her kayit foto + not icerirse %100',
                      reason:
                          'Görsel belgelendirme ve detaylı raporlama, denetlenebilirlik için kritik öneme sahiptir.',
                    ),
                    _componentBlock(
                      number: '3',
                      title: 'Zamanlama',
                      weight: '%20',
                      color: AppColors.warning,
                      formula: 'zamaninda_kayit / toplam × 100',
                      target: '%100 = tüm kayıtlar zamanında',
                      reason:
                          'Planlanan zamanda görev tamamlama, organizasyonel disiplinin göstergesidir.',
                    ),
                    _componentBlock(
                      number: '4',
                      title: 'Uyumluluk',
                      weight: '%10',
                      color: AppColors.error,
                      formula: '(toplam - gec_kayit) / toplam × 100',
                      target: 'gecikme yoksa %100',
                      reason:
                          'Süreç uyumu, kurumsal politikalara uyumun göstergesidir.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 3: FINAL FORMÜL
            Card(
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.functions,
                            color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Final Skor Formülü',
                            style: AppTextStyles.heading2),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Genel Skor =',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '(Verimlilik × 0.40)\n'
                            '+ (Kalite × 0.30)\n'
                            '+ (Zamanlama × 0.20)\n'
                            '+ (Uyumluluk × 0.10)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sonuç 0-100 arası bir değerdir ve ardından harf notu ile performans seviyesine dönüştürülür.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 4: HARF NOTU
            _gradeCard(),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 5: SEVİYE SİSTEMİ
            _levelCard(),
            const SizedBox(height: AppSpacing.md),

            // BÖLÜM 6: AKADEMİK REFERANSLAR
            _sectionCard(
              icon: Icons.menu_book_outlined,
              title: 'Akademik Referanslar',
              content:
                  '• Kaplan, R. S., & Norton, D. P. (1992). The balanced scorecard – measures that drive performance. '
                  'Harvard Business Review, 70(1), 71-79.\n\n'
                  '• Locke, E. A., & Latham, G. P. (1990). A theory of goal setting and task performance. '
                  'Englewood Cliffs, NJ: Prentice Hall.\n\n'
                  '• ISO 9001:2015 - Kalite Yönetim Sistemleri Şartları, Uluslararası Standardizasyon Örgütü.\n\n'
                  "• Doran, G. T. (1981). There's a S.M.A.R.T. way to write management's goals and objectives. "
                  'Management Review, 70(11), 35-36.',
            ),
            const SizedBox(height: AppSpacing.md),

            // BİLGİ NOTU
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bu metodoloji, ISO 9001 kalite yönetim standartları ve '
                      'OKR (Objectives and Key Results) hedef belirleme yaklaşımıyla uyumludur.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(title, style: AppTextStyles.heading2)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(content, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  Widget _componentBlock({
    required String number,
    required String title,
    required String weight,
    required Color color,
    required String formula,
    required String target,
    required String reason,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  weight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _kvBlock('Formül', formula, monospace: true),
          const SizedBox(height: 4),
          _kvBlock('Hedef', target),
          const SizedBox(height: 4),
          _kvBlock('Gerekçe', reason),
        ],
      ),
    );
  }

  Widget _kvBlock(String label, String value,
      {bool monospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.bold)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _gradeCard() {
    const grades = [
      ('A+', '95-100', AppColors.success),
      ('A', '85-94', AppColors.success),
      ('B', '70-84', Color(0xFF7C3AED)),
      ('C', '55-69', AppColors.warning),
      ('D', '40-54', AppColors.warning),
      ('F', '0-39', AppColors.error),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grade_outlined,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Harf Notu Skalası',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: grades.map((g) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: g.$3.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: g.$3.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        g.$1,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: g.$3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(g.$2, style: AppTextStyles.caption),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard() {
    const levels = [
      ('Üstün Performans', '85+', AppColors.success),
      ('Yüksek Performans', '70-84', Color(0xFF7C3AED)),
      ('İyi Performans', '55-69', AppColors.primary),
      ('Gelişmekte', '40-54', AppColors.warning),
      ('Geliştirilmeli', '<40', AppColors.error),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Performans Seviyeleri',
                    style: AppTextStyles.heading2),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...levels.map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: l.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child:
                            Text(l.$1, style: AppTextStyles.body)),
                    Text(
                      l.$2,
                      style: AppTextStyles.caption
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
