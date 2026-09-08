# TableFlip

A small MySQL-backed restaurant table manager. Add tables, then **flip** them
between `available` and `occupied`. Built with Node.js, Express and `mysql2`.

## Requirements

- Node.js 22+
- MySQL 8.0+

## Getting started

```bash
# 1. Install dependencies
npm install

# 2. Configure the database connection
cp .env.example .env   # edit if your MySQL credentials differ

# 3. Create the schema
npm run migrate

# 4. Start the app
npm start
# -> TableFlip listening on http://localhost:3000
```

The app connects to MySQL over TCP. The defaults (see `.env.example`) expect a
database named `tableflip` reachable at `127.0.0.1:3306` with user/password
`tableflip`/`tableflip`.

## Database setup

```sql
CREATE DATABASE tableflip;
CREATE DATABASE tableflip_test;
CREATE USER 'tableflip'@'localhost' IDENTIFIED WITH mysql_native_password BY 'tableflip';
GRANT ALL PRIVILEGES ON tableflip.* TO 'tableflip'@'localhost';
GRANT ALL PRIVILEGES ON tableflip_test.* TO 'tableflip'@'localhost';
FLUSH PRIVILEGES;
```

## API

| Method | Path                   | Description                              |
| ------ | ---------------------- | ---------------------------------------- |
| GET    | `/health`              | Liveness + database reachability check   |
| GET    | `/api/tables`          | List all tables                          |
| POST   | `/api/tables`          | Create a table `{ name, seats }`         |
| GET    | `/api/tables/:id`      | Fetch a single table                     |
| POST   | `/api/tables/:id/flip` | Toggle `available` &harr; `occupied`     |
| DELETE | `/api/tables/:id`      | Delete a table                           |

## Testing

Tests run against the `tableflip_test` database and reset the schema between
cases, so they need a live MySQL server.

```bash
npm test
```

## Cloud Agent environment

The Cloud Agent environment boots from a base snapshot that already has MySQL 8.0
and Node.js 22 installed. On each boot:

- `install`: `npm ci`
- `start`: `scripts/start-mysql.sh` starts MySQL, waits for readiness, and
  idempotently creates the `tableflip`/`tableflip_test` databases and app user.
- the dev server runs `npm start` and listens on port `3000`.

`scripts/start-mysql.sh` and `scripts/init-db.sh` are safe to run locally too if
you want to reproduce the same startup on your own machine.
