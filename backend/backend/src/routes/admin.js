const express = require('express');
const db = require('../db');

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

module.exports = router;
