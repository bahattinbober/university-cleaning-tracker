const request = require('supertest');
const app = require('../src/index');
const db = require('../src/db');

const INITIAL_PW = 'initpass123';
const NEW_PW = 'newpass456';

let staffEmail;
let staffToken;

function dbRun(sql, params) {
  return new Promise((resolve, reject) =>
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve(this);
    })
  );
}

beforeAll(async () => {
  staffEmail = global.randomEmail('chpw-staff');

  await request(app).post('/api/auth/register').send({
    name: 'PW Tester',
    email: staffEmail,
    password: INITIAL_PW,
    employee_no: 'EMP-PW-01',
    department: 'Test',
  });

  await dbRun(`UPDATE users SET approval_status = 'approved' WHERE email = ?`, [staffEmail]);

  const loginRes = await request(app).post('/api/auth/login').send({
    email: staffEmail,
    password: INITIAL_PW,
  });
  staffToken = loginRes.body.token;
});

afterAll((done) => {
  db.run(`DELETE FROM users WHERE email = ?`, [staffEmail], () => done());
});

// ---------------------------------------------------------------------------
describe('PUT /api/auth/change-password', () => {
  it('1 - Token olmadan → 401', async () => {
    const res = await request(app).put('/api/auth/change-password').send({
      oldPassword: INITIAL_PW,
      newPassword: NEW_PW,
    });
    expect(res.statusCode).toBe(401);
  });

  it('2 - Yanlış eski şifre → 401, "Eski şifre yanlış"', async () => {
    const res = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ oldPassword: 'yanlis-sifre', newPassword: NEW_PW });
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toMatch(/eski şifre yanlış/i);
  });

  it('3 - Yeni şifre çok kısa (5 karakter) → 400, "en az 8 karakter"', async () => {
    const res = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ oldPassword: INITIAL_PW, newPassword: 'kisa' });
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/8 karakter/i);
  });

  it('4 - Eski === yeni → 400, "farklı olmalı"', async () => {
    const res = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ oldPassword: INITIAL_PW, newPassword: INITIAL_PW });
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/farklı/i);
  });

  it('5 - Eksik alanlar (sadece oldPassword) → 400', async () => {
    const res = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ oldPassword: INITIAL_PW });
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/zorunlu/i);
  });

  it('6 - Geçerli şifre değişimi → 200; eski çalışmaz, yeni çalışır', async () => {
    // Şifreyi değiştir
    const changeRes = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ oldPassword: INITIAL_PW, newPassword: NEW_PW });
    expect(changeRes.statusCode).toBe(200);

    // Eski şifre artık 401 vermeli
    const oldLoginRes = await request(app).post('/api/auth/login').send({
      email: staffEmail,
      password: INITIAL_PW,
    });
    expect(oldLoginRes.statusCode).toBe(401);

    // Yeni şifre 200 vermeli
    const newLoginRes = await request(app).post('/api/auth/login').send({
      email: staffEmail,
      password: NEW_PW,
    });
    expect(newLoginRes.statusCode).toBe(200);
    expect(newLoginRes.body).toHaveProperty('token');
  });
});
