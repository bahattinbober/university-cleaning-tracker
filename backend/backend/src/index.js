require('dotenv').config();

const express = require('express');
const cors = require('cors');
const db = require('./db'); // veritabanı bağlantısı

const authRoutes = require('./routes/auth');
const roomsRoutes = require('./routes/rooms');
const cleaningRoutes = require('./routes/cleaning');
const adminRoutes = require('./routes/admin');
const tasksRoutes = require('./routes/tasks');
const authMiddleware = require('./middleware/authMiddleware');

if (!process.env.JWT_SECRET) {
  console.error('❌ JWT_SECRET env değişkeni eksik. Sunucu başlatılamıyor.');
  process.exit(1);
}

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : [];

const app = express();
app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error(`CORS: '${origin}' origin'ine izin verilmiyor`));
  },
}));
app.use(express.json());

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Tüm kullanıcıları listele — yalnızca admin erişebilir
app.get('/api/users', authMiddleware, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Yetkiniz yok (admin değil)' });
  }

  const sql = `SELECT id, name, email, role FROM users ORDER BY id`;

  db.all(sql, [], (err, rows) => {
    if (err) {
      console.error('❌ Kullanıcı listesi hatası:', err.message);
      return res
        .status(500)
        .json({ message: 'Kullanıcı listesi alınırken bir hata oluştu' });
    }

    res.json(rows);
  });
});


// Auth (login)
app.use('/api/auth', authRoutes);

// Rooms -> token zorunlu
app.use('/api/rooms', authMiddleware, roomsRoutes);

// Cleaning -> token zorunlu
app.use('/api/cleaning', authMiddleware, cleaningRoutes);
app.use('/api/cleaning-logs', authMiddleware, cleaningRoutes);
app.use('/api/admin', authMiddleware, adminRoutes);
app.use('/api/tasks', authMiddleware, tasksRoutes);

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
