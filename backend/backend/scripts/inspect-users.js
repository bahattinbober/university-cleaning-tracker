const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');
const db = new sqlite3.Database(dbPath);

db.all(`SELECT id, email, role, password_hash, approval_status FROM users`, [], (err, rows) => {
  if (err) {
    console.error('❌ Sorgu hatası:', err.message);
  } else {
    rows.forEach((row) => {
      console.log({
        id: row.id,
        email: row.email,
        role: row.role,
        approval_status: row.approval_status,
        password_hash: (row.password_hash || '').slice(0, 25) + '...',
      });
    });
    console.log(`\nToplam kayıt: ${rows.length}`);
  }

  db.close((closeErr) => {
    if (closeErr) console.error('❌ DB kapatma hatası:', closeErr.message);
  });
});
