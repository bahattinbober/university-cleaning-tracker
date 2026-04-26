const path = require('path');
const fs = require('fs');

// .env.test varsa onu yükle, yoksa normal .env
const envTest = path.join(__dirname, '..', '.env.test');
const envDefault = path.join(__dirname, '..', '.env');

if (fs.existsSync(envTest)) {
  require('dotenv').config({ path: envTest });
} else {
  require('dotenv').config({ path: envDefault });
}

// Her test dosyası için rastgele benzersiz email üretici
global.randomEmail = (prefix = 'test') =>
  `${prefix}-${Date.now()}-${Math.floor(Math.random() * 9999)}@pau.edu.tr`;
