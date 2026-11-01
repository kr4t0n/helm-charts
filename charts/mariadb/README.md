# mariadb

[MariaDB](https://mariadb.org) server from the official
[`mariadb`](https://hub.docker.com/_/mariadb) image
([MariaDB/mariadb-docker](https://github.com/MariaDB/mariadb-docker)), pinned by
digest. One release runs one server: a StatefulSet with one replica, a Service
and a ConfigMap. The templates are this chart's own; names, labels and the
image reference come from the [`common`](../common) library's helpers.

## Prerequisites

A Secret in the release's namespace that holds the root password, under the key
`mariadb-root-password` (`auth.rootPasswordKey`). The chart never creates one.
When `auth.username` is set, the same Secret holds that user's password under
`mariadb-password` (`auth.passwordKey`). For example:

```bash
umask 077
openssl rand -base64 24 | tr -d '\n' > root-password
openssl rand -base64 24 | tr -d '\n' > app-password
kubectl -n db create secret generic mariadb-auth \
  --from-file=mariadb-root-password=root-password \
  --from-file=mariadb-password=app-password
rm root-password app-password
```

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install mariadb kr4t0n/mariadb -n db \
  --set auth.existingSecret=mariadb-auth \
  --set auth.database=app \
  --set auth.username=app
```

Clients in the cluster connect to `mariadb.db.svc:3306`. To open a root shell
over the server's socket:

```bash
kubectl -n db exec -it mariadb-0 -- mariadb -uroot -p
```

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `image.repository` | Image | `mariadb` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `image.digest` | Index digest of the tag, all architectures (empty ⇒ pull by tag) | the 12.3.3 index |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `auth.existingSecret` | Secret holding the passwords | **required** |
| `auth.rootPasswordKey` | Its key for the root password | `mariadb-root-password` |
| `auth.rootHost` | Host `root` may log in from; `localhost` is the socket only, `%` any host | `localhost` |
| `auth.database` | Database to create | `""` |
| `auth.username` | User to create, with all privileges on `auth.database` only | `""` |
| `auth.passwordKey` | Secret key for that user's password | `mariadb-password` |
| `autoUpgrade` | Run `mariadb-upgrade` when the major or minor version rises | `true` |
| `config` | Lines appended to the chart's `[mariadb]` group in `my.cnf` | `""` |
| `service.type` / `service.port` | Service | `ClusterIP` / `3306` |
| `persistence.storageClass` | StorageClass of the data volume (empty ⇒ cluster default) | `""` |
| `persistence.size` | Data volume size | `8Gi` |
| `persistence.accessModes` | Data volume access modes | `[ReadWriteOnce]` |
| `podSecurityContext` / `securityContext` | Pod and container security contexts, verbatim | see [Security](#security) |
| `probes.{startup,readiness,liveness}` | Probes, verbatim | see [Probes](#probes) |
| `terminationGracePeriodSeconds` | Time for a clean shutdown | `60` |
| `resources` | Requests and limits | `{}` |
| `extraEnvs` | Extra env vars for the server | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Extra volumes | `[]` |
| `podAnnotations`, `imagePullSecrets`, `priorityClassName`, `nodeSelector`, `tolerations`, `affinity` | Pod settings | unset |

`auth.rootHost`, `auth.database` and `auth.username` act on the first start
only, while the data volume is empty. So does the Secret: the server keeps the
passwords it was initialised with. To change one later, run `ALTER USER` and
then update the Secret to match.

## How it works

- **First start.** The image's entrypoint initialises `/var/lib/mysql`, loads
  the time zone tables, sets root's password from
  `MARIADB_ROOT_PASSWORD_FILE`, creates `root@<auth.rootHost>` unless it is
  `localhost`, and creates `auth.database` and `auth.username`. It also creates
  a `healthcheck` user (`USAGE` only, local hosts only) and writes its login to
  `/var/lib/mysql/.my-healthcheck.cnf` with mode `0600`. It unsets the password
  variables before it starts the server.
- **Passwords** are read from files, never from env values. The Secret is
  mounted read-only at `/run/secrets/mariadb` with only the keys the chart
  needs, at mode `0440`.
- **Config.** The image reads `/etc/mysql/conf.d/` last, so the ConfigMap
  mounted there overrides the image's defaults. The chart sets
  `ignore_db_dirs=lost+found`: the data volume's root is the datadir, and
  without it the server lists a filesystem's `lost+found` as a database
  (`#mysql50#lost+found`). A change to `config` rolls the pod through a
  checksum annotation.

## Probes

All three run the image's own `/usr/local/bin/healthcheck.sh` over the socket.

| Probe | Check | Timing |
|-------|-------|--------|
| startup | `--connect --innodb_initialized` | every 10 s, up to 10 minutes |
| readiness | `--connect --innodb_initialized` | every 10 s, 3 failures |
| liveness | `--connect` | every 10 s, 6 failures |

- `--connect` fails while the entrypoint's temporary server runs during init
  or an upgrade, because that server skips networking. So a pod is never Ready
  before the real server starts.
- `--innodb_initialized` needs the `healthcheck` user's login, so readiness
  fails on a server nobody can log in to.
- `--connect` counts "access denied" as connected. Liveness therefore restarts
  a server that has stopped answering, never one that only has a broken login.

## Upgrades

- **Patch bumps** (12.3.3 → 12.3.x) set `appVersion` and `image.digest`
  together, from the tag's index on Docker Hub. The entrypoint runs no
  `mariadb-upgrade` for them: it runs it only when the major or minor version
  rises, or when the data volume has no `mariadb_upgrade_info` yet.
- **Minor or major bumps** (12.3 → 13.0) with `autoUpgrade: true`: the
  entrypoint starts a temporary server, backs up the `mysql` schema to
  `system_mysql_backup_<old version>.sql.zst` in the data volume, runs
  `mariadb-upgrade --upgrade-system-tables`, and logs `Starting
  mariadb-upgrade` and `Finished mariadb-upgrade`.
- **Going back.** MariaDB doesn't officially support downgrades, even to an
  older patch release, and doesn't test them in place. Take a dump before any
  bump you may want to undo.
- **Rollout.** Every chart version rolls the pod, because the chart's version
  is a pod label. A one-replica StatefulSet deletes the old pod before it
  creates the new one, so two servers never share the volume. Clients see an
  outage from the old server's shutdown to the new server's readiness.

## What stays fixed

These keep a release upgrading in place. Changing any of them breaks the
upgrade or the data:

- **Names.** The StatefulSet, Service and ConfigMap are named after the release
  (`fullnameOverride` changes that), and the pod is `<release>-0`.
- **Selector** `app: <release>`, and the StatefulSet's `serviceName`, the
  release name.
- **The data volume.** The claim template is named `data`, so the PVC is
  `data-<release>-0`.

Kubernetes rejects any change to a StatefulSet's spec except its replicas, pod
template, update strategy, `minReadySeconds`, `ordinals`,
`revisionHistoryLimit` and `persistentVolumeClaimRetentionPolicy`. The selector,
`serviceName` and the claim template therefore can't change once the release
is installed. A later chart version that changes any of them needs a new
release with the data moved across. That includes `persistence.storageClass`,
`persistence.size` and `persistence.accessModes`. Resize the volume by editing
the PVC, where the StorageClass allows expansion, and leave `persistence.size`
as it was. The claim template carries no labels, so a version bump never
touches it. The PVC outlives the release: `helm uninstall` leaves it, and a new
install under the same name mounts it again.

## Security

- The pod runs as uid and gid `999` (`mysql` in the image), with
  `runAsNonRoot`, `fsGroup: 999` (`fsGroupChangePolicy: OnRootMismatch`) and
  seccomp `RuntimeDefault`. Started as a non-root user, the entrypoint runs as
  that user throughout and never calls `gosu`.
- The container drops all capabilities, disallows privilege escalation and has
  a read-only root filesystem. Its writable paths are the data volume at
  `/var/lib/mysql` and emptyDirs at `/run/mysqld` (socket and PID file) and
  `/tmp` (`tmpdir`).
- The pod mounts no service account token and gets no service link env vars.
- `root` logs in over the socket only, unless `auth.rootHost` says otherwise.
- The chart adds no NetworkPolicy: any pod that can reach the Service and holds
  a login can connect.

Not included: replication, backups, metrics and TLS.
