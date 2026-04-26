<div align="center">

# Temizlik Takip Sistemi

### Cleaning Management System for University Personnel

Pamukkale Universitesi kampus temizlik personelinin gunluk temizlik gorevlerini kayit altina aldigi, yoneticilerin haftalik performans verilerini takip edebildigi fullstack mobil uygulamadir.

</div>

---

## Demo

<table>
  <tr>
    <td><img src="docs/screenshots/login.png" width="240"/></td>
    <td><img src="docs/screenshots/home-top.png" width="240"/></td>
    <td><img src="docs/screenshots/home-bottom.png" width="240"/></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/kpi.png" width="240"/></td>
    <td><img src="docs/screenshots/scheduled-task.png" width="240"/></td>
    <td></td>
  </tr>
</table>

---

## Vizyon

Universite kampuslerinde temizlik personeli takibi genellikle kagit cizelgelerle veya WhatsApp gruplari uzerinden yapilir. Bu proje QR kod ile lokasyon dogrulamali temizlik kaydi ve haftalik KPI skorlamasiyla bu sureci dijitallestirir.

---

## Ozellikler

- QR kod ile temizlik kaydi
- Haftalik KPI skoru ve madalya siralamasi
- Admin onay tabanli kayit sistemi
- Role-based access control (admin / staff)
- @pau.edu.tr domain kisitli kayit
- JWT authentication 8 saatlik token
- bcrypt sifre sakla 10 round
- Tam Turkce arayuz

---

## KPI Formulu

skor = (toplam_gorev x 5) + (tamamlanan x 3) + (notlu x 1) + (fotografli x 2) + (zamaninda x 4) - (gec x 2)

Literatur referansi: Balanced Scorecard (Kaplan and Norton, 1996)

---

## Kurulum

Backend:
cd backend/backend
npm install
npm run dev

Frontend:
cd frontend
flutter pub get
flutter run

Test:
cd backend/backend
npm test

---

## Test

21 integration testi, 4 test suite, ortalama 3 saniye

---

## Akademik

Yazar: Bahattin Bober
Universite: Pamukkale Universitesi
Yil: 2026
