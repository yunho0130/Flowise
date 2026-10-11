#!/bin/sh
set -eu

# The pre-upgrade Railway volume may contain root-owned SQLite, logs and storage.
# Fix ownership after the volume is mounted, then run the app as an unprivileged user.
DATA_DIR=/opt/railway/.flowise
if [ -d "$DATA_DIR" ]; then
  chown -R node:node "$DATA_DIR"
fi

exec su-exec node "$@"
