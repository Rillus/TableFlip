'use strict';

const repo = require('../src/tableRepository');
const { resetDatabase, closePool } = require('./helpers/db');

beforeEach(async () => {
  await resetDatabase();
});

afterAll(async () => {
  await closePool();
});

describe('tableRepository', () => {
  test('createTable persists a table and returns it with defaults', async () => {
    const created = await repo.createTable({ name: 'Window 1', seats: 4 });

    expect(created).toMatchObject({
      name: 'Window 1',
      seats: 4,
      status: 'available',
    });
    expect(created.id).toBeGreaterThan(0);
  });

  test('createTable defaults seats to 2 when omitted', async () => {
    const created = await repo.createTable({ name: 'Bar stool' });
    expect(created.seats).toBe(2);
  });

  test('listTables returns all tables ordered by id', async () => {
    await repo.createTable({ name: 'T1', seats: 2 });
    await repo.createTable({ name: 'T2', seats: 6 });

    const tables = await repo.listTables();
    expect(tables).toHaveLength(2);
    expect(tables.map((t) => t.name)).toEqual(['T1', 'T2']);
  });

  test('getTable returns null for an unknown id', async () => {
    expect(await repo.getTable(999)).toBeNull();
  });

  test('flipTable toggles available -> occupied -> available', async () => {
    const created = await repo.createTable({ name: 'Corner', seats: 2 });

    const flipped = await repo.flipTable(created.id);
    expect(flipped.status).toBe('occupied');

    const flippedBack = await repo.flipTable(created.id);
    expect(flippedBack.status).toBe('available');
  });

  test('flipTable returns null for an unknown id', async () => {
    expect(await repo.flipTable(12345)).toBeNull();
  });

  test('deleteTable removes a table and reports success', async () => {
    const created = await repo.createTable({ name: 'Patio', seats: 8 });

    expect(await repo.deleteTable(created.id)).toBe(true);
    expect(await repo.getTable(created.id)).toBeNull();
    expect(await repo.deleteTable(created.id)).toBe(false);
  });
});
