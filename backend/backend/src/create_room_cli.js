// src/create_room_cli.js
const readline = require('readline');
const db = require('./db'); // db.js ile aynı klasörde

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
    console.log('🏢 Yeni Oda Ekleme Aracı\n');

    const floor = await ask('Kat numarası (ör: 3): ');
    const roomNumber = await ask('Oda numarası (ör: 39): ');
    const extraDesc = await ask('Açıklama (opsiyonel, Enter geç): ');

    if (!floor || !roomNumber) {
      console.log('❌ Kat ve oda numarası zorunludur.');
      rl.close();
      process.exit(1);
    }

    // Oda kodu: K + kat + oda (ör: K339)
    const roomCode = `K${floor}${roomNumber}`;

    // Description metni
    const description =
      extraDesc && extraDesc.length > 0
        ? extraDesc
        : `Kat ${floor}, Oda ${roomNumber}`;

    // location_id şimdilik NULL (ileride lokasyon eklemek istersen değiştirilebilir)
    const sql = `
      INSERT INTO rooms (location_id, name, description)
      VALUES (?, ?, ?)
    `;

    db.run(sql, [null, roomCode, description], function (err) {
      if (err) {
        console.error('❌ Oda eklenirken hata:', err.message);
      } else {
        console.log('\n✅ Oda eklendi!');
        console.log('ID:', this.lastID);
        console.log('Oda kodu:', roomCode);
        console.log('Açıklama:', description);
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
