const request = require('supertest');
const app = require('../src/index');
const db = require('../src/db');

let adminToken;
let staffToken;
let staffEmail;

// DB'de kullanıcıyı onaylamak için promisify yardımcısı
function dbRun(sql, params) {
  return new Promise((resolve, reject) =>
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve(this);
    })
  );
}

beforeAll(async () => {
  // Admin login
  const adminRes = await request(app).post('/api/auth/login').send({
    email: process.env.ADMIN_DEFAULT_EMAIL,
    password: process.env.ADMIN_DEFAULT_PASSWORD,
  });
  adminToken = adminRes.body.token;

  // Staff kullanıcı oluştur, approve et, login ol
  staffEmail = global.randomEmail('users-staff');
  await request(app).post('/api/auth/register').send({
    name: 'Staff Tester',
    email: staffEmail,
    password: 'staffpass123',
    employee_no: 'EMP-USR-01',
    department: 'Test',
  });

  await dbRun(`UPDATE users SET approval_status = 'approved' WHERE email = ?`, [staffEmail]);

  const staffRes = await request(app).post('/api/auth/login').send({
    email: staffEmail,
    password: 'staffpass123',
  });
  staffToken = staffRes.body.token;
});

afterAll((done) => {
  db.run(`DELETE FROM users WHERE email = ?`, [staffEmail], () => done());
});

// ---------------------------------------------------------------------------
describe('GET /api/users', () => {
  it('1 - Token olmadan → 401, "Token gerekli"', async () => {
    const res = await request(app).get('/api/users');
    expect(res.statusCode).toBe(401);
    expect(res.body.message).toMatch(/token gerekli/i);
  });

  it('2 - Geçersiz token → 401', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer bu.gecersiz.bir.token');
    expect(res.statusCode).toBe(401);
  });

  it('3 - Staff token ile → 403, "Yetkiniz yok"', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${staffToken}`);
    expect(res.statusCode).toBe(403);
    expect(res.body.message).toMatch(/yetki/i);
  });

  it('4 - Admin token ile → 200, dizi içinde admin@example.com var', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    const emails = res.body.map((u) => u.email);
    expect(emails).toContain(process.env.ADMIN_DEFAULT_EMAIL);
  });
});
