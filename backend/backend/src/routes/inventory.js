const express = require('express');
const db = require('../db');

const router = express.Router();

function ensureAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok' });
  }
  next();
}

// GET /api/inventory/abc-analysis -> ABC sınıflandırması (son 30 gün)
router.get('/abc-analysis', (req, res) => {
  const sql = `
    SELECT
      i.id,
      i.name,
      i.unit,
      i.current_amount,
      i.category,
      COALESCE(SUM(CASE WHEN il.action = 'use'
                       THEN il.amount ELSE 0 END), 0) as total_usage
    FROM inventory i
    LEFT JOIN inventory_logs il ON il.inventory_id = i.id
      AND il.created_at >= datetime('now', '-30 days')
    GROUP BY i.id
    ORDER BY total_usage DESC
  `;

  db.all(sql, [], (err, items) => {
    if (err) return res.status(500).json({ message: 'DB hatası' });

    if (items.length === 0) {
      return res.json({
        items: [],
        summary: {
          total_items: 0,
          total_usage: 0,
          a_count: 0, b_count: 0, c_count: 0,
          a_percentage: 0, b_percentage: 0, c_percentage: 0,
        },
        analysis_period: 'last_30_days',
      });
    }

    const totalUsage = items.reduce((sum, item) => sum + Number(item.total_usage), 0);

    let cumulative = 0;
    const enriched = items.map((item) => {
      const usage = Number(item.total_usage);
      const percentage = totalUsage > 0 ? (usage / totalUsage) * 100 : 0;
      cumulative += percentage;

      let abc_class;
      if (totalUsage === 0) abc_class = 'C';
      else if (cumulative <= 80) abc_class = 'A';
      else if (cumulative <= 95) abc_class = 'B';
      else abc_class = 'C';

      return {
        ...item,
        total_usage: usage,
        percentage: parseFloat(percentage.toFixed(2)),
        cumulative_percentage: parseFloat(cumulative.toFixed(2)),
        abc_class,
      };
    });

    const aItems = enriched.filter(i => i.abc_class === 'A');
    const bItems = enriched.filter(i => i.abc_class === 'B');
    const cItems = enriched.filter(i => i.abc_class === 'C');

    const calcPct = (arr) => totalUsage > 0
      ? parseFloat(((arr.reduce((s, i) => s + i.total_usage, 0) / totalUsage) * 100).toFixed(1))
      : 0;

    res.json({
      items: enriched,
      summary: {
        total_items: items.length,
        total_usage: totalUsage,
        a_count: aItems.length,
        b_count: bItems.length,
        c_count: cItems.length,
        a_percentage: calcPct(aItems),
        b_percentage: calcPct(bItems),
        c_percentage: calcPct(cItems),
      },
      analysis_period: 'last_30_days',
    });
  });
});

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
                const LEAD_TIME_DAYS = 7;
                const SAFETY_STOCK_DAYS = 3;
                const ORDER_COST = 50;
                const HOLDING_COST_PER_UNIT = 10;
                const SERVICE_LEVEL_Z = 1.65;

                if (err2 || !row || row.total_used === 0) {
                  const rop0 = item.min_threshold;
                  let alertLevel0;
                  if (item.current_amount === 0) alertLevel0 = 'depleted';
                  else if (item.current_amount <= item.min_threshold) alertLevel0 = 'critical';
                  else alertLevel0 = 'normal';

                  resolve({
                    ...item,
                    daily_average: 0,
                    days_remaining: null,
                    status: item.current_amount <= item.min_threshold ? 'critical' : 'normal',
                    reorder_point: rop0,
                    suggested_order: null,
                    alert_level: alertLevel0,
                    lead_time_days: LEAD_TIME_DAYS,
                    eoq_optimal_order: 0,
                    annual_demand: 0,
                    orders_per_year: 0,
                    days_between_orders: null,
                    safety_stock_statistical: item.min_threshold,
                    service_level: 95,
                    cost_parameters: { order_cost: ORDER_COST, holding_cost: HOLDING_COST_PER_UNIT },
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

                const reorderPoint = Math.ceil(dailyAvg * (LEAD_TIME_DAYS + SAFETY_STOCK_DAYS));
                const suggestedOrderAmt = Math.ceil(dailyAvg * 30 - item.current_amount);

                let alertLevel;
                if (item.current_amount === 0) alertLevel = 'depleted';
                else if (item.current_amount <= item.min_threshold) alertLevel = 'critical';
                else if (item.current_amount <= reorderPoint) alertLevel = 'reorder';
                else alertLevel = 'normal';

                const annualDemand = dailyAvg * 365;
                const eoq = Math.ceil(Math.sqrt((2 * annualDemand * ORDER_COST) / HOLDING_COST_PER_UNIT));
                const ordersPerYear = eoq > 0 ? Math.round(annualDemand / eoq) : 0;
                const daysBetweenOrders = ordersPerYear > 0 ? Math.round(365 / ordersPerYear) : null;
                const demandStdDev = dailyAvg * 0.3;
                const safetyStockStat = Math.ceil(SERVICE_LEVEL_Z * demandStdDev * Math.sqrt(LEAD_TIME_DAYS));

                resolve({
                  ...item,
                  daily_average: parseFloat(dailyAvg.toFixed(2)),
                  days_remaining: daysRemaining,
                  status,
                  reorder_point: reorderPoint,
                  suggested_order: suggestedOrderAmt > 0 ? suggestedOrderAmt : null,
                  alert_level: alertLevel,
                  lead_time_days: LEAD_TIME_DAYS,
                  eoq_optimal_order: eoq,
                  annual_demand: Math.round(annualDemand),
                  orders_per_year: ordersPerYear,
                  days_between_orders: daysBetweenOrders,
                  safety_stock_statistical: safetyStockStat,
                  service_level: 95,
                  cost_parameters: { order_cost: ORDER_COST, holding_cost: HOLDING_COST_PER_UNIT },
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
