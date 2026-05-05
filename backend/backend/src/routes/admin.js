const express = require('express');
const db = require('../db');
const XLSX = require('xlsx');

const router = express.Router();

function ensureAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok (admin değil)' });
  }
  next();
}

// GET /api/admin/pending-users -> onay bekleyen kullanıcılar
router.get('/pending-users', ensureAdmin, (req, res) => {
  const sql = `
    SELECT id, name, email, employee_no, department, role, approval_status
    FROM users
    WHERE approval_status = 'pending'
    ORDER BY id DESC
  `;

  db.all(sql, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ message: 'Sunucu hatası' });
    }
    return res.json(rows);
  });
});

// PUT /api/admin/approve-user/:id -> kullanıcı onayla
router.put('/approve-user/:id', ensureAdmin, (req, res) => {
  const userId = Number(req.params.id);
  if (!userId) {
    return res.status(400).json({ message: 'Geçersiz kullanıcı id' });
  }

  db.run(
    `UPDATE users SET approval_status = 'approved' WHERE id = ?`,
    [userId],
    function (err) {
      if (err) return res.status(500).json({ message: 'Sunucu hatası' });
      if (this.changes === 0) {
        return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
      }
      return res.json({ message: 'Kullanıcı onaylandı' });
    }
  );
});

// PUT /api/admin/reject-user/:id -> kullanıcı reddet
router.put('/reject-user/:id', ensureAdmin, (req, res) => {
  const userId = Number(req.params.id);
  if (!userId) {
    return res.status(400).json({ message: 'Geçersiz kullanıcı id' });
  }

  db.run(
    `UPDATE users SET approval_status = 'rejected' WHERE id = ?`,
    [userId],
    function (err) {
      if (err) return res.status(500).json({ message: 'Sunucu hatası' });
      if (this.changes === 0) {
        return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
      }
      return res.json({ message: 'Kullanıcı reddedildi' });
    }
  );
});

// POST /api/admin/scheduled-tasks -> planlı görev oluştur
router.post('/scheduled-tasks', ensureAdmin, (req, res) => {
  const { room_id, title, description, scheduled_for, assigned_user_id } = req.body;

  if (!room_id || !title || !scheduled_for) {
    return res.status(400).json({ message: 'room_id, title ve scheduled_for zorunlu' });
  }

  db.run(
    `INSERT INTO scheduled_tasks (room_id, title, description, scheduled_for, assigned_user_id, status)
     VALUES (?, ?, ?, ?, ?, 'pending')`,
    [
      room_id,
      String(title).trim(),
      description ? String(description).trim() : null,
      scheduled_for,
      assigned_user_id || null,
    ],
    function (err) {
      if (err) return res.status(500).json({ message: 'Sunucu hatası' });
      return res.status(201).json({
        id: this.lastID,
        room_id,
        title: String(title).trim(),
        description: description ? String(description).trim() : null,
        scheduled_for,
        assigned_user_id: assigned_user_id || null,
        status: 'pending',
      });
    }
  );
});

// GET /api/admin/scheduled-tasks -> planlı görevleri listele
router.get('/scheduled-tasks', ensureAdmin, (req, res) => {
  const sql = `
    SELECT
      st.id,
      st.room_id,
      st.title,
      st.description,
      st.scheduled_for,
      st.assigned_user_id,
      st.status,
      st.completed_log_id,
      st.created_at,
      r.name AS room_name,
      u.name AS assigned_user_name
    FROM scheduled_tasks st
    LEFT JOIN rooms r ON r.id = st.room_id
    LEFT JOIN users u ON u.id = st.assigned_user_id
    ORDER BY datetime(st.scheduled_for) ASC
  `;

  db.all(sql, [], (err, rows) => {
    if (err) return res.status(500).json({ message: 'Sunucu hatası' });
    return res.json(rows);
  });
});

