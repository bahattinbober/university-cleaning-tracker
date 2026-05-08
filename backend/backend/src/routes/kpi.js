const express = require('express');
const db = require('../db');

const router = express.Router();

const dbGet = (sql, params = []) =>
  new Promise((resolve, reject) =>
    db.get(sql, params, (err, row) => (err ? reject(err) : resolve(row)))
  );

const dbAll = (sql, params = []) =>
  new Promise((resolve, reject) =>
    db.all(sql, params, (err, rows) => (err ? reject(err) : resolve(rows)))
  );

// GET /api/kpi/me -> giriş yapan kullanıcının detaylı KPI'ı
router.get('/me', async (req, res) => {
  await calculateAndReturn(req.user.id, res);
});

// GET /api/kpi/user/:id -> belirli bir kullanıcının KPI'ı (admin veya kendisi)
router.get('/user/:id', (req, res, next) => {
  if (req.user.role !== 'admin' && req.user.id !== Number(req.params.id)) {
    return res.status(403).json({ message: 'Yetkiniz yok' });
  }
  next();
}, async (req, res) => {
  await calculateAndReturn(Number(req.params.id), res);
});

// POST /api/kpi/target -> admin hedef atar
router.post('/target', (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Sadece admin hedef atayabilir' });
  }

  const { user_id, target_value } = req.body;

  if (!user_id || !target_value || target_value < 1 || target_value > 1000) {
    return res.status(400).json({ message: 'Geçersiz hedef değeri (1-1000 arası)' });
  }

  const sql = `
    INSERT INTO kpi_targets (user_id, target_value, set_by)
    VALUES (?, ?, ?)
    ON CONFLICT(user_id) DO UPDATE SET
      target_value = excluded.target_value,
      set_by       = excluded.set_by,
      set_at       = datetime('now')
  `;

  db.run(sql, [user_id, target_value, req.user.id], function (err) {
    if (err) {
      console.error('KPI target kayıt hatası:', err);
      return res.status(500).json({ message: 'Hedef kaydedilemedi' });
    }
    res.json({ message: 'Hedef başarıyla atandı', user_id, target_value });
  });
});

// GET /api/kpi/target/:user_id -> hedef getir
router.get('/target/:user_id', (req, res) => {
  const userId = Number(req.params.user_id);

  if (req.user.role !== 'admin' && req.user.id !== userId) {
    return res.status(403).json({ message: 'Yetkiniz yok' });
  }

  db.get(
    'SELECT * FROM kpi_targets WHERE user_id = ?',
    [userId],
    (err, row) => {
      if (err) return res.status(500).json({ message: 'Hata' });
      res.json(row || { user_id: userId, target_value: null });
    }
  );
});

// GET /api/kpi/trend/:user_id -> son 7 günlük günlük kayıt sayısı
router.get('/trend/:user_id', (req, res) => {
  const userId = Number(req.params.user_id);

  if (req.user.role !== 'admin' && req.user.id !== userId) {
    return res.status(403).json({ message: 'Yetkiniz yok' });
  }

  const sql = `
    SELECT
      DATE(cleaned_at) as date,
      COUNT(*) as count,
      SUM(CASE WHEN image IS NOT NULL AND image != '' THEN 1 ELSE 0 END) as photo_count,
      SUM(CASE WHEN notes IS NOT NULL AND notes != '' THEN 1 ELSE 0 END) as note_count
    FROM cleaning_logs
    WHERE user_id = ?
      AND cleaned_at >= datetime('now', '-7 days')
    GROUP BY DATE(cleaned_at)
    ORDER BY date ASC
  `;

  db.all(sql, [userId], (err, rows) => {
    if (err) return res.status(500).json({ message: 'Hata' });

    // Eksik günleri 0 ile doldur
    const result = [];
    for (let i = 6; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      const found = rows.find((r) => r.date === dateStr);
      result.push({
        date: dateStr,
        count: found ? found.count : 0,
        photo_count: found ? found.photo_count : 0,
        note_count: found ? found.note_count : 0,
      });
    }

    res.json(result);
  });
});

