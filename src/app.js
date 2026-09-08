'use strict';

const path = require('path');
const express = require('express');
const repo = require('./tableRepository');
const { getPool } = require('./db');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

function parseId(value) {
  const id = Number.parseInt(value, 10);
  return Number.isInteger(id) && id > 0 ? id : null;
}

app.get('/health', async (_req, res) => {
  try {
    await getPool().query('SELECT 1');
    res.json({ status: 'ok', db: 'up' });
  } catch (err) {
    res.status(503).json({ status: 'error', db: 'down', error: err.message });
  }
});

app.get('/api/tables', async (_req, res, next) => {
  try {
    res.json(await repo.listTables());
  } catch (err) {
    next(err);
  }
});

app.get('/api/tables/:id', async (req, res, next) => {
  try {
    const id = parseId(req.params.id);
    if (!id) return res.status(400).json({ error: 'Invalid table id' });

    const table = await repo.getTable(id);
    if (!table) return res.status(404).json({ error: 'Table not found' });
    res.json(table);
  } catch (err) {
    next(err);
  }
});

app.post('/api/tables', async (req, res, next) => {
  try {
    const { name, seats } = req.body || {};
    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'A non-empty "name" is required' });
    }
    if (seats != null && (!Number.isInteger(seats) || seats < 1)) {
      return res.status(400).json({ error: '"seats" must be a positive integer' });
    }

    const table = await repo.createTable({ name: name.trim(), seats });
    res.status(201).json(table);
  } catch (err) {
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'A table with that name already exists' });
    }
    next(err);
  }
});

app.post('/api/tables/:id/flip', async (req, res, next) => {
  try {
    const id = parseId(req.params.id);
    if (!id) return res.status(400).json({ error: 'Invalid table id' });

    const table = await repo.flipTable(id);
    if (!table) return res.status(404).json({ error: 'Table not found' });
    res.json(table);
  } catch (err) {
    next(err);
  }
});

app.delete('/api/tables/:id', async (req, res, next) => {
  try {
    const id = parseId(req.params.id);
    if (!id) return res.status(400).json({ error: 'Invalid table id' });

    const removed = await repo.deleteTable(id);
    if (!removed) return res.status(404).json({ error: 'Table not found' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
