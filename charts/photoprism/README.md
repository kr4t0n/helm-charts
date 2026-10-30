# photoprism

[PhotoPrism](https://photoprism.app) — an AI-powered photo library that indexes,
tags and browses your own collection. Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install photoprism kr4t0n/photoprism -n media --create-namespace
```

Then open the web UI:

```bash
kubectl -n media port-forward svc/photoprism 2342:2342
# http://127.0.0.1:2342
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `photoprism/photoprism` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `2342` |
| `workingDir` | Container working directory | `/photoprism` |
| `persistence.size` | Storage volume (`/photoprism/storage`) size | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `probes.{startup,readiness}` | Health probes against `/healthz` and `/readyz` | enabled |
| `extraEnvs` | `PHOTOPRISM_*` config vars | `[]` |
| `existingSecret.*` | Load all keys of a secret as env (admin password, DB creds) | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount your photo library at `/photoprism/originals` | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Two different volumes.** The chart manages *only* PhotoPrism's own state —
  one PVC named `<release>` mounted at `/photoprism/storage` (sidecar files,
  thumbnails, index database, cache). Your **photo library is not managed
  here**: mount it at `/photoprism/originals` via `extraVolumes` /
  `extraVolumeMounts`, since it is usually a pre-existing PVC or NFS export
  shared with other apps.
- **The image is pinned, not `latest`.** PhotoPrism's release tags are date
  stamps. A mutable `latest` plus `pullPolicy: IfNotPresent` makes the running
  version depend on which node the pod lands on and what that node has cached —
  a reschedule can jump the server forward by months without warning. Because
  PhotoPrism runs schema migrations at startup and does **not** bind its HTTP
  port until they finish, that shows up as minutes of connection-refused errors
  from whatever fronts it. Bump `appVersion` to upgrade deliberately, and expect
  a migration window the first time you move to a much newer release.
- **Health probes are on by default.** PhotoPrism binds its HTTP port only after
  finishing any schema migrations the running version needs, so without a
  readiness probe the pod reports `Ready` while nothing is listening and callers
  get connection refused for the whole migration window. The startup probe
  tolerates a ~15 minute first boot (`periodSeconds: 10 × failureThreshold: 90`)
  — raise it if you jump across many releases at once, since every intervening
  schema change is replayed. There is deliberately **no liveness probe**: long
  indexing passes can stop answering promptly, and a liveness failure would
  restart the container mid-pass.
- **Secrets**: put `PHOTOPRISM_ADMIN_PASSWORD` and any database credentials in a
  Secret and reference it via `existingSecret`, not in `extraEnvs`.
- **`workingDir: /photoprism`** is required — PhotoPrism resolves its config and
  assets relative to it.

## Upgrading to 0.6.2

`0.6.2` moves PhotoPrism from `261007` to `261029`, which upgrades the bundled
libheif from 1.23.5 to 1.23.7 (security fixes) and Go to 1.27.3. No values
changes are required, but three things change at runtime:

- **Back up the index database first.** `261029` upgrades PhotoPrism's database
  layer and runs schema migrations on its first start, which may take longer
  than usual and need extra disk space for a while. The migrations only run
  forward, so going back to `261007` means restoring a dump taken before the
  upgrade, for example with PhotoPrism's own command:

  ```bash
  kubectl -n <ns> exec deploy/<release> -- photoprism backup -i /photoprism/storage/backups/before-261029.sql
  ```

  `photoprism restore -i -f <file>` loads it back. See PhotoPrism's
  [backup guide](https://docs.photoprism.app/user-guide/backups/).

- **MCP is on by default.** The `/api/v1/mcp` endpoint is enabled for every
  account whose role may use it: admins in every edition, users and viewers in
  PhotoPrism Plus and Pro, managers in Pro. Apps connect to it through OAuth;
  `PHOTOPRISM_OAUTH_APPS` defaults to `registered`, which allows only apps an
  admin registers with `photoprism clients add`. To keep both off, add to
  `extraEnvs`:

  ```yaml
  extraEnvs:
    - name: PHOTOPRISM_DISABLE_MCP
      value: "true"
    - name: PHOTOPRISM_OAUTH_APPS
      value: "none"
  ```

- **Some file names are skipped.** Files and folders whose names contain
  `|"?*%<>{}:~$` are no longer indexed, imported or synced.

The chart sets no update strategy, so on a ReadWriteOnce volume scale to zero
first or set `strategy: {type: Recreate}`, as in the 0.0.x note below.

## Upgrading from 0.0.x

`0.1.0` moves rendering to the `common` library. Resource names, the
`app: <release>` selector and the PVC name are unchanged, so existing releases
upgrade in place and reuse their storage PVC. Two values changes are required:

- **Ingress.** The `ingress.classes[]` list (one Ingress per class) is replaced
  by the shared single-Ingress schema:

  ```yaml
  # before
  ingress:
    enabled: true
    classes:
      - className: tailscale
        hosts:
          - host: photo
            paths:
              - path: /
                pathType: ImplementationSpecific
        tls:
          - hosts: [photo]

  # after
  ingress:
    enabled: true
    className: tailscale
    pathType: ImplementationSpecific   # library default is Prefix
    hosts:
      - host: photo
    tls:
      - hosts: [photo]
  ```

  The rendered Ingress is now named `<release>` instead of
  `<release>-<className>`, so the old object is replaced. If you need several
  ingress classes, install the chart once per class or manage the extra
  Ingresses outside it.

- **Persistence.** The storage volume moved under `persistence.volumes`:

  ```yaml
  # before
  persistence:
    enabled: true
    storageClass: longhorn
    size: 40Gi

  # after
  persistence:
    enabled: true
    storageClass: longhorn
    size: 40Gi
    accessModes: [ReadWriteOnce]
    volumes:
      storage:
        mountPath: /photoprism/storage
        claimNameSuffix: ""   # PVC stays named "<release>"
  ```

  The defaults in [`values.yaml`](./values.yaml) already express this, so you
  only need the block if you override `mountPath` or claim naming.

`imagePullPolicy` also moved to `image.pullPolicy`; the old top-level key is
still honoured by the library as a fallback.

The pod template labels change, so the Deployment rolls. With `replicaCount: 1`
on a ReadWriteOnce storage volume, Kubernetes surges a second pod before
terminating the old one and the new pod hits a Multi-Attach error. Scale to zero
first for a clean cutover:

```bash
kubectl -n <ns> scale deploy/<release> --replicas=0
helm upgrade <release> kr4t0n/photoprism -n <ns> -f <your-values.yaml>
```