// GET /api/admin/weekly-kpi -> son 7 güne göre çalışan karşılaştırması
router.get('/weekly-kpi', ensureAdmin, (req, res) => {
  // Skor formülü merkezi olarak burada hesaplanır:
  // score = (total_tasks * 5) + (completed_tasks * 3) + (noted_tasks * 1) + (photo_tasks * 2) + (on_time_tasks * 4) - (late_tasks * 2)
  const sql = `
    SELECT
      u.id AS user_id,
      u.name,
      u.email,
      COUNT(cl.id) AS total_tasks,
      SUM(CASE WHEN cl.status = 'completed' THEN 1 ELSE 0 END) AS completed_tasks,
      SUM(
        CASE
          WHEN cl.notes IS NOT NULL AND TRIM(cl.notes) <> '' THEN 1
          ELSE 0
        END
      ) AS noted_tasks,
      SUM(
        CASE
          WHEN cl.image IS NOT NULL AND TRIM(cl.image) <> '' THEN 1
          ELSE 0
        END
      ) AS photo_tasks,
      SUM(
        CASE
          WHEN st.id IS NOT NULL
               AND datetime(cl.cleaned_at) <= datetime(st.scheduled_for) THEN 1
          ELSE 0
        END
      ) AS on_time_tasks,
      SUM(
        CASE
          WHEN st.id IS NOT NULL
               AND datetime(cl.cleaned_at) > datetime(st.scheduled_for) THEN 1
          ELSE 0
        END
      ) AS late_tasks
    FROM cleaning_logs cl
    INNER JOIN users u ON u.id = cl.user_id
    LEFT JOIN scheduled_tasks st ON st.completed_log_id = cl.id
    WHERE datetime(cl.cleaned_at) >= datetime('now', '-7 day')
    GROUP BY u.id, u.name, u.email
  `;

  db.all(sql, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ message: 'Sunucu hatası' });
    }

    const result = rows
      .map((row) => {
        const totalTasks = Number(row.total_tasks || 0);
        const completedTasks = Number(row.completed_tasks || 0);
        const notedTasks = Number(row.noted_tasks || 0);
        const photoTasks = Number(row.photo_tasks || 0);
        const onTimeTasks = Number(row.on_time_tasks || 0);
        const lateTasks = Number(row.late_tasks || 0);

        return {
          user_id: row.user_id,
          name: row.name,
          email: row.email,
          total_tasks: totalTasks,
          completed_tasks: completedTasks,
          noted_tasks: notedTasks,
          photo_tasks: photoTasks,
          on_time_tasks: onTimeTasks,
          late_tasks: lateTasks,
          score:
            totalTasks * 5 +
            completedTasks * 3 +
            notedTasks * 1 +
            photoTasks * 2 +
            onTimeTasks * 4 -
            lateTasks * 2,
        };
      })
      .sort((a, b) => b.score - a.score);

    return res.json(result);
  });
});

// GET /api/admin/user-logs/:userId -> admin, seçili kullanıcının temizlik kayıtları
router.get('/user-logs/:userId', ensureAdmin, (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ message: 'Geçersiz kullanıcı id' });
  }

  const sql = `
    SELECT
      cl.id,
      cl.room_id,
      r.name AS room_name,
      cl.cleaned_at,
      cl.notes,
      cl.image
    FROM cleaning_logs cl
    LEFT JOIN rooms r ON r.id = cl.room_id
    WHERE cl.user_id = ?
    ORDER BY datetime(cl.cleaned_at) DESC
  `;

  db.all(sql, [userId], (err, rows) => {
    if (err) {
      return res.status(500).json({ message: 'Sunucu hatası' });
    }
    return res.json({ logs: rows });
  });
});

