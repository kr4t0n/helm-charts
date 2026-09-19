# plex

[Plex Media Server](https://plex.tv) — organizes and streams your personal
media library. Built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install plex kr4t0n/plex -n media --create-namespace
```

Then open the web UI:

```bash
kubectl -n media port-forward svc/plex 32400:32400
# http://127.0.0.1:32400/web
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `plexinc/pms-docker` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI / API port | `32400` |
| `service.hostPort` | Also bind the web UI port on the node | `true` |
| `extraPorts` | Discovery / DLNA / Companion container ports | see `values.yaml` |
| `persistence.size` | Config volume (`/config`) size | `8Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`, `ADVERTISE_IP`) | `[]` |
| `existingSecret.*` | Load all keys of a secret as env (e.g. `PLEX_CLAIM`) | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount your media library | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config`.
- **Claiming the server**: put `PLEX_CLAIM` in a Secret and reference it via
  `existingSecret`, rather than placing the token in values.
- **Media libraries** are not managed by this chart — mount them yourself with
  `extraVolumes` / `extraVolumeMounts` (NFS, hostPath, an existing PVC, …).
- **`hostPort`** is on by default because Plex's client discovery and
  direct-play expect to reach the server on the node address. It restricts the
  pod to one pod per node; set `service.hostPort: false` if you front Plex with
  an Ingress or LoadBalancer instead.
- **Discovery ports** (GDM, Bonjour, DLNA) are declared on the pod only and are
  *not* published through the Service — matching the pre-library chart. Add
  matching `service.extraPorts` entries if you need them routed.

## Upgrading from 0.0.x

`0.1.0` moves rendering to the `common` library. Resource names, the
`app: <release>` selector and the PVC name are unchanged, so existing releases
upgrade in place and reuse their PVC. Two values changes are required:

- **Ingress.** The `ingress.classes[]` list (one Ingress per class) is replaced
  by the shared single-Ingress schema:

  ```yaml
  # before
  ingress:
    enabled: true
    classes:
      - className: traefik
        annotations: {...}
        hosts:
          - host: plex.example.com
            paths:
              - path: /
                pathType: Prefix
        tls:
          - secretName: plex-tls
            hosts: [plex.example.com]

  # after
  ingress:
    enabled: true
    className: traefik
    annotations: {...}
    hosts:
      - host: plex.example.com
    tls:
      - hosts: [plex.example.com]
        secretName: plex-tls
  ```

  The rendered Ingress is now named `<release>` instead of
  `<release>-<className>`, so the old object is replaced. If you need several
  ingress classes, install the chart once per class or manage the extra
  Ingresses outside it.

- **Persistence.** The config volume moved under `persistence.volumes`:

  ```yaml
  # before
  persistence:
    enabled: true
    storageClass: longhorn
    size: 8Gi

  # after
  persistence:
    enabled: true
    storageClass: longhorn
    size: 8Gi
    accessModes: [ReadWriteOnce]
    volumes:
      config:
        mountPath: /config
        claimNameSuffix: ""   # PVC stays named "<release>"
  ```

  The defaults in [`values.yaml`](./values.yaml) already express this, so you
  only need the block if you override `mountPath` or claim naming.

`imagePullPolicy` also moved to `image.pullPolicy`; the old top-level key is
still honoured by the library as a fallback.
