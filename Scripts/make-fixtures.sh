#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/Fixtures"

sqlite3 "$root/Fixtures/empty.sqlite" "VACUUM;"

sqlite3 "$root/Fixtures/users.sqlite" <<'SQL'
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT
);
CREATE VIEW active_users AS SELECT * FROM users;
INSERT INTO users (name, email) VALUES
  ('Ada', 'ada@example.com'),
  ('Alan', 'alan@example.com'),
  ('Alonzo', 'alonzo@example.com');
SQL

sqlite3 "$root/Fixtures/no_pk.sqlite" <<'SQL'
CREATE TABLE notes (note TEXT);
INSERT INTO notes VALUES ('hello');
SQL

sqlite3 "$root/Fixtures/json.sqlite" <<'SQL'
CREATE TABLE events (id INTEGER PRIMARY KEY, payload TEXT);
INSERT INTO events (payload) VALUES ('{"ok":true,"n":1}');
SQL

sqlite3 "$root/Fixtures/nulls.sqlite" <<'SQL'
CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, email TEXT);
INSERT INTO people (name, email) VALUES ('Ada', NULL), ('Alan', '');
SQL

cols=""
names=""
values=""
for i in $(seq 1 79); do
  cols="$cols, c$i TEXT"
  names="$names, c$i"
  values="$values, 'x'"
done
sqlite3 "$root/Fixtures/wide.sqlite" "CREATE TABLE wide (id INTEGER PRIMARY KEY$cols); INSERT INTO wide (id$names) VALUES (1$values);"

sqlite3 "$root/Fixtures/ten_thousand.sqlite" <<'SQL'
CREATE TABLE numbers (id INTEGER PRIMARY KEY, n INTEGER NOT NULL);
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 10000)
INSERT INTO numbers (id, n) SELECT n, n FROM seq;
SQL

echo "Wrote fixtures in $root/Fixtures"
