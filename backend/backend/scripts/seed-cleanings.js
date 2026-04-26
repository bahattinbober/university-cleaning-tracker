const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');
const db = new sqlite3.Database(dbPath);

const ROOM_NAME = 'K339';

const records = [
  { user_id: 4, cleaned_at: '2026-04-25 09:30:00', notes: null,                        image: null            },
  { user_id: 4, cleaned_at: '2026-04-24 14:15:00', notes: 'Toz aldım',                 image: null            },
  { user_id: 5, cleaned_at: '2026-04-23 10:00:00', notes: null,                        image: null            },
  { user_id: 5, cleaned_at: '2026-04-22 11:30:00', notes: 'Tahta silindi',              image: 'dummy_photo_1' },
  { user_id: 6, cleaned_at: '2026-04-21 08:45:00', notes: null,                        image: null            },
  { user_id: 6, cleaned_at: '2026-04-20 13:20:00', notes: 'Toplantı sonrası temizlik', image: 'dummy_photo_2' },
  { user_id: 4, cleaned_at: '2026-04-19 09:00:00', notes: null,                        image: null            },
];

// Bir kaydın zaten var olup olmadığını kontrol et (user_id + room_id + cleaned_at üçlüsü)
function exists(roomId, rec) {
  return new Promise((resolve, reject) => {
    db.get(
      `SELECT id FROM cleaning_logs WHERE user_id=? AND room_id=? AND cleaned_at=?`,
      [rec.user_id, roomId, rec.cleaned_at],
      (err, row) => (err ? reject(err) : resolve(!!row))
    );
  });
}

function insert(roomId, rec) {
  return new Promise((resolve, reject) => {
    db.run(
      `INSERT INTO cleaning_logs (user_id, room_id, cleaned_at, status, notes, image)
       VALUES (?, ?, ?, 'completed', ?, ?)`,
      [rec.user_id, roomId, rec.cleaned_at, rec.notes, rec.image],
      function (err) {
        if (err) reject(err);
        else resolve(this.lastID);
      }
    );
  });
}

async function seed() {
  // K339 oda id'sini bul
  const room = await new Promise((resolve, reject) =>
    db.get(`SELECT id FROM rooms WHERE name = ?`, [ROOM_NAME], (err, row) =>
      err ? reject(err) : resolve(row)
    )
  );

  if (!room) {
    console.error(`"${ROOM_NAME}" odası bulunamadı. Script durduruluyor.`);
    db.close();
    return;
  }

  const roomId = room.id;
  console.log(`"${ROOM_NAME}" odası bulundu → room_id=${roomId}\n`);

  let inserted = 0;
  let skipped = 0;

  for (const rec of records) {
    if (await exists(roomId, rec)) {
      console.log(`  ⏭  Zaten var → user_id=${rec.user_id}, cleaned_at=${rec.cleaned_at}`);
      skipped++;
    } else {
      const newId = await insert(roomId, rec);
      console.log(`  ✅ Eklendi  → id=${newId}, user_id=${rec.user_id}, cleaned_at=${rec.cleaned_at}, notes=${rec.notes ?? 'null'}`);
      inserted++;
    }
  }

  console.log(`\nToplam ${inserted} kayıt eklendi, ${skipped} kayıt atlandı (zaten mevcut).`);
  db.close();
}

seed().catch((err) => {
  console.error('Hata:', err.message);
  db.close();
});
