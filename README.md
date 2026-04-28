<div align="center">

# 🧹 Temizlik Takip Sistemi

### Cleaning Management System for University Personnel

Pamukkale Üniversitesi kampüs temizlik personelinin günlük temizlik görevlerini kayıt altına aldığı, yöneticilerin haftalık performans verilerini takip edebildiği fullstack mobil uygulamadır.

[![Tests](https://img.shields.io/badge/tests-21%20passing-success)]()
[![Backend](https://img.shields.io/badge/backend-Node.js%2022-339933?logo=node.js&logoColor=white)]()
[![Frontend](https://img.shields.io/badge/frontend-Flutter%203.10-02569B?logo=flutter&logoColor=white)]()
[![Database](https://img.shields.io/badge/database-SQLite-003B57?logo=sqlite&logoColor=white)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

</div>

---

## 📱 Demo

<table>
  <tr>
    <td align="center"><b>Giriş</b></td>
    <td align="center"><b>Yönetim Paneli</b></td>
    <td align="center"><b>Personel Paneli</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/login.png" width="240"/></td>
    <td><img src="docs/screenshots/home-top.png" width="240"/></td>
    <td><img src="docs/screenshots/home-bottom.png" width="240"/></td>
  </tr>
  <tr>
    <td align="center"><b>Haftalık KPI</b></td>
    <td align="center"><b>Planlı Görev</b></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/kpi.png" width="240"/></td>
    <td><img src="docs/screenshots/scheduled-task.png" width="240"/></td>
    <td></td>
  </tr>
</table>

---

## 🎯 Vizyon

Üniversite kampüslerinde temizlik personeli takibi genellikle kâğıt çizelgelerle veya WhatsApp grupları üzerinden yapılır — şeffaf değildir, ölçülemez, adil değildir. Bu proje, **QR kod ile lokasyon doğrulamalı temizlik kaydı** ve **haftalık KPI skorlamasıyla** bu süreci dijitalleştirir.

---

## ✨ Özellikler

### Personel İçin

- 📷 QR kod ile temizlik kaydı (not + fotoğraf opsiyonel)
- 📋 Planlı görev takibi
- 📊 Geçmiş kayıtları gözden geçir

### Yönetici İçin

- ✅ Kullanıcı onay sistemi
- 📅 Görev planlama (oda + personel + tarih/saat)
- 🏆 Haftalık KPI sıralaması (madalya pozisyonlu)
- 👥 Personel detay incelemesi

### Sistem

- 🔐 JWT authentication (8 saat)
- 🛡️ Role-based access control
- 🌐 @pau.edu.tr domain kısıtı
- 🔒 bcrypt şifreleme (NIST uyumlu)
- 🇹🇷 Tam Türkçe arayüz

---

## 📐 KPI Formülü
