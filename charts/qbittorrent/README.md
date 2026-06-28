# qbittorrent

[qBittorrent](https://www.qbittorrent.org/) with its Web UI. Packaged from the
[linuxserver/qbittorrent](https://hub.docker.com/r/linuxserver/qbittorrent)
image and built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install qbittorrent kr4t0n/qbittorrent -n qbittorrent --create-namespace
```

Then open the Web UI:

```bash
kubectl -n qbittorrent port-forward svc/qbittorrent 8080:8080
# http://127.0.0.1:8080
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/qbittorrent` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8080` |
| `extraPorts` | Extra container ports (BitTorrent `6881` TCP+UDP) | bttcp/btudp |
| `persistence.size` | Config volume (`/config`) size | `4Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`, `WEBUI_PORT`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars from a Secret | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount a downloads directory | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (qBittorrent
  config + torrent state).
- **BitTorrent port**: `6881` (TCP+UDP) is declared on the **pod** via
  `extraPorts` but is **not** published by the Service (same as before). To
  accept inbound peers, add a matching `service.extraPorts` entry and an
  appropriate Service type / host setup.
- **Downloads**: mount your downloads directory via
  `extraVolumes`/`extraVolumeMounts` (e.g. an NFS share at `/downloads`).
- **Time zone**: set `TZ` via `extraEnvs`.
