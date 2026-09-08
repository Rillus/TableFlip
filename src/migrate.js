'use strict';

const { getPool, closePool } = require('./db');
const { createSchema } = require('./schema');

async function migrate() {
  const pool = getPool();
  await createSchema(pool);
}

if (require.main === module) {
  migrate()
    .then(async () => {
      // eslint-disable-next-line no-console
      console.log('Migration complete: restaurant_tables ready.');
      await closePool();
    })
    .catch(async (err) => {
      // eslint-disable-next-line no-console
      console.error('Migration failed:', err.message);
      await closePool();
      process.exit(1);
    });
}

module.exports = { migrate };