// DELETE /api/admin/users/:id -> kullanıcıyı sil
router.delete('/users/:id', ensureAdmin, (req, res) => {
  const targetId = parseInt(req.params.id, 10);
  const adminId = req.user.id;

  if (isNaN(targetId)) {
    return res.status(400).json({ message: 'Geçersiz kullanıcı id' });
  }

  if (targetId === adminId) {
    return res.status(400).json({ message: 'Kendi hesabınızı silemezsiniz' });
  }

  db.get('SELECT id, role FROM users WHERE id = ?', [targetId], (err, row) => {
    if (err) return res.status(500).json({ message: 'DB hatası' });
    if (!row) return res.status(404).json({ message: 'Kullanıcı bulunamadı' });

    if (row.role === 'admin') {
      return res.status(403).json({ message: 'Diğer admini silemezsiniz' });
    }

    db.serialize(() => {
      db.run('DELETE FROM cleaning_logs WHERE user_id = ?', [targetId]);
      db.run('DELETE FROM scheduled_tasks WHERE assigned_user_id = ?', [targetId]);
      db.run('DELETE FROM users WHERE id = ?', [targetId], function (deleteErr) {
        if (deleteErr) return res.status(500).json({ message: 'Silme hatası' });
        if (this.changes === 0) {
          return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
        }
        return res.json({ message: 'Kullanıcı başarıyla silindi', deletedId: targetId });
      });
    });
  });
});

// GET /api/admin/export -> Excel raporu indir
router.get('/export', ensureAdmin, (req, res) => {
  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() - 7);
  const weekStartStr = weekStart.toISOString().split('T')[0];

  const dbQuery = (sql, params) =>
    new Promise((resolve, reject) =>
      db.all(sql, params, (err, rows) => (err ? reject(err) : resolve(rows)))
    );

  Promise.all([
    dbQuery(
      `SELECT u.name AS 'Personel',
              COUNT(*) AS 'Toplam Kayıt',
              SUM(CASE WHEN cl.notes IS NOT NULL AND cl.notes != '' THEN 1 ELSE 0 END) AS 'Notlu Kayıt',
              SUM(CASE WHEN cl.image IS NOT NULL AND cl.image != '' THEN 1 ELSE 0 END) AS 'Fotoğraflı Kayıt',
              (COUNT(*) * 5 +
               SUM(CASE WHEN cl.notes IS NOT NULL AND cl.notes != '' THEN 1 ELSE 0 END) * 1 +
               SUM(CASE WHEN cl.image IS NOT NULL AND cl.image != '' THEN 1 ELSE 0 END) * 2) AS 'Toplam Puan'
       FROM cleaning_logs cl
       JOIN users u ON cl.user_id = u.id
       WHERE DATE(cl.cleaned_at) >= ?
       GROUP BY u.id, u.name
       ORDER BY COUNT(*) DESC`,
      [weekStartStr]
    ),
    dbQuery(
      `SELECT u.name AS 'Personel',
              r.name AS 'Oda',
              cl.cleaned_at AS 'Tarih',
              CASE WHEN cl.notes IS NOT NULL AND cl.notes != '' THEN cl.notes ELSE '-' END AS 'Not',
              CASE WHEN cl.image IS NOT NULL AND cl.image != '' THEN 'Var' ELSE 'Yok' END AS 'Fotoğraf'
       FROM cleaning_logs cl
       LEFT JOIN users u ON cl.user_id = u.id
       LEFT JOIN rooms r ON cl.room_id = r.id
       ORDER BY cl.cleaned_at DESC`,
      []
    ),
    dbQuery(
      `SELECT name AS 'Ad Soyad',
              email AS 'E-posta',
              CASE WHEN role = 'admin' THEN 'Yönetici' ELSE 'Personel' END AS 'Rol',
              CASE WHEN approval_status = 'approved' THEN 'Onaylı'
                   WHEN approval_status = 'pending' THEN 'Beklemede'
                   ELSE 'Reddedildi' END AS 'Durum',
              employee_no AS 'Sicil No',
              department AS 'Departman'
       FROM users
       ORDER BY role DESC, name`,
      []
    ),
    dbQuery(
      `SELECT r.name AS 'Oda',
              r.description AS 'Açıklama',
              COUNT(cl.id) AS 'Toplam Temizlik',
              MAX(cl.cleaned_at) AS 'Son Temizlik'
       FROM rooms r
       LEFT JOIN cleaning_logs cl ON r.id = cl.room_id
       GROUP BY r.id, r.name, r.description
       ORDER BY COUNT(cl.id) DESC`,
      []
    ),
  ])
    .then(([kpiData, cleaningData, userData, roomStats]) => {
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(kpiData), 'Haftalık KPI');
      XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(cleaningData), 'Tüm Kayıtlar');
      XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(userData), 'Personel');
      XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(roomStats), 'Oda İstatistikleri');

      const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
      const today = new Date().toISOString().split('T')[0];

      res.setHeader(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      res.setHeader('Content-Disposition', `attachment; filename="temizlik_raporu_${today}.xlsx"`);
      res.send(buffer);
    })
    .catch((err) => {
      console.error('Export hatası:', err);
      res.status(500).json({ message: 'Excel oluşturulamadı: ' + err.message });
    });
});

