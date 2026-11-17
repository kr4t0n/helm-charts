#!/bin/sh
# Starts nginx in the background, then becomes aria2c, so aria2c is PID 1 and
# receives SIGTERM directly. Arguments are extra aria2c options.
set -eu

# nginx publishes the RPC on 8080, so it never runs without a secret.
if [ -z "${RPC_SECRET:-}" ]; then
  echo "entrypoint: RPC_SECRET is required" >&2
  exit 1
fi

# aria2c refuses to start when its input-file is missing.
touch /config/aria2.session

nginx -e stderr &
exec aria2c --conf-path=/etc/aria2/aria2.conf --rpc-secret="$RPC_SECRET" "$@"
