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
| `image.tag` | linuxserver build tag and index digest (amd64 and arm64) | `5.3.0_v2.1.3-ls489`, by digest |
| `service.port` | Web UI port | `8080` |
| `extraPorts` | Extra container ports (BitTorrent `6881` TCP+UDP) | bttcp/btudp |
| `persistence.size` | Config volume (`/config`) size | `4Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`, `WEBUI_PORT`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars from a Secret | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount a downloads directory | `[]` |
| `securityContext` | Capabilities for linuxserver's root init | see below |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (qBittorrent
  config + torrent state).
- **BitTorrent port**: `6881` (TCP+UDP) is declared on the **pod** via
  `extraPorts` but is **not** published by the Service (same as before). To
  accept inbound peers, add a matching `service.extraPorts` entry and an
  appropriate Service type / host setup.
- **Capabilities.** The chart drops all capabilities and adds back the four the
  init needs: `CHOWN` to chown `/config`, `SETUID` / `SETGID` to drop to
  `PUID:PGID`, and `DAC_OVERRIDE` for root to create `/config/qBittorrent` and
  copy linuxserver's default `qBittorrent.conf` there, after the base image has
  already chowned `/config` to `PUID`. Without `DAC_OVERRIDE`, a fresh volume
  starts on qBittorrent's built-in defaults instead: downloads saved to
  `/config/Downloads` rather than `/downloads`, UPnP on, and a random listen
  port rather than `6881`. A volume that already has `qBittorrent.conf` keeps
  working with the other three.
- **Downloads**: mount your downloads directory via
  `extraVolumes`/`extraVolumeMounts` (e.g. an NFS share at `/downloads`).
- **Time zone**: set `TZ` via `extraEnvs`.
