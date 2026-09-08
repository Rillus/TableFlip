'use strict';

const app = require('./app');
const config = require('./config');
const { migrate } = require('./migrate');

async function start() {
  await migrate();
  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`TableFlip listening on http://localhost:${config.port}`);
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start TableFlip:', err.message);
  process.exit(1);
});
