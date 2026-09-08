'use strict';

require('dotenv').config();

const isTest = process.env.NODE_ENV === 'test';

function toInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

const config = {
  port: toInt(process.env.PORT, 3000),
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: toInt(process.env.DB_PORT, 3306),
    user: process.env.DB_USER || 'tableflip',
    password: process.env.DB_PASSWORD || 'tableflip',
    // The test run targets a separate database so it can be reset safely.
    database: isTest
      ? process.env.TEST_DB_NAME || 'tableflip_test'
      : process.env.DB_NAME || 'tableflip',
  },
};

module.exports = config;
