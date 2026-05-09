import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InventoryMethodologyScreen extends StatelessWidget {
  const InventoryMethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envanter Metodolojisi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.info_outline,
            color: AppColors.primary,
            title: 'Giriş',
            content:
                'Envanter yönetimi, kuruluşların kaynaklarını verimli kullanmasının temel taşıdır. '
                'Sistemimiz, Pareto Yasası (1906), Wilson EOQ Modeli (1934) ve modern lean envanter '
                'prensiplerini birleştirerek otomatik karar destek sağlar. '
                'Bu sayfa, sistemin envanter analizinde kullandığı bilimsel yöntemleri açıklar.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSection(
            icon: Icons.pie_chart_outline,
            color: AppColors.primary,
            title: '1. ABC Analizi (Pareto Yasası)',
            content:
                'Vilfredo Pareto\'nun 1906\'da gözlemlediği 80/20 prensibi, envanter yönetiminde '
                'ABC sınıflandırması olarak uygulanır. Sistem, son 30 günlük kullanım hacmine göre '
                'kümülatif yüzde dağılımı temel alarak stok kalemlerini üç sınıfa ayırır:\n\n'
                '• A sınıfı: Kümülatif değerin %0-80\'i — yüksek değerli, kritik takip\n'
                '• B sınıfı: %80-95 arası — orta değerli, periyodik kontrol\n'
                '• C sınıfı: %95+ — düşük değerli, esnek takip\n\n'
                'Bu yaklaşım, kaynak önceliklendirme için endüstri standardıdır (ISO 9001).',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'ABC Sınıflandırma Algoritması',
            formula:
                'kümülatif % ≤ 80  →  A sınıfı\n'
                '80 < kümülatif % ≤ 95  →  B sınıfı\n'
                'kümülatif % > 95  →  C sınıfı',
            note: 'Sıralama: kullanım hacmine göre azalan',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.shopping_cart_outlined,
            color: AppColors.warning,
            title: '2. Yeniden Sipariş Noktası (Wilson EOQ)',
            content:
                'R. H. Wilson\'ın 1934\'te formüle ettiği envanter modeli, modern stok yönetiminin '
                'temelidir. Sistem, her stok kalemi için yeniden sipariş noktasını (Reorder Point) '
                'şu üç parametreyle hesaplar:\n\n'
                '• Günlük ortalama tüketim: son 7 günlük "use" log\'larından\n'
                '• Tedarik süresi (Lead Time): 7 gün (varsayılan)\n'
                '• Güvenlik stoğu (Safety Stock): 3 gün\n\n'
                'Stok ROP\'a düştüğünde, sistem otomatik sipariş önerisi sunar.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'Reorder Point Formülü',
            formula:
                'ROP = günlük_ortalama × (lead_time + safety_stock)\n'
                '    = günlük_ortalama × (7 + 3)\n'
                '    = günlük_ortalama × 10',
            note: 'Lead time ve safety stock ihtiyaca göre ayarlanabilir',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.notifications_active_outlined,
            color: AppColors.error,
            title: '3. Akıllı Uyarı Sistemi (4 Kademeli)',
            content:
                'Sistem, her stok kaleminin durumunu dört kademeli akıllı uyarı sistemi ile '
                'sınıflandırır. Bu yaklaşım, yöneticinin tek bakışta envanter sağlığını '
                'değerlendirmesini sağlar.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAlertLevelCard(
            'Tükendi',
            Colors.black87,
            'current = 0',
            'Acil sipariş gerekli',
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildAlertLevelCard(
            'Kritik',
            AppColors.error,
            'current ≤ min_threshold',
            'Minimum eşik altında, hızlı sipariş',
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildAlertLevelCard(
            'Sipariş Zamanı',
            AppColors.warning,
            'current ≤ ROP',
            'Yeniden sipariş noktası altında',
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildAlertLevelCard(
            'Normal',
            AppColors.success,
            'current > ROP',
            'Yeterli stok, takibe devam',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.analytics_outlined,
            color: AppColors.primary,
            title: '4. Günlük Tüketim Hesabı',
            content:
                'Günlük ortalama tüketim, sistemin tüm tahminlerinin temelidir. '
                'Son 7 günlük "use" eylemleri toplanır ve farklı gün sayısına bölünür. '
                'Bu yöntem, anlık dalgalanmaları yumuşatarak gerçekçi bir trend sunar.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'Günlük Ortalama Formülü',
            formula:
                'günlük_ortalama = toplam_kullanım(son 7 gün) / aktif_gün_sayısı\n\n'
                'tahmini_bitiş = mevcut_stok / günlük_ortalama',
            note: 'Aktif gün: kullanım kaydı olan benzersiz günler',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.shopping_basket_outlined,
            color: AppColors.warning,
            title: '5. Önerilen Sipariş Miktarı',
            content:
                'Sipariş miktarı, 30 günlük hedef tüketim üzerinden hesaplanır. '
                'Mevcut stoktan eksik olan miktar, önerilen sipariş olarak sunulur. '
                'Bu yaklaşım, depolama maliyetini minimize ederken tükenmeyi önler.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'Önerilen Sipariş Formülü',
            formula:
                'önerilen_sipariş = (günlük_ortalama × 30) - mevcut_stok\n\n'
                'Eğer önerilen ≤ 0 → sipariş gerekmez',
            note: 'Hedef: 30 günlük yeterlilik',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.trending_up,
            color: AppColors.success,
            title: '6. Lean Envanter Prensipleri',
            content:
                'Sistem, Toyota Üretim Sistemi\'nden ilham alan lean envanter prensipleriyle '
                'uyumlu çalışır:\n\n'
                '• Just-In-Time (JIT): Doğru zamanda, doğru miktarda sipariş\n'
                '• Pareto önceliklendirme: Kaynakları A sınıfına odakla\n'
                '• Sürekli izleme: Otomatik uyarı ile manuel kontrol minimum\n'
                '• Veri tabanlı karar: Tahminler sezgi yerine matematiğe dayalı\n\n'
                'Bu prensipler, israfı azaltırken servis seviyesini koruyan '
                'modern envanter yönetiminin temelidir.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.calculate_outlined,
            color: AppColors.primary,
            title: '7. Optimum Sipariş Miktarı (EOQ)',
            content:
                'F. W. Harris\'in 1913\'te ortaya attığı ve R. H. Wilson\'ın '
                '1934\'te genelleştirdiği Ekonomik Sipariş Miktarı (Economic Order '
                'Quantity, EOQ) modeli, klasik envanter optimizasyon yöntemidir. '
                'Bir defada ne kadar sipariş verilmesi gerektiğini hesaplar.\n\n'
                'Model, iki temel maliyeti dengeler:\n\n'
                '• Sipariş maliyeti (S): her sipariş seferi maliyeti\n'
                '• Taşıma maliyeti (H): birim başına yıllık depolama maliyeti\n\n'
                'Sistem, varsayılan olarak S=50 TL ve H=10 TL/birim/yıl kullanır. '
                'Bu değerler, gerçek satın alma verisi ile güncellenebilir.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'EOQ Formülü (Wilson 1934)',
            formula:
                'Q* = sqrt(2 * D * S / H)\n\n'
                'D = yıllık talep (günlük_ortalama * 365)\n'
                'S = sipariş başına maliyet (50 TL)\n'
                'H = birim başına yıllık taşıma (10 TL)\n\n'
                'Yıllık sipariş sayısı = D / Q*\n'
                'İki sipariş arası gün  = 365 / (D/Q*)',
            note: 'Maliyet parametreleri ihtiyaca göre ayarlanabilir',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSection(
            icon: Icons.security_outlined,
            color: AppColors.warning,
            title: '8. İstatistiksel Güvenlik Stoğu',
            content:
                'Sabit gün sayısı yerine, talep belirsizliğini hesaba katan '
                'istatistiksel güvenlik stoğu kullanılır. Bu yaklaşım, %95 '
                'servis seviyesi (stoksuz kalmama olasılığı) garanti eder.\n\n'
                'Formül, talebin standart sapması ve tedarik süresinin karekökü '
                'ile orantılıdır. Talep dalgalandıkça güvenlik stoğu artar.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFormulaCard(
            title: 'Safety Stock Formülü',
            formula:
                'SS = Z * sigma * sqrt(L)\n\n'
                'Z = 1.65 (%95 servis seviyesi)\n'
                'sigma = talep standart sapması (günlük_ort * 0.3)\n'
                'L = tedarik süresi (lead time, 7 gün)',
            note: 'Daha yüksek servis seviyesi = daha yüksek Z değeri',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReferencesCard(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Envanter Yönetim Metodolojisi',
                    style: AppTextStyles.heading1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sistemimizde uygulanan akademik temelli envanter yönetim '
              'yöntemlerinin teknik açıklaması.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Text(
                'Bu sayfa, sistemin "neden" ve "nasıl" hesapladığını '
                'şeffaf şekilde açıklar. Akademik dayanaklar tezde belirtilmiştir.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
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
                Icon(icon, color: color, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.heading2.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(content, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required String formula,
    required String note,
  }) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.functions,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                formula,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertLevelCard(
      String label, Color color, String condition, String desc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  Text(desc, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Akademik Referanslar',
                    style: AppTextStyles.heading2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ref('Pareto, V. (1906). Manuale di Economia Politica. '
                'ABC sınıflandırması ve 80/20 prensibinin temeli.'),
            _ref('Wilson, R. H. (1934). A Scientific Routine for Stock Control. '
                'Reorder Point ve EOQ modelinin formülasyonu.'),
            _ref('Harris, F. W. (1913). How Many Parts to Make at Once. '
                'Economic Order Quantity (EOQ) modelinin orijinal sunumu.'),
            _ref('ISO 9001:2015. Quality Management Systems — Resource Management. '
                'Envanter sınıflandırma standartları.'),
            _ref('Ohno, T. (1988). Toyota Production System. '
                'Just-In-Time ve lean envanter prensipleri.'),
          ],
        ),
      ),
    );
  }

  Widget _ref(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
