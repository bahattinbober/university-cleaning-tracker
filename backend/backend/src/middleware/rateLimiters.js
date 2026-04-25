const rateLimit = require('express-rate-limit');

const FIFTEEN_MINUTES = 15 * 60 * 1000;

const loginLimiter = rateLimit({
  windowMs: FIFTEEN_MINUTES,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Çok fazla giriş denemesi yaptınız, lütfen 15 dakika sonra tekrar deneyin.' },
});

const generalLimiter = rateLimit({
  windowMs: FIFTEEN_MINUTES,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen 15 dakika sonra tekrar deneyin.' },
});

module.exports = { loginLimiter, generalLimiter };
