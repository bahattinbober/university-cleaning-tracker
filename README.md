# 🧹 Üniversite Personel Çalışma Takip Sistemi

> Pamukkale Üniversitesi - Bilgisayar Mühendisliği Bitirme Tezi
> 2025-2026 Bahar Dönemi

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18.x-green.svg)](https://nodejs.org)
[![SQLite](https://img.shields.io/badge/SQLite-3-lightblue.svg)](https://sqlite.org)

## 📌 Proje Hakkında

Üniversite personeli çalışmalarını dijital ortamda takip eden,
performans ve envanter yönetimi için akademik literatür temelli
karar destek sistemi sunan mobil uygulama.

## 🎯 Akademik Yaklaşım

### Performans Yönetimi
- Balanced Scorecard (Kaplan & Norton, 1992)
- Goal-Setting Theory (Locke & Latham, 1990)
- SMART Goals (Doran, 1981)
- Behavioral Reinforcement (Skinner, 1953)

### Envanter Optimizasyonu
- EOQ Modeli (Harris, 1913; Wilson, 1934) - Q* = √(2DS/H)
- Reorder Point (Wilson, 1934)
- Safety Stock - SS = Z·σ·√L
- ABC Analizi (Pareto, 1906)
- Demand Forecasting (Brown, 1956)
- Toyota Production System (Ohno, 1988)

### Maliyet Yönetimi
- Activity-Based Costing (Kaplan & Cooper, 1988)

### Standartlar ve Görselleştirme
- ISO 9001:2015 Quality Management
- Tufte Information Visualization (1983)

## ✨ Özellikler

### 📊 KPI Modülü
- Balanced Scorecard 4 bileşen
- Harf notu (A+ to F) + 5 seviye
- Hedef sistemi (OKR)
- 7 günlük trend grafiği
- 8 başarı göstergesi
- Heuristik öneri motoru (DSS)
- A4 PDF kurumsal performans raporu
- KPI Metodoloji sayfası
- Z-Score istatistiksel benchmark

### 📦 Stok Modülü
- ABC Analizi (Pareto)
- Reorder Point (4 kademeli alert)
- Wilson EOQ optimum sipariş
- İstatistiksel Safety Stock
- Demand Forecasting (3-yöntem ensemble)
- Stok Metodoloji sayfası
- A4 PDF envanter raporu

### 💰 Bütçe / Maliyet Modülü
- Birim maliyet yönetimi
- 6 aylık trend
- Kategori dağılımı (pie chart)
- Top 10 maliyetli kalem

### 📈 Analiz ve Görselleştirme
- Ana Dashboard
- Heatmap (gün × saat yoğunluk)
- Karşılaştırmalı Analiz (PoP)

## 🛠️ Teknoloji Stack

### Frontend
- Flutter 3.x (Dart)
- fl_chart, http, shared_preferences
- pdf, printing, mobile_scanner, image_picker

### Backend
- Node.js 18.x + Express.js
- SQLite 3 (sqlite3)
- bcryptjs, jsonwebtoken
- express-rate-limit, multer

## 📐 Sistem Mimarisi

3-katmanlı (3-tier) istemci-sunucu mimarisi:

- **Sunum Katmanı**: Flutter Mobile (Dart)
- **İş Mantığı Katmanı**: Node.js + Express
- **Veri Katmanı**: SQLite 3

İletişim: HTTPS/REST + JWT Authentication

Detaylı diyagramlar:
- [📐 Sistem Mimarisi](docs/architecture.html)
- [💾 ERD - Veritabanı Şeması](docs/erd.html)

## 🚀 Kurulum

### Önkoşullar
- Node.js 18+
- Flutter 3.x

### Backend
```bash
cd backend/backend
npm install
npm run dev
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

### Test Verileri
```bash
cd backend/backend
node fix_and_seed.js
node add_inventory_usage.js
```

### Demo Hesaplar
- Admin: admin@example.com
- Personel: test.personel@pau.edu.tr

## 📊 Proje İstatistikleri

- 48+ commit
- ~8,700 satır kod
- 23 akademik özellik
- 12 akademik dayanak
- 21 entegrasyon testi
- 0 lint hatası

## 🎓 Akademik Bilgiler

- **Üniversite**: Pamukkale Üniversitesi
- **Bölüm**: Bilgisayar Mühendisliği
- **Öğrenci**: Bahattin BOBER
- **Dönem**: 2025-2026 Bahar
- **Sunum**: 15 Mayıs 2026

## 📄 Lisans

Bu proje akademik amaçla geliştirilmiştir.
