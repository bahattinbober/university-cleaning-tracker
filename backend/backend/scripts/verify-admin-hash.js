require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcrypt');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');
const db = new sqlite3.Database(dbPath);

const envPassword = process.env.ADMIN_DEFAULT_PASSWORD;
const adminEmail  = process.env.ADMIN_DEFAULT_EMAIL || 'admin@example.com';

console.log('Env şifre uzunluğu    :', envPassword?.length ?? '(ADMIN_DEFAULT_PASSWORD eksik)');

db.get(`SELECT password_hash FROM users WHERE email = ?`, [adminEmail], async (err, row) => {
  if (err) {
    console.error('❌ DB sorgu hatası:', err.message);
    return db.close();
  }

  if (!row) {
    console.log(`ℹ️  DB'de ${adminEmail} bulunamadı — önce sunucuyu başlatıp seed'in çalışmasını bekle.`);
    return db.close();
  }

  console.log('DB hash ilk 30 karakter:', row.password_hash?.substring(0, 30));

  if (!envPassword) {
    console.error('❌ ADMIN_DEFAULT_PASSWORD .env\'de tanımlı değil, karşılaştırma yapılamıyor.');
    return db.close();
  }

  const match = await bcrypt.compare(envPassword, row.password_hash);
  console.log('Bcrypt match (env vs DB):', match);

  db.close();
});
