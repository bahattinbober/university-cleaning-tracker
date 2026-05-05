const express = require('express');
const db = require('../db');

const router = express.Router();

function ensureAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok' });
  }
  next();
}

// GET /api/inventory -> tüm malzemeler + tahmin
router.get('/', (req, res) => {
  db.all(`SELECT * FROM inventory ORDER BY name ASC`, [], (err, items) => {
    if (err) return res.status(500).json({ message: 'DB hatası' });

    Promise.all(
      items.map(
        (item) =>
          new Promise((resolve) => {
            db.get(
              `SELECT
                 COALESCE(SUM(amount), 0) as total_used,
                 COUNT(DISTINCT DATE(created_at)) as days
               FROM inventory_logs
               WHERE inventory_id = ?
                 AND action = 'use'
                 AND created_at >= datetime('now', '-7 days')`,
              [item.id],
              (err2, row) => {
                if (err2 || !row || row.total_used === 0) {
                  resolve({
                    ...item,
                    daily_average: 0,
                    days_remaining: null,
                    status:
                      item.current_amount <= item.min_threshold
                        ? 'critical'
                        : 'normal',
                  });
                  return;
                }

                const dailyAvg = row.total_used / Math.max(row.days, 1);
                const daysRemaining =
                  dailyAvg > 0
                    ? Math.floor(item.current_amount / dailyAvg)
                    : null;

                let status = 'normal';
                if (item.current_amount <= item.min_threshold) {
                  status = 'critical';
                } else if (daysRemaining !== null && daysRemaining < 5) {
                  status = 'critical';
                } else if (daysRemaining !== null && daysRemaining < 10) {
                  status = 'warning';
                }

                resolve({
                  ...item,
                  daily_average: parseFloat(dailyAvg.toFixed(2)),
                  days_remaining: daysRemaining,
                  status,
                });
              }
            );
          })
      )
    ).then((enriched) => res.json(enriched));
  });
});

// POST /api/inventory -> yeni malzeme ekle (admin)
router.post('/', ensureAdmin, (req, res) => {
  const { name, unit, current_amount, min_threshold, category } = req.body;

  if (!name || !unit) {
    return res.status(400).json({ message: 'name ve unit zorunlu' });
  }

  const trimmedName = String(name).trim();
  const trimmedUnit = String(unit).trim();
  const amount = Number(current_amount) || 0;
  const threshold = Number(min_threshold) || 0;

  db.run(
    `INSERT INTO inventory (name, unit, current_amount, min_threshold, category)
     VALUES (?, ?, ?, ?, ?)`,
    [
      trimmedName,
      trimmedUnit,
      amount,
      threshold,
      category ? String(category).trim() : null,
    ],
    function (err) {
      if (err) return res.status(500).json({ message: 'Ekleme hatası: ' + err.message });

      const newId = this.lastID;

      if (amount > 0) {
        db.run(
          `INSERT INTO inventory_logs (inventory_id, user_id, action, amount, note)
           VALUES (?, ?, 'add', ?, 'İlk stok girişi')`,
          [newId, req.user.id, amount]
        );
      }

      res.status(201).json({
        id: newId,
        name: trimmedName,
        unit: trimmedUnit,
        current_amount: amount,
        min_threshold: threshold,
        category: category || null,
        daily_average: 0,
        days_remaining: null,
        status: amount <= threshold ? 'critical' : 'normal',
      });
    }
  );
});

// PUT /api/inventory/:id/restock -> stok ekle (admin)
router.put('/:id/restock', ensureAdmin, (req, res) => {
  const id = Number(req.params.id);
  const addAmount = Number(req.body.amount);
  const note = req.body.note;

  if (!addAmount || addAmount <= 0) {
    return res.status(400).json({ message: 'Geçerli amount gerekli' });
  }

  db.get(`SELECT * FROM inventory WHERE id = ?`, [id], (err, item) => {
    if (err || !item) return res.status(404).json({ message: 'Malzeme bulunamadı' });

    const newAmount = item.current_amount + addAmount;

    db.run(
      `UPDATE inventory SET current_amount = ?, updated_at = datetime('now') WHERE id = ?`,
      [newAmount, id],
      (updateErr) => {
        if (updateErr) return res.status(500).json({ message: 'Güncelleme hatası' });

        db.run(
          `INSERT INTO inventory_logs (inventory_id, user_id, action, amount, note)
           VALUES (?, ?, 'add', ?, ?)`,
          [id, req.user.id, addAmount, note ? String(note).trim() : 'Stok eklendi']
        );

        res.json({ id, current_amount: newAmount });
      }
    );
  });
});

// DELETE /api/inventory/:id -> sil (admin)
router.delete('/:id', ensureAdmin, (req, res) => {
  const id = Number(req.params.id);
  db.run(`DELETE FROM inventory WHERE id = ?`, [id], function (err) {
    if (err) return res.status(500).json({ message: 'Silme hatası' });
    if (this.changes === 0) return res.status(404).json({ message: 'Malzeme bulunamadı' });
    res.json({ id, deleted: true });
  });
});

// GET /api/inventory/:id/logs -> hareket geçmişi
router.get('/:id/logs', (req, res) => {
  const id = Number(req.params.id);
  db.all(
    `SELECT il.*, u.name as user_name
     FROM inventory_logs il
     LEFT JOIN users u ON il.user_id = u.id
     WHERE il.inventory_id = ?
     ORDER BY il.created_at DESC
     LIMIT 50`,
    [id],
    (err, rows) => {
      if (err) return res.status(500).json({ message: 'DB hatası' });
      res.json(rows);
    }
  );
});

module.exports = router;
