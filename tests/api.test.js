'use strict';

const request = require('supertest');
const app = require('../src/app');
const { resetDatabase, closePool } = require('./helpers/db');

beforeEach(async () => {
  await resetDatabase();
});

afterAll(async () => {
  await closePool();
});

describe('TableFlip API', () => {
  test('GET /health reports the database is reachable', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up' });
  });

  test('GET /api/tables starts empty', async () => {
    const res = await request(app).get('/api/tables');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('POST /api/tables creates a table', async () => {
    const res = await request(app)
      .post('/api/tables')
      .send({ name: 'Booth 1', seats: 4 });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ name: 'Booth 1', seats: 4, status: 'available' });
    expect(res.body.id).toBeGreaterThan(0);
  });

  test('POST /api/tables rejects a missing name with 400', async () => {
    const res = await request(app).post('/api/tables').send({ seats: 4 });
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('POST /api/tables rejects a duplicate name with 409', async () => {
    await request(app).post('/api/tables').send({ name: 'Unique', seats: 2 });
    const res = await request(app).post('/api/tables').send({ name: 'Unique', seats: 2 });
    expect(res.status).toBe(409);
  });

  test('POST /api/tables/:id/flip toggles the status', async () => {
    const created = await request(app)
      .post('/api/tables')
      .send({ name: 'Flip me', seats: 2 });
    const id = created.body.id;

    const flip = await request(app).post(`/api/tables/${id}/flip`);
    expect(flip.status).toBe(200);
    expect(flip.body.status).toBe('occupied');

    const flipBack = await request(app).post(`/api/tables/${id}/flip`);
    expect(flipBack.body.status).toBe('available');
  });

  test('POST /api/tables/:id/flip returns 404 for unknown id', async () => {
    const res = await request(app).post('/api/tables/9999/flip');
    expect(res.status).toBe(404);
  });

  test('DELETE /api/tables/:id removes the table', async () => {
    const created = await request(app)
      .post('/api/tables')
      .send({ name: 'Temp', seats: 2 });
    const id = created.body.id;

    const del = await request(app).delete(`/api/tables/${id}`);
    expect(del.status).toBe(204);

    const after = await request(app).get(`/api/tables/${id}`);
    expect(after.status).toBe(404);
  });
});
