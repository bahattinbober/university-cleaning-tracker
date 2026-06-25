# Üniversite Personel Çalışma Takip Sistemi

**Pamukkale Üniversitesi — Bilgisayar Mühendisliği Bitirme Tezi, 2025–2026 Bahar Dönemi**

---

## 📌 Proje Hakkında

Üniversite temizlik personelinin oda bazındaki çalışmalarını QR kod ve GPS doğrulamasıyla dijital ortamda takip eden; performans, envanter ve maliyet yönetimi için akademik literatür temelli karar destek modülleri sunan mobil uygulama.

Sistem, 15 Mayıs 2026 tarihinde Pamukkale Teknokent'te canlı olarak demonstre edilmiştir.

---

## 🎯 Akademik Dayanak (12 Kaynak)

**Performans Yönetimi**
- Balanced Scorecard — Kaplan & Norton (1992)
- Goal-Setting Theory — Locke & Latham (1990)
- SMART Goals — Doran (1981)
- Behavioral Reinforcement — Skinner (1953)

**Envanter & Talep Yönetimi**
- EOQ Modeli — Harris (1913); Wilson (1934) → Q* = √(2DS/H)
- ABC Analizi — Pareto (1906)
- Exponential Smoothing — Brown (1956) → Fₜ₊₁ = αAₜ + (1−α)Fₜ, α = 0.3
- Toyota Production System — Ohno (1988)

**Maliyet & Kalite**
- Activity-Based Costing — Kaplan & Cooper (1988)
- ISO 9001:2015 Quality Management
- Anomali Tespiti — Z-Skor; Barnett & Lewis (1994)

**Görselleştirme**
- Information Visualization — Tufte (1983)

---

## ✨ Özellikler

### 📊 KPI / Balanced Scorecard Modülü
- 4 BSC boyutu: Verimlilik (%40) · Kalite (%30) · Zamanlama (%20) · Uyumluluk (%10)
- 16 SMART KPI hedefi (Locke-Latham + Doran)
- Harf notu sistemi (A → F) + 5 performans seviyesi
- Z-Skor istatistiksel benchmark — en yüksek: **Z = +2.66**
- Ortalama BSC skoru: **76.8 / 100**, KPI başarı oranı: **%81.3**
- A4 PDF kurumsal performans raporu (pdfkit, 4 sayfa)

### 📦 Stok / Envanter Modülü
- ABC Analizi: A sınıfı **11 kalem → %77** kullanım hacmi
- Wilson EOQ önerisi: **121 paket** (optimal sipariş)
- Brown üssel düzgünleştirme: α = 0.3, MAPE **%9.4**
- Reorder Point uyarıları (4 kademe)
- Toplam stok değeri: **160.020 TL** (18 kalem, 375 hareket)

### 💰 Bütçe / Maliyet Modülü
- Activity-Based Costing — lokasyon bazlı maliyet dağılımı
- 4 PAÜ lokasyonu × kategori bazlı pasta grafik
- 6 aylık maliyet trendi

### 📈 Analiz & Görselleştirme
- Admin Dashboard (anlık KPI + stok özeti)
- Heatmap: gün × saat temizlik yoğunluğu (Tufte ilkeleri)
- Z-Skor karşılaştırma ekranı (18 aktif personel)
- QR Tarama + Haversine GPS doğrulaması (50 m tolerans)

---

## 🛠️ Teknoloji Stack

**Frontend**
- Flutter 3.x (Dart) — 26 mobil ekran, 47 widget
- `mobile_scanner 7.1.3`, `fl_chart`, `pdf`, `printing`, `http`, `flutter_secure_storage`

**Backend**
- Node.js 18.x + Express.js — 38 REST API uç noktası
- SQLite 3 (`better-sqlite3`) — 8 tablo, 1.423 kayıt
- `bcrypt` (salt = 10), `jsonwebtoken` (HS256, 8 saat), `pdfkit`, `express-rate-limit`, `express-validator`

---

## 📐 Sistem Mimarisi

3 katmanlı (three-tier) istemci-sunucu mimarisi:

```
Flutter Mobile (Dart)          →  HTTPS / JWT
Express Router (38 endpoint)   →  Controllers + Middleware
DSS Services (BSC, EOQ, ABC,   →  SQLite (8 tablo)
Brown, Z-Skor, Costing)
```

Detaylı diyagramlar:
- [📐 Sistem Mimarisi](https://github.com/bahattinbober/university-cleaning-tracker/blob/main/docs/architecture.html)
- [💾 ERD — Veritabanı Şeması](https://github.com/bahattinbober/university-cleaning-tracker/blob/main/docs/erd.html)

---

## 🚀 Kurulum

**Önkoşullar:** Node.js 18+, Flutter 3.x

```bash
# Backend
cd backend/backend
npm install
npm run dev          # http://localhost:4000

# Frontend
cd frontend
flutter pub get
flutter run          # Emülatör: 10.0.2.2:4000

# Demo verisi yükle
cd backend/backend
node fix_and_seed.js
node add_inventory_usage.js
```

**Demo Hesaplar**

| Rol | E-posta |
|-----|---------|
| Admin | admin@pau.edu.tr |
| Personel | test.personel@pau.edu.tr |

**QR Üretimi:** `http://localhost:4000/qr.html`

---

## 📊 Proje İstatistikleri

| Metrik | Değer |
|--------|-------|
| Toplam kod satırı | 18.811 |
| Backend (JavaScript) | 2.987 satır / 14 dosya |
| Frontend (Dart) | 15.824 satır / 35 dosya |
| Toplam commit | 51 |
| REST API uç noktası | 38 |
| JWT korumalı uç nokta | 36 (%94.7) |
| Mobil ekran | 26 |
| Flutter widget | 47 |
| Veri tabanı tablosu | 8 |
| Entegrasyon testi dosyası | 4 |
| Lint hatası | 0 |
| Akademik dayanak | 12 |
| Demo veri — temizlik kaydı | 966 (90 günlük) |
| Demo veri — stok hareketi | 375 |

---

## 🎓 Akademik Bilgiler

| | |
|--|--|
| Üniversite | Pamukkale Üniversitesi |
| Fakülte | Mühendislik Fakültesi |
| Bölüm | Bilgisayar Mühendisliği |
| Öğrenci | Bahattin BÖBER (22253076) |
| Danışman | Prof. Dr. Sezai TOKAT |
| Dönem | 2025–2026 Bahar |
| Tez No | CENG 402 / 10-6 |
| Sunum | 15 Mayıs 2026, Pamukkale Teknokent |

---

## 📄 Lisans

© 2026 Bahattin BÖBER — Tüm hakları saklıdır.  
Ticari kullanım için iletişime geçin: boberbahattin@gmail.com
