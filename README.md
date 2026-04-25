# Temizlik Takip Sistemi
### *Cleaning Management System — Mobile & REST API*

Pamukkale Üniversitesi kampüs temizlik personelinin günlük temizlik görevlerini kayıt altına aldığı, yöneticilerin haftalık performans verilerini takip edebildiği fullstack bir mobil uygulamadır. Personel QR kod okuyarak temizlik logu oluşturur; yöneticiler görev atar, kullanıcı onaylar ve KPI skorlarını izler.

---

## Tech Stack

![Node.js](https://img.shields.io/badge/Node.js-22.x-339933?logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express-5.x-000000?logo=express&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-8h_token-000000?logo=jsonwebtokens&logoColor=white)
![bcrypt](https://img.shields.io/badge/bcrypt-10_round-FF6B6B)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)

---

## Özellikler

- **QR kod ile temizlik logu** — Personel odanın QR kodunu okutarak anında log oluşturur; opsiyonel not ve fotoğraf ekleyebilir.
- **Haftalık KPI skoru** — Her personel için otomatik hesaplanan performans puanı:
  ```
  skor = (toplam_görev × 5) + (tamamlanan × 3) + (notlu × 1) + (fotoğraflı × 2) + (zamanında × 4) − (geç × 2)
  ```
- **Admin onay tabanlı kayıt** — Yeni hesaplar `pending` durumunda oluşur; admin onaylamadan giriş yapılamaz.
- **Role-based access control** — `admin` ve `staff` rolleri; admin endpoint'leri middleware katmanında korunur.
- **Domain kısıtlı kayıt** — Yalnızca `@pau.edu.tr` uzantılı e-postalar kabul edilir.
- **JWT authentication** — 8 saatlik token, her istekte `Authorization: Bearer` header'ı ile iletilir.
- **Fotoğraf kanıtı** — Temizlik loguna base64 kodlanmış fotoğraf eklenebilir.
- **Zamanlanmış görev sistemi** — Admin belirli oda ve personel için görev atar; temizlik logu oluşturulduğunda en yakın bekleyen görev otomatik tamamlanır.

---

## Mimari

```
┌─────────────────────┐        HTTP/REST        ┌──────────────────────┐
│   Flutter Mobil App │ ──────────────────────▶ │  Express.js API      │
│                     │                         │  Node.js : 4000      │
│  SharedPreferences  │ ◀────────────────────── │                      │
│  (JWT token)        │      JSON response       │  authMiddleware.js   │
└─────────────────────┘                         └──────────┬───────────┘
                                                           │
                                                           ▼
                                                ┌──────────────────────┐
                                                │  SQLite              │
                                                │  temizlik_sistemi    │
                                                │  .sqlite             │
                                                │                      │
                                                │  users               │
                                                │  rooms               │
                                                │  cleaning_logs       │
                                                │  scheduled_tasks     │
                                                └──────────────────────┘
```

---

## Kurulum

### Gereksinimler

- Node.js 18+
- Flutter SDK 3.10+
- Android emülatör veya fiziksel cihaz

### Backend

```bash
cd backend/backend
npm install
cp .env.example .env   # değerleri doldur (bkz. .env Yapılandırması)
npm run dev            # sunucu http://localhost:4000 adresinde başlar
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run            # bağlı emülatör veya cihazda çalıştır
```

> **Not:** Flutter uygulaması API'ye `http://10.0.2.2:4000` üzerinden bağlanır (Android emülatör loopback IP'si). Fiziksel cihaz veya production kullanımında bu adresi her ekrandaki API çağrısında güncellemeniz gerekir.

---

## .env Yapılandırması

`backend/backend/.env.example` dosyasını `.env` olarak kopyalayıp aşağıdaki değerleri doldurun:

```env
PORT=4000
JWT_SECRET="buraya_en_az_64_karakterlik_rastgele_string"
ADMIN_DEFAULT_EMAIL="admin@example.com"
ADMIN_DEFAULT_PASSWORD="GucluSifre#2024!"
ALLOWED_ORIGINS="http://10.0.2.2:4000,http://localhost:4000"
```

> ⚠️ **Özel karakter uyarısı:** `#`, `$` gibi karakter içeren değerleri **mutlaka çift tırnak içine alın.**
> `dotenv` tırnaksız değerlerde `#` karakterini yorum başlangıcı olarak yorumlar ve değeri sessizce keser.
> Güçlü şifre üretmek için: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`

`ADMIN_DEFAULT_EMAIL` ve `ADMIN_DEFAULT_PASSWORD` tanımlıysa sunucu ilk açılışta otomatik admin hesabı oluşturur. İkisi de boş bırakılırsa seed atlanır.

---

## Güvenlik

Bu proje [12-Factor App](https://12factor.net/) prensiplerine uygun geliştirilmiştir:

| Katman | Uygulama |
|---|---|
| Secret yönetimi | Tüm gizli değerler `.env` dosyasında, kaynak kodda hardcoded değer yok |
| Authentication | JWT, 8 saatlik geçerlilik süresi |
| Şifre saklama | bcrypt, 10 round |
| API erişim kontrolü | CORS whitelist (`ALLOWED_ORIGINS` env değişkeni) |
| Yetkilendirme | Admin endpoint'leri `ensureAdmin` middleware ile korunur |
| Kayıt kısıtı | Yalnızca `@pau.edu.tr` domain'i kabul edilir, yeni hesaplar admin onayı bekler |

---

## API Endpoint'leri

| Method | Path | Auth | Açıklama |
|---|---|---|---|
| `POST` | `/api/auth/register` | Yok | Yeni kullanıcı kaydı (onay beklenir) |
| `POST` | `/api/auth/login` | Yok | Giriş, JWT token döner |
| `GET` | `/api/health` | Yok | Sunucu sağlık kontrolü |
| `GET` | `/api/users` | Admin | Tüm kullanıcıları listele |
| `GET` | `/api/rooms` | Token | Oda listesi |
| `POST` | `/api/rooms` | Admin | Yeni oda ekle |
| `POST` | `/api/cleaning` | Token | Temizlik logu oluştur |
| `GET` | `/api/cleaning/my` | Token | Kendi temizlik loglarım |
| `GET` | `/api/tasks/my-scheduled` | Token | Bana atanan bekleyen görevler |
| `GET` | `/api/admin/pending-users` | Admin | Onay bekleyen kullanıcılar |
| `PUT` | `/api/admin/approve-user/:id` | Admin | Kullanıcı onayla |
| `PUT` | `/api/admin/reject-user/:id` | Admin | Kullanıcı reddet |
| `GET` | `/api/admin/scheduled-tasks` | Admin | Tüm zamanlanmış görevler |
| `POST` | `/api/admin/scheduled-tasks` | Admin | Yeni görev oluştur |
| `GET` | `/api/admin/weekly-kpi` | Admin | Haftalık KPI skor tablosu |
| `GET` | `/api/admin/user-logs/:userId` | Admin | Belirli kullanıcının logları |

---

## Akademik Bilgi

Bu proje **Pamukkale Üniversitesi Bilgisayar Mühendisliği** bölümü bitirme tezi kapsamında geliştirilmektedir.

**Yazar:** Bahattin Bober

---

## Karşılaşılan İlginç Buglar

### `dotenv` ve `#` Karakteri Sorunu

Production hazırlığı sırasında ilginç bir `dotenv` davranışı keşfedildi: kütüphane, tırnak içine alınmamış değerlerde `#` karakterini satır sonu yorum başlangıcı olarak yorumluyor.

```env
# Sorunlu hal — dotenv Y5%QNA4Ga'dan sonrasını siliyor:
ADMIN_DEFAULT_PASSWORD=Y5%QNA4Ga#Jkx@Gu

# Doğru hal — tırnak içinde özel karakterler sorunsuz çalışır:
ADMIN_DEFAULT_PASSWORD="Y5%QNA4Ga#Jkx@Gu"
```

Sorun `bcrypt.compare` eşleşmemesiyle kendini gösterdi: `process.env.ADMIN_DEFAULT_PASSWORD` değerinin uzunluğu 16 yerine 9 çıkıyordu. Özel bir `verify-admin-hash.js` scripti yazılarak `Env şifre uzunluğu: 9` çıktısıyla teşhis edildi; tırnak eklendikten sonra uzunluk 16'ya döndü ve `Bcrypt match: true` elde edildi.

**Çıkarılan ders:** `.env` dosyalarında `#`, `$`, `!` gibi özel karakter içeren tüm değerleri çift tırnak içine alın.

---

## Lisans

[MIT](LICENSE)
