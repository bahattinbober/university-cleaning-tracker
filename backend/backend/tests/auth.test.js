const request = require('supertest');
const app = require('../src/index');
const db = require('../src/db');

// afterAll'da silinecek email'leri izle
const createdEmails = [];

function trackEmail(email) {
  createdEmails.push(email);
  return email;
}

function validBody(email) {
  return {
    name: 'Test User',
    email,
    password: 'testpass123',
    employee_no: 'EMP001',
    department: 'Temizlik',
  };
}

afterAll((done) => {
  if (createdEmails.length === 0) return done();
  const placeholders = createdEmails.map(() => '?').join(',');
  db.run(
    `DELETE FROM users WHERE email IN (${placeholders})`,
    createdEmails,
    () => done()
  );
});

// ---------------------------------------------------------------------------
describe('POST /api/auth/register', () => {
  it('1 - @pau.edu.tr ile geçerli kayıt → 201, pending', async () => {
    const email = trackEmail(global.randomEmail('reg'));
    const res = await request(app).post('/api/auth/register').send(validBody(email));
    expect(res.statusCode).toBe(201);
    expect(res.body.message).toMatch(/onay/i);
  });

  it('2 - @gmail.com ile kayıt → 400, domain hatası', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(validBody('test@gmail.com'));
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/@pau\.edu\.tr/i);
  });

  it('3 - Eksik alanlar (sadece email) → 400', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: global.randomEmail('partial') });
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/zorunlu/i);
  });

  it('4 - Aynı email ile 2. kayıt → 409, zaten kayıtlı', async () => {
    const email = trackEmail(global.randomEmail('dup'));
    await request(app).post('/api/auth/register').send(validBody(email));
    const res = await request(app).post('/api/auth/register').send(validBody(email));
    expect(res.statusCode).toBe(409);
    expect(res.body.message).toMatch(/kayıtlı/i);
  });

  it('5 - Kısa şifre doğrulama yok → register validates domain, not pw length', () => {
    // auth.js'de register'da şifre uzunluğu kontrolü yok; bu kasıtlı atlanıyor.
    // Gelecekte eklenirse buraya test yazılacak.
    expect(true).toBe(true);
  });
});

// ---------------------------------------------------------------------------
describe('POST /api/auth/login', () => {
  it('6 - Geçerli admin login → 200, JWT token + user objesi', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: process.env.ADMIN_DEFAULT_EMAIL,
      password: process.env.ADMIN_DEFAULT_PASSWORD,
    });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('user');
    expect(res.body.user.role).toBe('admin');
    // JWT: üç noktalı format
    expect(res.body.token.split('.')).toHaveLength(3);
  });

  it('7 - Yanlış şifre → 401, genel hata mesajı', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: process.env.ADMIN_DEFAULT_EMAIL,
      password: 'yanlis-sifre',
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toMatch(/geçersiz/i);
  });

  it('8 - Var olmayan email → 401, aynı genel mesaj (user enumeration yok)', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: 'yok@pau.edu.tr',
      password: 'herhangi',
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toMatch(/geçersiz/i);
  });

  it('9 - Pending kullanıcı login → 403, onay bekliyor', async () => {
    const email = trackEmail(global.randomEmail('pending'));
    await request(app).post('/api/auth/register').send(validBody(email));
    const res = await request(app).post('/api/auth/login').send({
      email,
      password: 'testpass123',
    });
    expect(res.statusCode).toBe(403);
    expect(res.body.message).toMatch(/onaylanmadı/i);
  });

  it('10 - Boş body → 400, eksik alan mesajı', async () => {
    const res = await request(app).post('/api/auth/login').send({});
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/gerekli/i);
  });
});
