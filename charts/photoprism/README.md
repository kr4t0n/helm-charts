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
| `image.tag` | Tag | `latest` |
| `service.port` | Web UI port | `2342` |
| `workingDir` | Container working directory | `/photoprism` |
| `persistence.size` | Storage volume (`/photoprism/storage`) size | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
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
- **`image.tag` is `latest` on purpose.** PhotoPrism's release tags are date
  stamps that go stale quickly, and deployed servers track `latest`. Leaving it
  empty would resolve to the chart's `appVersion` and silently downgrade the
  server. Set an explicit date tag if you want a reproducible deploy.
- **Secrets**: put `PHOTOPRISM_ADMIN_PASSWORD` and any database credentials in a
  Secret and reference it via `existingSecret`, not in `extraEnvs`.
- **`workingDir: /photoprism`** is required — PhotoPrism resolves its config and
  assets relative to it.

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
