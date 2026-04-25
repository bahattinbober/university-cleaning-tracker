const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;
const ALLOWED_EMAIL_DOMAIN = '@pau.edu.tr';

// POST /api/auth/register
router.post('/register', async (req, res) => {
  const { name, email, password, employee_no, department } = req.body;

  if (!name || !email || !password || !employee_no || !department) {
    return res.status(400).json({ message: 'Tüm alanlar zorunludur' });
  }

  const emailLower = String(email).trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(emailLower)) {
    return res.status(400).json({ message: 'Geçerli bir e-posta giriniz' });
  }

  if (!emailLower.endsWith(ALLOWED_EMAIL_DOMAIN)) {
    return res
      .status(400)
      .json({ message: `Sadece ${ALLOWED_EMAIL_DOMAIN} uzantılı e-posta kabul edilir` });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 10);

    db.get(`SELECT id FROM users WHERE email = ?`, [emailLower], (checkErr, existingUser) => {
      if (checkErr) return res.status(500).json({ message: 'Sunucu hatası' });
      if (existingUser) {
        return res.status(409).json({ message: 'Bu e-posta zaten kayıtlı' });
      }

      db.run(
        `INSERT INTO users (name, email, password_hash, role, employee_no, department, approval_status)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          String(name).trim(),
          emailLower,
          passwordHash,
          'staff',
          String(employee_no).trim(),
          String(department).trim(),
          'pending',
        ],
        function (insertErr) {
          if (insertErr) {
            return res.status(500).json({ message: 'Kayıt oluşturulamadı' });
          }
          res
            .status(201)
            .json({ message: 'Kayıt alındı, admin onayı bekleniyor' });
        }
      );
    });
  } catch (err) {
    return res.status(500).json({ message: 'Sunucu hatası' });
  }
});

// POST /api/auth/login
router.post('/login', (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = String(email || '').trim().toLowerCase();

  if (!normalizedEmail || !password) {
    return res.status(400).json({ message: 'Email ve şifre gerekli' });
  }

  db.get(`SELECT * FROM users WHERE email = ?`, [normalizedEmail], async (err, user) => {
    if (err) return res.status(500).json({ message: 'Sunucu hatası' });
    if (!user) return res.status(401).json({ message: 'Geçersiz email veya şifre' });

    if (user.approval_status === 'pending') {
      return res.status(403).json({ message: 'Hesabınız henüz onaylanmadı' });
    }
    if (user.approval_status === 'rejected') {
      return res.status(403).json({ message: 'Hesabınız reddedildi' });
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return res.status(401).json({ message: 'Geçersiz email veya şifre' });

    const token = jwt.sign(
      { id: user.id, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  });
});

module.exports = router;
