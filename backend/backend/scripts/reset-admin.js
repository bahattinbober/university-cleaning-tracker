const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');
const db = new sqlite3.Database(dbPath);

db.all(`SELECT id, email FROM users WHERE role = 'admin'`, [], (err, rows) => {
  if (err) {
    console.error('❌ Sorgu hatası:', err.message);
    return db.close();
  }

  if (rows.length === 0) {
    console.log('ℹ️  Silinecek admin kullanıcısı bulunamadı.');
    return db.close();
  }

  let pending = rows.length;

  rows.forEach((row) => {
    db.run(`DELETE FROM users WHERE id = ?`, [row.id], function (delErr) {
      if (delErr) {
        console.error(`❌ id=${row.id} email=${row.email} silinirken hata:`, delErr.message);
      } else {
        console.log(`✅ id=${row.id} email=${row.email} silindi`);
      }

      pending -= 1;
      if (pending === 0) {
        db.close((closeErr) => {
          if (closeErr) console.error('❌ DB kapatma hatası:', closeErr.message);
        });
      }
    });
  });
});
