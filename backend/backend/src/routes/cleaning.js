const express = require('express');
const db = require('../db');

const router = express.Router();

// POST /api/cleaning veya /api/cleaning-logs -> temizlik kaydı ekle
router.post('/', (req, res) => {
  const { user_id, room_id, status, notes, image } = req.body;
  const userId = user_id || req.user.id; // body'den gelebilir, yoksa token kullan

  if (!userId || !room_id || !status) {
    return res
      .status(400)
      .json({ message: 'user_id, room_id ve status zorunlu' });
  }

  if (status !== 'completed') {
    return res.status(400).json({ message: 'status sadece "completed" olabilir' });
  }

  db.run(
    `INSERT INTO cleaning_logs (user_id, room_id, status, notes, image)
     VALUES (?, ?, ?, ?, ?)`,
    [userId, room_id, status, notes || null, image || null],
    function (err) {
      if (err) {
        console.error('Cleaning ekleme hata:', err.message);
        return res.status(500).json({ message: 'Sunucu hatası' });
      }

      const cleaningLogId = this.lastID;

      // Oluşan cleaning log için en yakın pending planlı görevi tamamlanmışa çevir.
      const matchSql = `
        SELECT id
        FROM scheduled_tasks
        WHERE room_id = ?
          AND status = 'pending'
          AND (assigned_user_id = ? OR assigned_user_id IS NULL)
        ORDER BY ABS(strftime('%s', scheduled_for) - strftime('%s', 'now')) ASC
        LIMIT 1
      `;

      db.get(matchSql, [room_id, userId], (matchErr, taskRow) => {
        if (matchErr) {
          console.error('Scheduled task eşleşme hatası:', matchErr.message);
        } else if (taskRow) {
          db.run(
            `UPDATE scheduled_tasks
             SET status = 'completed', completed_log_id = ?
             WHERE id = ?`,
            [cleaningLogId, taskRow.id],
            (updateErr) => {
              if (updateErr) {
                console.error('Scheduled task güncelleme hatası:', updateErr.message);
              }
            }
          );
        }

        res.status(201).json({
          id: cleaningLogId,
          user_id: userId,
          room_id,
          status,
          notes: notes || null,
          image: image || null,
        });
      });
    }
  );
});

// GET /api/cleaning/my -> sadece giriş yapan kullanıcının kayıtları
router.get('/my', (req, res) => {
  const userId = req.user.id;

  const sql = `
    SELECT cl.*,
           r.name AS room_name
    FROM cleaning_logs cl
    LEFT JOIN rooms r ON cl.room_id = r.id
    WHERE cl.user_id = ?
    ORDER BY cl.cleaned_at DESC
  `;

  db.all(sql, [userId], (err, rows) => {
    if (err) {
      console.error('My logs hata:', err.message);
      return res.status(500).json({ message: 'Sunucu hatası' });
    }
    res.json(rows);
  });
});

// GET /api/cleaning -> tüm kayıtlar (sadece admin)
router.get('/', (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok (admin değil)' });
  }

  const sql = `
    SELECT cl.*,
           u.name AS user_name,
           r.name AS room_name
    FROM cleaning_logs cl
    LEFT JOIN users u ON cl.user_id = u.id
    LEFT JOIN rooms r ON cl.room_id = r.id
    ORDER BY cl.cleaned_at DESC
  `;

  db.all(sql, [], (err, rows) => {
    if (err) {
      console.error('All logs hata:', err.message);
      return res.status(500).json({ message: 'Sunucu hatası' });
    }
    res.json(rows);
  });
});

module.exports = router;