async function calculateAndReturn(userId, res) {
  try {
    const user = await dbGet(
      `SELECT id, name, email FROM users WHERE id = ?`,
      [userId]
    );
    if (!user) return res.status(404).json({ message: 'Kullanıcı bulunamadı' });

    // Son 7 gün istatistikleri
    const stats = await dbGet(
      `SELECT
         COUNT(*) as total,
         SUM(CASE WHEN notes IS NOT NULL AND notes != '' THEN 1 ELSE 0 END) as noted,
         SUM(CASE WHEN image IS NOT NULL AND image != '' THEN 1 ELSE 0 END) as photo,
         SUM(CASE WHEN strftime('%H', cleaned_at) BETWEEN '06' AND '14' THEN 1 ELSE 0 END) as on_time,
         SUM(CASE WHEN strftime('%H', cleaned_at) > '14' THEN 1 ELSE 0 END) as late
       FROM cleaning_logs
       WHERE user_id = ? AND cleaned_at >= datetime('now', '-7 days')`,
      [userId]
    );

    const total   = Number(stats?.total   || 0);
    const noted   = Number(stats?.noted   || 0);
    const photo   = Number(stats?.photo   || 0);
    const on_time = Number(stats?.on_time || 0);
    const late    = Number(stats?.late    || 0);

    // Sistem ortalaması (tüm aktif personelin son 7 günü)
    const systemAvg = await dbGet(
      `SELECT AVG(cnt) as avg_total FROM (
         SELECT COUNT(*) as cnt
         FROM cleaning_logs cl
         JOIN users u ON cl.user_id = u.id
         WHERE cl.cleaned_at >= datetime('now', '-7 days')
           AND u.role = 'staff'
         GROUP BY cl.user_id
       )`
    );
    const avgTotal = Math.max(Number(systemAvg?.avg_total || 0), 10);

    // Kişisel hedef
    const targetRow = await dbGet(
      'SELECT target_value FROM kpi_targets WHERE user_id = ?',
      [userId]
    );
    const target = targetRow ? targetRow.target_value : null;
    const targetCompletion = target
      ? Math.min(100, Math.round((total / target) * 100))
      : null;

    // ── 4 BİLEŞEN (0-100) ──────────────────────────────────────────────────

    // 1. VERİMLİLİK %40 — kayıt / hedef (ortalama × 1.5)
    const productivityTarget = avgTotal * 1.5;
    const productivity = Math.min(100, Math.round((total / productivityTarget) * 100));

    // 2. KALİTE %30 — (fotoğraf + not) / (kayıt × 2)
    const quality = total > 0
      ? Math.min(100, Math.round(((photo + noted) / (total * 2)) * 100))
      : 0;

    // 3. ZAMANLAMA %20 — zamanında / toplam
    const timeliness = total > 0
      ? Math.round((on_time / total) * 100)
      : 0;

    // 4. UYUMLULUK %10 — geç kalanların tersi
    const compliance = total > 0
      ? Math.max(0, Math.round(((total - late) / total) * 100))
      : 100;

    // Ağırlıklı genel skor (0-100)
    const overall = Math.round(
      productivity * 0.40 +
      quality      * 0.30 +
      timeliness   * 0.20 +
      compliance   * 0.10
    );

    // Harf notu
    const grade =
      overall >= 90 ? 'A+' :
      overall >= 80 ? 'A'  :
      overall >= 70 ? 'B'  :
      overall >= 60 ? 'C'  :
      overall >= 50 ? 'D'  : 'F';

    // Performans seviyesi
    let level, levelName, levelEmoji;
    if      (overall >= 85) { level = 5; levelName = 'Üstün Performans';  levelEmoji = '⭐'; }
    else if (overall >= 70) { level = 4; levelName = 'Yüksek Performans'; levelEmoji = '🟢'; }
    else if (overall >= 55) { level = 3; levelName = 'İyi Performans';    levelEmoji = '🔵'; }
    else if (overall >= 40) { level = 2; levelName = 'Gelişmekte';        levelEmoji = '🟡'; }
    else                    { level = 1; levelName = 'Geliştirilmeli';    levelEmoji = '🔴'; }

    // Eski formül (geriye uyumluluk)
    const legacyScore = total * 5 + noted * 1 + photo * 2 + on_time * 4 - late * 2;
    const legacyMax   = total * (5 + 1 + 2 + 4);

    res.json({
      user:   { id: user.id, name: user.name, email: user.email },
      period: 'last_7_days',

      overall_score: overall,
      max_score:     100,
      grade,

      components: {
        productivity: { value: productivity, weight: 40, label: 'Verimlilik',  icon: 'speed'    },
        quality:      { value: quality,      weight: 30, label: 'Kalite',      icon: 'star'     },
        timeliness:   { value: timeliness,   weight: 20, label: 'Zamanlama',   icon: 'schedule' },
        compliance:   { value: compliance,   weight: 10, label: 'Uyumluluk',   icon: 'verified' },
      },

      stats: { total, noted, photo, on_time, late },

      benchmark: {
        system_average_records: Math.round(avgTotal),
        productivity_target:    Math.round(productivityTarget),
        records_above_average:  Math.max(0, total - Math.round(avgTotal)),
        target,
        target_completion:      targetCompletion,
      },

      legacy_score: legacyScore,
      legacy_max:   legacyMax,

      level: { number: level, name: levelName, emoji: levelEmoji },

      breakdown: [
        { label: 'Toplam Kayıt', count: total,   points: total   * 5, formula: `${total} × 5`   },
        { label: 'Fotoğraflı',  count: photo,   points: photo   * 2, formula: `${photo} × 2`   },
        { label: 'Notlu',       count: noted,   points: noted   * 1, formula: `${noted} × 1`   },
        { label: 'Zamanında',   count: on_time, points: on_time * 4, formula: `${on_time} × 4` },
        { label: 'Geç (ceza)',  count: late,    points: -late   * 2, formula: `-${late} × 2`   },
      ],
    });
  } catch (err) {
    console.error('KPI hesaplama hatası:', err);
    res.status(500).json({ message: 'KPI hesaplanamadı: ' + err.message });
  }
}

module.exports = router;
