// src/create_user_cli.js
const readline = require('readline');
const bcrypt = require('bcrypt');
const db = require('./db'); // db.js ile aynı klasörde olduğu için ./db yeterli

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function ask(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve(answer.trim()));
  });
}

async function main() {
  try {
    console.log('👤 Yeni kullanıcı ekleme aracı\n');

    const name = await ask('İsim Soyisim: ');
    const email = await ask('Email: ');
    const plainPassword = await ask('Şifre: ');
    const role = await ask('Rol (admin/staff): ');

    if (!name || !email || !plainPassword || !role) {
      console.log('❌ Tüm alanları doldurman gerekiyor.');
      rl.close();
      process.exit(1);
    }

    const passwordHash = await bcrypt.hash(plainPassword, 10);

    const sql = `
      INSERT INTO users (name, email, password_hash, role)
      VALUES (?, ?, ?, ?)
    `;

    db.run(sql, [name, email, passwordHash, role], function (err) {
      if (err) {
        console.error('❌ Kullanıcı eklenirken hata:', err.message);
      } else {
        console.log('\n✅ Kullanıcı eklendi!');
        console.log('ID:', this.lastID);
        console.log('Ad:', name);
        console.log('Email:', email);
        console.log('Rol:', role);
      }
      rl.close();
      process.exit(0);
    });
  } catch (err) {
    console.error('❌ Hata:', err);
    rl.close();
    process.exit(1);
  }
}

main();
