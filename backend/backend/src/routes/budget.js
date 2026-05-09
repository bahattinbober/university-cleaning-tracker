const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/budget/summary -> mevcut stok değeri + tüketim + kategori + top 10
router.get('/summary', (req, res) => {
  const inventoryValueSql = `
    SELECT
      COALESCE(SUM(current_amount * unit_cost), 0) as total_value,
      COUNT(*) as item_count,
      COUNT(CASE WHEN unit_cost > 0 THEN 1 END) as costed_items
    FROM inventory
  `;

  const consumedSql = `
    SELECT
      COALESCE(SUM(l.amount * i.unit_cost), 0) as consumed_cost
    FROM inventory_logs l
    JOIN inventory i ON l.inventory_id = i.id
    WHERE l.action = 'use'
      AND l.created_at >= datetime('now', '-30 days')
      AND i.unit_cost > 0
  `;

  const categorySql = `
    SELECT
      COALESCE(category, 'Genel') as category,
      SUM(current_amount * unit_cost) as value,
      COUNT(*) as item_count
    FROM inventory
    WHERE unit_cost > 0
    GROUP BY category
    ORDER BY value DESC
  `;

  const topItemsSql = `
    SELECT
      id, name, unit, current_amount, unit_cost,
      (current_amount * unit_cost) as total_value
    FROM inventory
    WHERE unit_cost > 0
    ORDER BY total_value DESC
    LIMIT 10
  `;

  const results = {};
  let completed = 0;
  let errSent = false;

  function fail(err) {
    if (!errSent) {
      errSent = true;
      console.error('Budget summary hata:', err.message);
      res.status(500).json({ message: 'DB hatası' });
    }
  }

  function checkDone() {
    completed++;
    if (completed === 4) sendResponse();
  }

  function sendResponse() {
    res.json({
      total_value: parseFloat((results.total_value || 0).toFixed(2)),
      consumed_cost: parseFloat((results.consumed_cost || 0).toFixed(2)),
      item_count: results.item_count || 0,
      costed_items: results.costed_items || 0,
      categories: results.categories || [],
      top_items: results.top_items || [],
    });
  }

  db.get(inventoryValueSql, [], (err, row) => {
    if (err) return fail(err);
    results.total_value = row?.total_value || 0;
    results.item_count = row?.item_count || 0;
    results.costed_items = row?.costed_items || 0;
    checkDone();
  });

  db.get(consumedSql, [], (err, row) => {
    if (err) return fail(err);
    results.consumed_cost = row?.consumed_cost || 0;
    checkDone();
  });

  db.all(categorySql, [], (err, rows) => {
    if (err) return fail(err);
    results.categories = (rows || []).map(r => ({
      category: r.category,
      value: parseFloat((r.value || 0).toFixed(2)),
      item_count: r.item_count,
    }));
    checkDone();
  });

  db.all(topItemsSql, [], (err, rows) => {
    if (err) return fail(err);
    results.top_items = (rows || []).map(r => ({
      id: r.id,
      name: r.name,
      unit: r.unit,
      current_amount: r.current_amount,
      unit_cost: r.unit_cost,
      total_value: parseFloat((r.total_value || 0).toFixed(2)),
    }));
    checkDone();
  });
});

// GET /api/budget/trend -> 6 aylık tüketim maliyeti
router.get('/trend', (req, res) => {
  const sql = `
    SELECT
      strftime('%Y-%m', l.created_at) as month,
      COALESCE(SUM(l.amount * i.unit_cost), 0) as cost
    FROM inventory_logs l
    JOIN inventory i ON l.inventory_id = i.id
    WHERE l.action = 'use'
      AND l.created_at >= datetime('now', '-180 days')
      AND i.unit_cost > 0
    GROUP BY strftime('%Y-%m', l.created_at)
    ORDER BY month ASC
  `;

  db.all(sql, [], (err, rows) => {
    if (err) return res.status(500).json({ message: 'DB hatası' });

    const today = new Date();
    const monthNames = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];

    const months = [];
    for (let i = 5; i >= 0; i--) {
      const dt = new Date(today.getFullYear(), today.getMonth() - i, 1);
      const yyyymm = `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}`;
      const found = rows.find(r => r.month === yyyymm);
      months.push({
        month: yyyymm,
        label: monthNames[dt.getMonth()],
        cost: found ? parseFloat(Number(found.cost).toFixed(2)) : 0,
      });
    }

    const total = months.reduce((s, m) => s + m.cost, 0);
    const avg = total / 6;

    res.json({
      trend: months,
      total_6mo: parseFloat(total.toFixed(2)),
      avg_monthly: parseFloat(avg.toFixed(2)),
    });
  });
});

module.exports = router;
