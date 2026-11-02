# dispatcharr

[Dispatcharr](https://github.com/Dispatcharr/Dispatcharr) manages IPTV
playlists and EPG data, proxies the streams, and shows up in Plex, Emby or
Jellyfin as an HDHomeRun tuner. This chart runs the upstream image's
**all-in-one** mode: one container with nginx, uWSGI (Django), daphne, Celery,
Redis and Postgres, and all state on one volume at `/data`. It is built on the
[`common`](../common) library chart.

## Prerequisites

A Secret in the release's namespace with the password for the image's internal
Postgres, under the key `postgres-password` (`postgres.passwordKey`). The chart
never creates one, and the container refuses to start if the value is empty or
`secret`, the image's default. For example:

```bash
umask 077
openssl rand -base64 24 | tr -d '\n' > postgres-password
kubectl -n media create secret generic dispatcharr-postgres \
  --from-file=postgres-password=postgres-password
rm postgres-password
```

The entrypoint sets the database role's password from the Secret on every
start, so changing the Secret and restarting the pod rotates it.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install dispatcharr kr4t0n/dispatcharr -n media \
  --set postgres.existingSecret=dispatcharr-postgres
```

### Create the admin

Dispatcharr always requires a login. The first visit creates the admin, and by
default only a client at `127.0.0.1` may do that (`dispatcharr.setupAllowedIP`).
Do it through a port-forward, right after the install:

```bash
kubectl -n media port-forward deploy/dispatcharr 9191:9191
# http://127.0.0.1:9191/
```

`GET /api/accounts/initialize-superuser/` reports the client IP Dispatcharr
sees. If it's `::1`, set `dispatcharr.setupAllowedIP` to `::1` and try again. Once an admin exists, the
setup endpoint is closed whatever this value says.

### Add it to Plex

Dispatcharr has no network discovery, so add the tuner by address. It serves
the tuner under `/hdhr`: `http://dispatcharr.<namespace>.svc:9191/hdhr`. The
XMLTV guide is at `http://dispatcharr.<namespace>.svc:9191/output/epg`.

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `image.repository` | Image | `ghcr.io/dispatcharr/dispatcharr` |
| `image.tag` | Tag and index digest (amd64 and arm64) | the 0.33.0 index, by digest |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `postgres.existingSecret` | Secret holding the Postgres password | **required** |
| `postgres.passwordKey` | Its key | `postgres-password` |
| `dispatcharr.setupAllowedIP` | The only client IP that may create the first admin | `127.0.0.1` |
| `dispatcharr.trustedProxies` | Peers whose `X-Real-IP` / `X-Forwarded-*` headers are trusted (`none` for no one) | `127.0.0.1/32` |
| `strategy` | Update strategy | `{type: Recreate}` |
| `service.type` / `service.port` | Service, and nginx's port | `ClusterIP` / `9191` |
| `persistence.volumes.data.size` | The `/data` volume | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `securityContext` | Container security context, verbatim | see [Security](#security) |
| `probes.{startup,readiness,liveness}` | Probes, verbatim | see [Probes](#probes) |
| `resources` | Requests and limits | `{}` |
| `extraEnvs` | Extra env vars, e.g. `TZ`, `UWSGI_WORKERS`, `CELERY_MAX_WORKERS` | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the rest (`nodeSelector`,
`tolerations`, `affinity`, `extraVolumes`, …).

## What the chart sets

These are rendered by the chart's own deployment template, outside
`extraEnvs`, so a release that sets its own `extraEnvs` can't drop them:

| Env var | Value | Why |
|---------|-------|-----|
| `DISPATCHARR_ENV` | `aio` | The chart runs all-in-one only. |
| `DISPATCHARR_PORT` | `service.port` | nginx's port. Also stops the Service link var `DISPATCHARR_PORT=tcp://…` that a Service named `dispatcharr` would inject. |
| `POSTGRES_PORT` / `REDIS_PORT` | `5432` / `6379` | Same, for Services named `postgres` or `redis` in the namespace, whose link vars would stop the start. |
| `DISPATCHARR_SETUP_ALLOWED_IP` | `dispatcharr.setupAllowedIP` | Until the admin exists, any client Dispatcharr counts as local (every pod) could create it. |
| `DISPATCHARR_TRUSTED_PROXIES` | `dispatcharr.trustedProxies` | By default Dispatcharr trusts client-IP headers from any private address, so a pod could claim to be `127.0.0.1`. |
| `POSTGRES_PASSWORD` | from `postgres.existingSecret`, not optional | The internal Postgres listens on every interface, and its role is a superuser. |

The chart fails to render when:

- `postgres.existingSecret`, `postgres.passwordKey`,
  `dispatcharr.setupAllowedIP` or `dispatcharr.trustedProxies` is empty;
- `extraEnvs` names one of the variables above, or `DISPATCHARR_DEBUG`, which
  also turns Redis's protected mode off;
- `existingSecret.enabled` is set: an `envFrom` Secret could carry any of those
  variables;
- `command` or `args` is set.

The container's command checks the password, then `exec`s the image's
entrypoint, which stays PID 1.

`trustedProxies: 127.0.0.1/32` means Dispatcharr ignores an ingress
controller's forwarded headers. It then logs the controller's pod IP as the
client, and links it builds for requests through an ingress use `http://` and
the request's Host. Links built for in-cluster clients that use the Service
address are right.

## How it works

- **Start.** The entrypoint runs as root: it creates the user `dispatch`
  (`PUID`/`PGID`, default 1000), writes its env into `/etc`, chowns `/data`
  and `/app`, then starts Postgres and uWSGI as that user. uWSGI starts Redis,
  Celery (workers and beat) and daphne. nginx's master process stays root and
  its workers run as `dispatch`. Django's migrations run on every start.
- **`/data`** holds everything: the Postgres data (`db/`), the Django secret
  key (`jwt`), logos, caches, M3U and EPG files, uploads, plugins, recordings,
  backups and logs. The EPG matcher downloads its model
  (`sentence-transformers/all-MiniLM-L6-v2`) from Hugging Face into
  `/data/models` on first use; set `DISABLE_ML_DOWNLOADS=true` in `extraEnvs`
  to stop that.
- **Backups.** By default Dispatcharr writes a `pg_dump` zip to
  `/data/backups` daily at 03:00 and keeps 3. They sit on the same volume, so back the volume up as
  well.

## Probes

All three call `GET /api/core/version/` through nginx. It needs no login and
doesn't touch the database.

| Probe | Timing |
|-------|--------|
| startup | every 10 s, up to 15 minutes (first start: `initdb` and migrations; a Postgres major bump: `pg_upgrade`) |
| readiness | every 10 s, 3 failures |
| liveness | every 20 s, 6 failures |

## Upgrades

- Bump `appVersion` and `image.tag` together: the version and the new index
  digest from ghcr.io.
- The entrypoint migrates the database on start, and an older image doesn't
  undo that. Snapshot the volume before a bump you may want to undo.
- When a new image ships a newer Postgres major, the entrypoint runs
  `pg_upgrade` on `/data/db`. If the image lacks the old major's binaries, it
  first installs them with `apt`, so the pod needs internet access for that
  start.
- Upstream fixes security issues only in its latest release, so keep up.

## What stays fixed

These keep a release upgrading in place:

- The Deployment, Service and PVC are named after the release
  (`fullnameOverride` changes that), and the PVC keeps that name through
  `claimNameSuffix: ""`.
- The selector is `app: <release>`.

## Security

- **Root at start.** The image sets no user, and its entrypoint needs root, so
  the chart sets neither `runAsNonRoot` nor `readOnlyRootFilesystem`. The
  container drops all capabilities and adds back only what the entrypoint uses:
  `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID` and `KILL`. It
  disallows privilege escalation and uses seccomp `RuntimeDefault`. There is no
  `fsGroup`: the entrypoint chowns what it needs, and `fsGroup` would walk the
  whole volume on every start.
- **Ports in the pod.** The Service exposes nginx's port only, but these also
  listen on every pod interface: uWSGI's HTTP port 5656 and daphne's 8001 (both
  serve Django without nginx in front), and Postgres's 5432 (password from the
  Secret). Redis has no password and accepts loopback clients only, through
  its protected mode.
- **No login on Plex's endpoints**, by design: `/hdhr/*`, the streams under
  `/proxy/ts/stream/`, `/output/m3u` and `/output/epg`. Only Dispatcharr's
  network allowlists (Settings → Network Access) gate them. By default the
  HDHomeRun endpoints, M3U and EPG are open to private addresses, every pod
  included, and streams to everyone.
- **Provider URLs.** The lineup and the default M3U point at Dispatcharr's own
  proxy, so clients don't see the provider's stream URLs. But
  `/output/m3u?direct=true` returns them to anyone the M3U/EPG allowlist
  admits, and a channel on the Redirect stream profile answers with a redirect
  to the provider's URL.
- **Admins run code.** Plugins (installed by an admin, from a zip or a plugin
  repository) and custom stream profiles run as UID 1000 in the pod, with the
  app's database access.
- The pod mounts the service account token: `common` has no setting for it.
- The chart adds no NetworkPolicy.

Not included: the modular mode (separate web, Celery, Postgres and Redis),
hardware transcoding devices, and metrics.
