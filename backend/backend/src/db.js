const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const bcrypt = require('bcrypt');

// Veritabanı dosyasının yolu (backend klasöründe oluşacak)
const dbPath = path.join(__dirname, '..', 'temizlik_sistemi.sqlite');

// Veritabanına bağlan
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('❌ SQLite bağlantı hatası:', err.message);
  } else {
    console.log('✅ SQLite veritabanına bağlanıldı:', dbPath);
  }
});

// Tabloları oluştur ve varsayılan admin ekle
db.serialize(() => {
  // USERS TABLOSU
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT UNIQUE,
      password_hash TEXT,
      role TEXT,
      employee_no TEXT,
      department TEXT,
      approval_status TEXT
    )
  `);

  // Eski veritabanları için users tablosuna yeni alanları güvenli şekilde ekle
  db.all(`PRAGMA table_info(users)`, [], (tableErr, columns) => {
    if (tableErr) {
      console.error('❌ users şema kontrol hatası:', tableErr.message);
      return;
    }

    const hasEmployeeNo = columns.some((column) => column.name === 'employee_no');
    const hasDepartment = columns.some((column) => column.name === 'department');
    const hasApprovalStatus = columns.some(
      (column) => column.name === 'approval_status'
    );

    if (!hasEmployeeNo) {
      db.run(`ALTER TABLE users ADD COLUMN employee_no TEXT`, (alterErr) => {
        if (alterErr) {
          console.error('❌ users employee_no alanı ekleme hatası:', alterErr.message);
        } else {
          console.log('✅ users tablosuna employee_no alanı eklendi');
        }
      });
    }

    if (!hasDepartment) {
      db.run(`ALTER TABLE users ADD COLUMN department TEXT`, (alterErr) => {
        if (alterErr) {
          console.error('❌ users department alanı ekleme hatası:', alterErr.message);
        } else {
          console.log('✅ users tablosuna department alanı eklendi');
        }
      });
    }

    if (!hasApprovalStatus) {
      db.run(`ALTER TABLE users ADD COLUMN approval_status TEXT`, (alterErr) => {
        if (alterErr) {
          console.error(
            '❌ users approval_status alanı ekleme hatası:',
            alterErr.message
          );
        } else {
          console.log('✅ users tablosuna approval_status alanı eklendi');
          // Mevcut kullanıcıları kilitlememek için eski kayıtları approved yap
          db.run(
            `UPDATE users SET approval_status = 'approved' WHERE approval_status IS NULL`
          );
        }
      });
    }
  });

  // LOCATIONS TABLOSU
  db.run(`
    CREATE TABLE IF NOT EXISTS locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      description TEXT
    )
  `);

  // ROOMS TABLOSU
  db.run(`
    CREATE TABLE IF NOT EXISTS rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location_id INTEGER,
      name TEXT,
      description TEXT,
      FOREIGN KEY (location_id) REFERENCES locations(id)
    )
  `);

  // CLEANING LOGS TABLOSU
  db.run(`
    CREATE TABLE IF NOT EXISTS cleaning_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      room_id INTEGER,
      cleaned_at TEXT DEFAULT (datetime('now')),
      status TEXT,
      notes TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (room_id) REFERENCES rooms(id)
    )
  `);

  // SCHEDULED TASKS TABLOSU
  db.run(`
    CREATE TABLE IF NOT EXISTS scheduled_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      scheduled_for TEXT NOT NULL,
      assigned_user_id INTEGER,
      status TEXT DEFAULT 'pending',
      completed_log_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (room_id) REFERENCES rooms(id),
      FOREIGN KEY (assigned_user_id) REFERENCES users(id),
      FOREIGN KEY (completed_log_id) REFERENCES cleaning_logs(id)
    )
  `);

  // Eski veritabanları için scheduled_tasks alanlarını güvenli şekilde ekle
  db.all(`PRAGMA table_info(scheduled_tasks)`, [], (tableErr, columns) => {
    if (tableErr) {
      console.error('❌ scheduled_tasks şema kontrol hatası:', tableErr.message);
      return;
    }

    const hasStatus = columns.some((column) => column.name === 'status');
    const hasCompletedLogId = columns.some(
      (column) => column.name === 'completed_log_id'
    );
    const hasCreatedAt = columns.some((column) => column.name === 'created_at');

    if (!hasStatus) {
      db.run(
        `ALTER TABLE scheduled_tasks ADD COLUMN status TEXT DEFAULT 'pending'`,
        (alterErr) => {
          if (alterErr) {
            console.error(
              '❌ scheduled_tasks status alanı ekleme hatası:',
              alterErr.message
            );
          }
        }
      );
    }

    if (!hasCompletedLogId) {
      db.run(
        `ALTER TABLE scheduled_tasks ADD COLUMN completed_log_id INTEGER`,
        (alterErr) => {
          if (alterErr) {
            console.error(
              '❌ scheduled_tasks completed_log_id alanı ekleme hatası:',
              alterErr.message
            );
          }
        }
      );
    }

    if (!hasCreatedAt) {
      db.run(
        `ALTER TABLE scheduled_tasks ADD COLUMN created_at TEXT DEFAULT (datetime('now'))`,
        (alterErr) => {
          if (alterErr) {
            console.error(
              '❌ scheduled_tasks created_at alanı ekleme hatası:',
              alterErr.message
            );
          }
        }
      );
    }
  });

  // Eski veritabanları için image alanını güvenli şekilde ekle
  db.all(`PRAGMA table_info(cleaning_logs)`, [], (tableErr, columns) => {
    if (tableErr) {
      console.error('❌ cleaning_logs şema kontrol hatası:', tableErr.message);
      return;
    }

    const hasImageColumn = columns.some((column) => column.name === 'image');
    if (!hasImageColumn) {
      db.run(`ALTER TABLE cleaning_logs ADD COLUMN image TEXT`, (alterErr) => {
        if (alterErr) {
          console.error('❌ cleaning_logs image alanı ekleme hatası:', alterErr.message);
        } else {
          console.log('✅ cleaning_logs tablosuna image alanı eklendi');
        }
      });
    }
  });

  console.log(
    '✅ Tablolar oluşturuldu (users, locations, rooms, cleaning_logs, scheduled_tasks)'
  );

  // Varsayılan admin seed — yalnızca env'de her iki değişken de varsa çalışır
  const seedEmail = process.env.ADMIN_DEFAULT_EMAIL;
  const seedPassword = process.env.ADMIN_DEFAULT_PASSWORD;

  if (!seedEmail || !seedPassword) {
    console.warn(
      '⚠️  ADMIN_DEFAULT_EMAIL veya ADMIN_DEFAULT_PASSWORD eksik — otomatik admin seed atlandı.'
    );
  } else {
    db.get(`SELECT * FROM users WHERE email = ?`, [seedEmail], async (err, row) => {
      if (err) {
        console.error('❌ Admin kontrol hatası:', err.message);
        return;
      }

      if (!row) {
        const hash = await bcrypt.hash(seedPassword, 10);

        db.run(
          `INSERT INTO users (name, email, password_hash, role, employee_no, department, approval_status)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          ['Admin', seedEmail, hash, 'admin', 'ADM-001', 'Yönetim', 'approved'],
          (err2) => {
            if (err2) {
              console.error('❌ Admin ekleme hatası:', err2.message);
            } else {
              console.log(`👤 Varsayılan admin oluşturuldu: ${seedEmail}`);
            }
          }
        );
      } else if (!row.approval_status) {
        db.run(`UPDATE users SET approval_status = 'approved' WHERE id = ?`, [row.id]);
      }
    });
  }
});

module.exports = db;
