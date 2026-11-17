# aria2 image

[aria2](https://aria2.github.io/) with the [AriaNg](https://github.com/mayswind/AriaNg)
web UI. nginx serves AriaNg and proxies `/jsonrpc` to aria2c on one port
(`8080`), so a single Service or ingress route covers the UI and the RPC it
calls. aria2 publishes no official image, and the third-party ones are pinned
to old Alpine releases.

- **Version:** `VERSION` holds `<aria2 version>-<image revision>`, which is also
  the image tag (`kr4t0n/aria2:1.37.0-2`). Bump the revision for every change
  that ships a new image (entrypoint, AriaNg, base); never re-push a tag, since
  nodes with `IfNotPresent` keep their cached copy. aria2 comes from Alpine's
  package (`aria2~<aria2 version>`; the build fails if the base no longer ships
  it). A `sha-<commit>` tag is pushed alongside. AriaNg is pinned in the
  `Dockerfile` by version and sha256. `1.37.0` is the first build, from before
  revisions.
- **Base image:** Alpine, pinned by digest. The image runs as uid/gid 65532 and
  works as any uid, or starts as root and drops to `PUID:PGID` (below); nginx
  writes only under `/tmp`.
- **Platforms:** `linux/amd64` and `linux/arm64` (arm64 under QEMU).
- **CI:** `.github/workflows/aria2-image.yml` builds on pull requests and pushes
  to Docker Hub on `main`. It needs the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
  repository secrets.

## Build locally

```bash
docker buildx build --load --build-arg ARIA2_VERSION="$(cut -d- -f1 VERSION)" -t aria2:dev .
docker run --rm -p 8080:8080 -e RPC_SECRET=change-me aria2:dev
# http://127.0.0.1:8080, then enter the secret under AriaNg Settings → RPC
```

## Running notes

- **`RPC_SECRET` is required.** The entrypoint exits without it, because
  nginx publishes the RPC on 8080. aria2c itself listens on `127.0.0.1:6800`
  only.
- **Arguments are aria2c options.** They override the image's
  [`aria2.conf`](./aria2.conf), e.g. `--max-connection-per-server=8`.
- **Paths:** downloads go to `/downloads`, and the session (unfinished
  downloads, restored on start) and DHT state to `/config`.
- **Users.** Started as a non-root uid (the default, 65532), nothing is chowned,
  so both paths must already be writable by it. Started as root, the entrypoint
  needs `PUID` (not 0) and `PGID`: it runs `chown -R PUID:PGID /config`, then
  starts nginx and aria2c as that user via `su-exec`, the linuxserver pattern.
  `/downloads` is never chowned, since it may be a volume other apps own; it must
  be writable by `PUID:PGID`. Root mode needs only the `CHOWN`, `SETUID` and
  `SETGID` capabilities.
- **AriaNg's default RPC address** is patched to the page's own host, port and
  scheme, so it works through a port-forward or an HTTPS ingress without
  editing. Settings saved in a browser override the default.
- **Shutdown:** aria2c runs as PID 1. On SIGTERM it saves the session and
  exits; nginx stops with the container.
- **Read-only root filesystem** works with a writable `/tmp`, e.g. an `emptyDir`.
