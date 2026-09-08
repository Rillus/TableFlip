#!/usr/bin/env bash
# Cloud Agent per-boot start command: bring MySQL up (idempotently), then run
# the TableFlip dev server attached in the foreground so its logs stay visible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/start-mysql.sh"

exec npm start
