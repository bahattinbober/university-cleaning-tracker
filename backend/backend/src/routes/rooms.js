const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/rooms  -> tüm odalar
router.get('/', (req, res) => {
  const sql = `
    SELECT rooms.id,
           rooms.name,
           rooms.description,
           rooms.location_id,
           rooms.latitude,
           rooms.longitude,
           locations.name AS location_name
    FROM rooms
    LEFT JOIN locations ON rooms.location_id = locations.id
  `;
  db.all(sql, [], (err, rows) => {
    if (err) {
      console.error('Rooms list hata:', err.message);
      return res.status(500).json({ message: 'Sunucu hatası' });
    }
    res.json(rows);
  });
});

// POST /api/rooms -> sadece admin oda ekleyebilir
router.post('/', (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok (admin değil)' });
  }

  const { location_id, name, description, latitude, longitude } = req.body;
  const trimmedName = name ? String(name).trim() : '';

  if (!trimmedName) {
    return res.status(400).json({ message: 'name zorunlu' });
  }

  const lat = latitude != null ? Number(latitude) : null;
  const lng = longitude != null ? Number(longitude) : null;

  db.run(
    `INSERT INTO rooms (location_id, name, description, latitude, longitude)
     VALUES (?, ?, ?, ?, ?)`,
    [
      location_id || null,
      trimmedName,
      description ? String(description).trim() : null,
      lat,
      lng,
    ],
    function (err) {
      if (err) {
        console.error('Room ekleme hata:', err.message);
        return res.status(500).json({ message: 'Sunucu hatası' });
      }
      res.status(201).json({
        id: this.lastID,
        location_id: location_id || null,
        name: trimmedName,
        description: description ? String(description).trim() : null,
        latitude: lat,
        longitude: lng,
      });
    }
  );
});

module.exports = router;
