const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/tasks/my-scheduled -> giriş yapan kullanıcının bekleyen planlı görevleri
router.get('/my-scheduled', (req, res) => {
  const userId = req.user.id;

  const sql = `
    SELECT
      st.id,
      st.room_id,
      st.title,
      st.description,
      st.scheduled_for,
      st.assigned_user_id,
      st.status,
      st.created_at,
      r.name AS room_name
    FROM scheduled_tasks st
    LEFT JOIN rooms r ON r.id = st.room_id
    WHERE st.status = 'pending' AND st.assigned_user_id = ?
    ORDER BY datetime(st.scheduled_for) ASC
  `;

  db.all(sql, [userId], (err, rows) => {
    if (err) return res.status(500).json({ message: 'Sunucu hatası' });
    return res.json(rows);
  });
});

module.exports = router;