// GET /api/admin/dashboard -> özet istatistikler
router.get('/dashboard', ensureAdmin, (req, res) => {
  const today = new Date().toISOString().split('T')[0];
  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() - 7);
  const weekStartStr = weekStart.toISOString().split('T')[0];

  const result = {};

  db.get(
    `SELECT COUNT(*) as count FROM cleaning_logs WHERE DATE(cleaned_at) = ?`,
    [today],
    (err, row) => {
      if (err) return res.status(500).json({ message: 'DB hatası' });
      result.today_count = row.count;

      db.get(
        `SELECT COUNT(*) as count FROM scheduled_tasks WHERE status = 'pending'`,
        [],
        (err, row) => {
          if (err) return res.status(500).json({ message: 'DB hatası' });
          result.pending_tasks = row.count;

          db.get(
            `SELECT COUNT(DISTINCT user_id) as count FROM cleaning_logs WHERE DATE(cleaned_at) >= ?`,
            [weekStartStr],
            (err, row) => {
              if (err) return res.status(500).json({ message: 'DB hatası' });
              result.active_personnel = row.count;

              db.get(
                `SELECT COUNT(*) as count FROM cleaning_logs WHERE DATE(cleaned_at) >= ?`,
                [weekStartStr],
                (err, row) => {
                  if (err) return res.status(500).json({ message: 'DB hatası' });
                  result.weekly_total = row.count;

                  db.all(
                    `SELECT r.name as room_name, COUNT(*) as count
                     FROM cleaning_logs cl
                     JOIN rooms r ON cl.room_id = r.id
                     WHERE DATE(cl.cleaned_at) >= ?
                     GROUP BY r.name
                     ORDER BY count DESC
                     LIMIT 5`,
                    [weekStartStr],
                    (err, rows) => {
                      if (err) return res.status(500).json({ message: 'DB hatası' });
                      result.room_distribution = rows;

                      db.all(
                        `SELECT DATE(cleaned_at) as day, COUNT(*) as count
                         FROM cleaning_logs
                         WHERE DATE(cleaned_at) >= ?
                         GROUP BY DATE(cleaned_at)
                         ORDER BY day ASC`,
                        [weekStartStr],
                        (err, rows) => {
                          if (err) return res.status(500).json({ message: 'DB hatası' });
                          result.weekly_trend = rows;

                          db.all(
                            `SELECT u.name, COUNT(*) as total,
                                    SUM(CASE WHEN cl.notes IS NOT NULL AND cl.notes != '' THEN 1 ELSE 0 END) as noted,
                                    SUM(CASE WHEN cl.image IS NOT NULL AND cl.image != '' THEN 1 ELSE 0 END) as photo
                             FROM cleaning_logs cl
                             JOIN users u ON cl.user_id = u.id
                             WHERE DATE(cl.cleaned_at) >= ?
                             GROUP BY u.id, u.name
                             ORDER BY total DESC
                             LIMIT 3`,
                            [weekStartStr],
                            (err, rows) => {
                              if (err) return res.status(500).json({ message: 'DB hatası' });
                              result.top_personnel = rows.map((r) => ({
                                name: r.name,
                                score: r.total * 5 + r.noted * 1 + r.photo * 2,
                              }));
                              return res.json(result);
                            }
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
});

// GET /api/admin/anomalies -> heuristik kural tabanlı anomali tespiti
router.get('/anomalies', ensureAdmin, async (req, res) => {
  try {
    const anomalies = [];

    const dbAll = (sql, params = []) =>
      new Promise((resolve, reject) =>
        db.all(sql, params, (err, rows) => (err ? reject(err) : resolve(rows)))
      );

    // KURAL 1: İNAKTİF PERSONEL — 3+ gündür kayıt yapmamış aktif personel
    const inactiveUsers = await dbAll(
      `SELECT u.id, u.name,
              MAX(cl.cleaned_at) as last_cleaning,
              CAST((julianday('now') - julianday(MAX(cl.cleaned_at))) AS INTEGER) as days_inactive
       FROM users u
       LEFT JOIN cleaning_logs cl ON u.id = cl.user_id
       WHERE u.role = 'staff' AND u.approval_status = 'approved'
       GROUP BY u.id, u.name
       HAVING days_inactive >= 3 OR last_cleaning IS NULL
       ORDER BY days_inactive ASC`
    );

    inactiveUsers.forEach((u) => {
      const days = u.days_inactive;
      anomalies.push({
        severity: days === null || days >= 7 ? 'high' : 'medium',
        icon: 'person_off',
        title: `${u.name} ${days === null ? 'hiç kayıt yapmadı' : `${days} gündür kayıt yapmadı`}`,
        description: u.last_cleaning
          ? `Son kayıt: ${u.last_cleaning}`
          : 'Sistemde hiç temizlik kaydı yok',
        type: 'inactive_user',
        data: { user_id: u.id },
      });
    });

    // KURAL 2: ŞÜPHELİ HIZLI KAYIT — aynı oda+kullanıcı, 1 saatte >3 kayıt
    const rapidLogs = await dbAll(
      `SELECT u.name as user_name, r.name as room_name, COUNT(*) as count
       FROM cleaning_logs cl
       JOIN users u ON cl.user_id = u.id
       JOIN rooms r ON cl.room_id = r.id
       WHERE cl.cleaned_at >= datetime('now', '-1 hour')
       GROUP BY cl.user_id, cl.room_id
       HAVING COUNT(*) > 3`
    );

    rapidLogs.forEach((r) => {
      anomalies.push({
        severity: 'medium',
        icon: 'speed',
        title: `${r.user_name} - ${r.room_name}'a ${r.count} kayıt (1 saatte)`,
        description: 'Şüpheli hızlı kayıt aktivitesi',
        type: 'rapid_logs',
      });
    });

    // KURAL 3: GECİKMİŞ GÖREV — scheduled_for geçti, hâlâ pending
    const overdueTasks = await dbAll(
      `SELECT st.id, st.title, st.scheduled_for, u.name as user_name
       FROM scheduled_tasks st
       LEFT JOIN users u ON st.assigned_user_id = u.id
       WHERE st.status = 'pending'
         AND datetime(st.scheduled_for) < datetime('now')
       ORDER BY st.scheduled_for ASC
       LIMIT 5`
    );

    overdueTasks.forEach((t) => {
      anomalies.push({
        severity: 'high',
        icon: 'event_busy',
        title: `Gecikmiş görev: ${t.title}`,
        description: `${t.user_name || 'Atanmadı'} - Tarih: ${t.scheduled_for}`,
        type: 'overdue_task',
        data: { task_id: t.id },
      });
    });

    // KURAL 4: HAFTALIK TREND — bu hafta vs geçen hafta %30+ sapma
    const weekComparison = await dbAll(
      `SELECT
         (SELECT COUNT(*) FROM cleaning_logs
          WHERE cleaned_at >= datetime('now', '-7 days')) as this_week,
         (SELECT COUNT(*) FROM cleaning_logs
          WHERE cleaned_at >= datetime('now', '-14 days')
            AND cleaned_at < datetime('now', '-7 days')) as last_week`
    );

    if (weekComparison.length > 0) {
      const { this_week, last_week } = weekComparison[0];
      if (last_week > 0) {
        const numChange = Math.round(((this_week - last_week) / last_week) * 100);
        if (Math.abs(numChange) >= 30) {
          anomalies.push({
            severity: 'info',
            icon: numChange > 0 ? 'trending_up' : 'trending_down',
            title: `Bu hafta kayıt sayısı %${Math.abs(numChange)} ${numChange > 0 ? 'arttı' : 'azaldı'}`,
            description: `Geçen hafta: ${last_week} kayıt, Bu hafta: ${this_week} kayıt`,
            type: 'weekly_trend',
          });
        }
      }
    }

    // KURAL 5: ONAY BEKLEYEN KULLANICILAR — users tablosunda created_at yok, sayı yeter
    const pendingUsers = await dbAll(
      `SELECT id, name, email
       FROM users
       WHERE approval_status = 'pending'
       ORDER BY id ASC`
    );

    if (pendingUsers.length > 0) {
      anomalies.push({
        severity: 'medium',
        icon: 'pending_actions',
        title: `${pendingUsers.length} kullanıcı onay bekliyor`,
        description: 'Yeni kayıt onayı verilmesi bekleniyor',
        type: 'pending_approvals',
        data: { count: pendingUsers.length },
      });
    }

    // KURAL 6: KRİTİK STOK — bitmek üzere olan malzemeler
    const criticalStock = await dbAll(
      `SELECT i.id, i.name, i.unit, i.current_amount, i.min_threshold,
              (SELECT COALESCE(SUM(amount), 0)
               FROM inventory_logs
               WHERE inventory_id = i.id
                 AND action = 'use'
                 AND created_at >= datetime('now', '-7 days')) as used_7d,
              (SELECT COUNT(DISTINCT DATE(created_at))
               FROM inventory_logs
               WHERE inventory_id = i.id
                 AND action = 'use'
                 AND created_at >= datetime('now', '-7 days')) as days_7d
       FROM inventory i`
    );

    criticalStock.forEach((stock) => {
      if (stock.current_amount <= stock.min_threshold) {
        anomalies.push({
          severity: 'high',
          icon: 'inventory_2',
          title: `${stock.name} kritik seviyede`,
          description: `Stokta sadece ${stock.current_amount} ${stock.unit} kaldı (min: ${stock.min_threshold})`,
          type: 'low_stock',
          data: { inventory_id: stock.id },
        });
        return;
      }

      if (stock.used_7d > 0 && stock.days_7d > 0) {
        const dailyAvg = stock.used_7d / stock.days_7d;
        const daysRemaining = Math.floor(stock.current_amount / dailyAvg);
        if (daysRemaining < 5) {
          anomalies.push({
            severity: 'high',
            icon: 'schedule',
            title: `${stock.name} ${daysRemaining} gün sonra bitecek`,
            description: `Günlük ortalama: ${dailyAvg.toFixed(1)} ${stock.unit}, mevcut: ${stock.current_amount} ${stock.unit}`,
            type: 'stock_running_out',
            data: { inventory_id: stock.id },
          });
        } else if (daysRemaining < 10) {
          anomalies.push({
            severity: 'medium',
            icon: 'schedule',
            title: `${stock.name} 10 gün içinde bitebilir`,
            description: `Günlük ortalama: ${dailyAvg.toFixed(1)} ${stock.unit}, ${daysRemaining} gün kaldı`,
            type: 'stock_warning',
            data: { inventory_id: stock.id },
          });
        }
      }
    });

    const severityOrder = { high: 0, medium: 1, info: 2 };
    anomalies.sort((a, b) => severityOrder[a.severity] - severityOrder[b.severity]);

    res.json({ count: anomalies.length, anomalies });
  } catch (err) {
    console.error('Anomali endpoint hatası:', err);
    res.status(500).json({ message: 'Anomali tespiti hatası: ' + err.message });
  }
});

module.exports = router;
