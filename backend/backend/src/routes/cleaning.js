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

// GET /api/cleaning/comparison -> bu hafta vs geçen hafta + bu ay vs geçen ay
router.get('/comparison', (req, res) => {
  const userId = req.user?.id;
  const role = req.user?.role;

  const userFilter = role === 'admin' ? '' : 'AND user_id = ?';
  const params = role === 'admin' ? [] : [userId];

  const queries = {
    thisWeek: `SELECT COUNT(*) as count FROM cleaning_logs
               WHERE cleaned_at >= datetime('now', '-7 days')
               ${userFilter}`,
    lastWeek: `SELECT COUNT(*) as count FROM cleaning_logs
               WHERE cleaned_at >= datetime('now', '-14 days')
                 AND cleaned_at < datetime('now', '-7 days')
               ${userFilter}`,
    thisMonth: `SELECT COUNT(*) as count FROM cleaning_logs
                WHERE cleaned_at >= datetime('now', '-30 days')
                ${userFilter}`,
    lastMonth: `SELECT COUNT(*) as count FROM cleaning_logs
                WHERE cleaned_at >= datetime('now', '-60 days')
                  AND cleaned_at < datetime('now', '-30 days')
                ${userFilter}`,
  };

  const dailySql = `
    SELECT
      DATE(cleaned_at) as day,
      COUNT(*) as count
    FROM cleaning_logs
    WHERE cleaned_at >= datetime('now', '-14 days')
      ${userFilter}
    GROUP BY DATE(cleaned_at)
    ORDER BY day ASC
  `;

  const results = {};
  let completed = 0;
  const total = 5;
  let errSent = false;

  function checkDone() {
    completed++;
    if (completed === total) sendResponse();
  }

  function fail(err) {
    if (!errSent) {
      errSent = true;
      console.error('Comparison hata:', err.message);
      res.status(500).json({ message: 'DB hatası' });
    }
  }

  function sendResponse() {
    const thisWeek = results.thisWeek || 0;
    const lastWeek = results.lastWeek || 0;
    const thisMonth = results.thisMonth || 0;
    const lastMonth = results.lastMonth || 0;

    const weekChange = lastWeek > 0
      ? ((thisWeek - lastWeek) / lastWeek) * 100
      : (thisWeek > 0 ? 100 : 0);
    const monthChange = lastMonth > 0
      ? ((thisMonth - lastMonth) / lastMonth) * 100
      : (thisMonth > 0 ? 100 : 0);

    function trendOf(change) {
      if (change > 5) return 'up';
      if (change < -5) return 'down';
      return 'stable';
    }

    const today = new Date();
    const dailyCompare = [];
    for (let i = 6; i >= 0; i--) {
      const thisDate = new Date(today);
      thisDate.setDate(thisDate.getDate() - i);
      const lastDate = new Date(today);
      lastDate.setDate(lastDate.getDate() - i - 7);

      const thisDayStr = thisDate.toISOString().split('T')[0];
      const lastDayStr = lastDate.toISOString().split('T')[0];

      const thisDayData = (results.daily || []).find(r => r.day === thisDayStr);
      const lastDayData = (results.daily || []).find(r => r.day === lastDayStr);

      const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      const dayLabel = dayNames[(thisDate.getDay() + 6) % 7];

      dailyCompare.push({
        day_label: dayLabel,
        this_week: thisDayData ? thisDayData.count : 0,
        last_week: lastDayData ? lastDayData.count : 0,
      });
    }

    res.json({
      week: {
        this: thisWeek,
        last: lastWeek,
        change_pct: parseFloat(weekChange.toFixed(1)),
        trend: trendOf(weekChange),
      },
      month: {
        this: thisMonth,
        last: lastMonth,
        change_pct: parseFloat(monthChange.toFixed(1)),
        trend: trendOf(monthChange),
      },
      daily_comparison: dailyCompare,
    });
  }

  db.get(queries.thisWeek, params, (err, row) => {
    if (err) return fail(err);
    results.thisWeek = row?.count || 0;
    checkDone();
  });
  db.get(queries.lastWeek, params, (err, row) => {
    if (err) return fail(err);
    results.lastWeek = row?.count || 0;
    checkDone();
  });
  db.get(queries.thisMonth, params, (err, row) => {
    if (err) return fail(err);
    results.thisMonth = row?.count || 0;
    checkDone();
  });
  db.get(queries.lastMonth, params, (err, row) => {
    if (err) return fail(err);
    results.lastMonth = row?.count || 0;
    checkDone();
  });
  db.all(dailySql, params, (err, rows) => {
    if (err) return fail(err);
    results.daily = rows || [];
    checkDone();
  });
});

module.exports = router;
