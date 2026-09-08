'use strict';

const { getPool, closePool } = require('../../src/db');
const { resetSchema } = require('../../src/schema');

async function resetDatabase() {
  const pool = getPool();
  await resetSchema(pool);
}

module.exports = { resetDatabase, getPool, closePool };
