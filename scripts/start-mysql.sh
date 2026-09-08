#!/usr/bin/env bash
# Bring MySQL up for a Cloud Agent boot and make sure the TableFlip databases
# and user exist. Safe to run repeatedly: it detects an already-running server
# and only creates databases/users that are missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure the runtime directory for the unix socket exists.
sudo install -d -o mysql -g mysql /var/run/mysqld

if ! sudo mysqladmin ping --silent >/dev/null 2>&1; then
  echo "Starting MySQL..."
  sudo service mysql start
else
  echo "MySQL already running."
fi

# Wait for the server to accept connections.
for _ in $(seq 1 30); do
  if sudo mysqladmin ping --silent >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! sudo mysqladmin ping --silent >/dev/null 2>&1; then
  echo "MySQL did not become ready in time." >&2
  exit 1
fi

bash "${SCRIPT_DIR}/init-db.sh"

echo "MySQL is ready."
