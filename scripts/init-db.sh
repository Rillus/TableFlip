#!/usr/bin/env bash
# Idempotently create the TableFlip databases and application user.
# Uses the local root socket (via sudo), which is how a fresh MySQL install
# authenticates the root account on Debian/Ubuntu.
set -euo pipefail

DB_USER="${DB_USER:-tableflip}"
DB_PASSWORD="${DB_PASSWORD:-tableflip}"
DB_NAME="${DB_NAME:-tableflip}"
TEST_DB_NAME="${TEST_DB_NAME:-tableflip_test}"

sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE DATABASE IF NOT EXISTS \`${TEST_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`${TEST_DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${TEST_DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

echo "TableFlip databases and user are ready."
