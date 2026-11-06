# calibre-web

[Calibre-Web](https://github.com/janeczku/calibre-web) — a clean web app for
browsing, reading and downloading eBooks from a Calibre library. Packaged from
the [linuxserver/calibre-web](https://hub.docker.com/r/linuxserver/calibre-web)
image and built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install calibre-web kr4t0n/calibre-web -n calibre --create-namespace
```

Then open the web UI:

```bash
kubectl -n calibre port-forward svc/calibre-web 8083:8083
# http://127.0.0.1:8083
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/calibre-web` |
| `image.tag` | linuxserver build tag and index digest (amd64 and arm64) | `0.6.27-ls408`, by digest |
| `service.port` | Web UI port | `8083` |
| `persistence.size` | Config volume (`/config`) size | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Mount your Calibre library | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (Calibre-Web's
  app config / database).
- **Your book library** is mounted via `extraVolumes` + `extraVolumeMounts`
  (e.g. an NFS share at `/books`), then pointed at from the Calibre-Web setup
  screen on first run.
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.
