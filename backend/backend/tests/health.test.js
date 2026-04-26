const request = require('supertest');
const app = require('../src/index');

describe('GET /api/health', () => {
  it('200 ve { status: "ok" } döner', async () => {
    const res = await request(app).get('/api/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
