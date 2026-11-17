#!/bin/sh
# Starts nginx in the background, then becomes aria2c, so aria2c is PID 1 and
# receives SIGTERM directly. Arguments are extra aria2c options.
set -eu

# nginx publishes the RPC on 8080, so it never runs without a secret.
if [ -z "${RPC_SECRET:-}" ]; then
  echo "entrypoint: RPC_SECRET is required" >&2
  exit 1
fi

# Started as root (the linuxserver pattern): hand /config to PUID:PGID, then run
# nginx and aria2c as that user. /downloads is never chowned; it may be a volume
# other apps own.
run=
if [ "$(id -u)" = 0 ]; then
  if [ -z "${PUID:-}" ] || [ -z "${PGID:-}" ] || [ "$PUID" = 0 ]; then
    echo "entrypoint: started as root, so set PUID (not 0) and PGID" >&2
    exit 1
  fi
  chown -R "$PUID:$PGID" /config
  run="su-exec $PUID:$PGID"
fi

# aria2c refuses to start when its input-file is missing.
$run touch /config/aria2.session

$run nginx -e stderr &
exec $run aria2c --conf-path=/etc/aria2/aria2.conf --rpc-secret="$RPC_SECRET" "$@"
