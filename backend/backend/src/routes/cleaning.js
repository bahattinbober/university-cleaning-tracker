const express = require('express');
const db = require('../db');

const router = express.Router();

// POST /api/cleaning veya /api/cleaning-logs -> temizlik kaydı ekle
router.post('/', (req, res) => {
  const { user_id, room_id, status, notes, image, used_materials } = req.body;
  const userId = user_id || req.user.id; // body'den gelebilir, yoksa token kullan

  if (image && Buffer.byteLength(image, 'base64') > 1.5 * 1024 * 1024) {
    return res.status(413).json({ message: 'Fotoğraf çok büyük (max 1MB)' });
  }

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

      // Kullanılan malzemeleri stoktan düş
      if (Array.isArray(used_materials) && used_materials.length > 0) {
        used_materials.forEach((mat) => {
          const invId = Number(mat.inventory_id);
          const amount = Number(mat.amount);
          if (!invId || !amount || amount <= 0) return;

          db.run(
            `UPDATE inventory
             SET current_amount = MAX(0, current_amount - ?),
                 updated_at = datetime('now')
             WHERE id = ?`,
            [amount, invId]
          );

          db.run(
            `INSERT INTO inventory_logs (inventory_id, user_id, action, amount, note)
             VALUES (?, ?, 'use', ?, ?)`,
            [invId, userId, amount, `Temizlik kaydı #${cleaningLogId}`]
          );
        });
      }

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

// GET /api/cleaning/heatmap -> gün×saat yoğunluk haritası
router.get('/heatmap', (req, res) => {
  const userId = req.user?.id;
  const role = req.user?.role;

  const sql = role === 'admin'
    ? `SELECT cleaned_at FROM cleaning_logs
       WHERE cleaned_at >= datetime('now', '-30 days')`
    : `SELECT cleaned_at FROM cleaning_logs
       WHERE user_id = ?
         AND cleaned_at >= datetime('now', '-30 days')`;

  const params = role === 'admin' ? [] : [userId];

  db.all(sql, params, (err, rows) => {
    if (err) return res.status(500).json({ message: 'DB hatası' });

    // 7 gün × 5 saat dilimi: 06-09, 09-12, 12-15, 15-18, 18-21
    const grid = Array.from({ length: 7 }, () =>
      Array.from({ length: 5 }, () => 0)
    );

    const slotForHour = (hour) => {
      if (hour >= 6 && hour < 9) return 0;
      if (hour >= 9 && hour < 12) return 1;
      if (hour >= 12 && hour < 15) return 2;
      if (hour >= 15 && hour < 18) return 3;
      if (hour >= 18 && hour < 21) return 4;
      return -1;
    };

    let total = 0;
    let maxValue = 0;

    rows.forEach((row) => {
      const dt = new Date(row.cleaned_at);
      const dayOfWeek = (dt.getDay() + 6) % 7; // Pzt=0, Paz=6
      const hour = dt.getHours();
      const slot = slotForHour(hour);

      if (slot >= 0) {
        grid[dayOfWeek][slot]++;
        total++;
        if (grid[dayOfWeek][slot] > maxValue) {
          maxValue = grid[dayOfWeek][slot];
        }
      }
    });

    let peakDay = -1, peakSlot = -1, peakValue = 0;
    for (let d = 0; d < 7; d++) {
      for (let s = 0; s < 5; s++) {
        if (grid[d][s] > peakValue) {
          peakValue = grid[d][s];
          peakDay = d;
          peakSlot = s;
        }
      }
    }

    res.json({
      grid,
      total,
      max_value: maxValue,
      day_labels: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
      slot_labels: ['06-09', '09-12', '12-15', '15-18', '18-21'],
      peak: peakValue > 0 ? {
        day: peakDay,
        slot: peakSlot,
        value: peakValue,
      } : null,
      period_days: 30,
    });
  });
});

module.exports = router;
