const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');
const db = new sqlite3.Database(dbPath);

// Keep admin (id=9) and all @pau.edu.tr users; delete everything else
db.all(
  `SELECT id, email, role FROM users WHERE id != 9 AND email NOT LIKE '%@pau.edu.tr'`,
  [],
  (err, rows) => {
    if (err) {
      console.error('Sorgu hatası:', err.message);
      db.close();
      return;
    }

    if (rows.length === 0) {
      console.log('Silinecek kullanıcı yok.');
      db.close();
      return;
    }

    console.log(`Silinecek ${rows.length} kullanıcı:`);
    rows.forEach((r) => console.log(`  id=${r.id}  ${r.email}  (${r.role})`));

    const ids = rows.map((r) => r.id);
    const placeholders = ids.map(() => '?').join(',');

    db.run(`DELETE FROM users WHERE id IN (${placeholders})`, ids, function (delErr) {
      if (delErr) {
        console.error('Silme hatası:', delErr.message);
      } else {
        console.log(`\n${this.changes} kullanıcı silindi.`);
      }
      db.close((closeErr) => {
        if (closeErr) console.error('DB kapatma hatası:', closeErr.message);
      });
    });
  }
);
