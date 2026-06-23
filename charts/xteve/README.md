# xteve

[xTeVe](https://github.com/xteve-project/xTeVe) — an M3U proxy server that
emulates a SiliconDust HDHomeRun tuner so IPTV channels can be consumed by
Plex, Emby and any client supporting `.ts` / `.m3u8` (HLS). Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install xteve kr4t0n/xteve -n media --create-namespace
```

Then open the web UI:

```bash
kubectl -n media port-forward svc/xteve 34400:34400
# http://127.0.0.1:34400/web/
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `dnsforge/xteve` |
| `image.tag` | Tag (only `latest` is published) | `latest` |
| `service.port` | Web UI / HDHomeRun port | `34400` |
| `persistence.size` | Config volume (`/home/xteve/conf`) size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC at `/home/xteve/conf` (config, data and
  backups all live there).
- **Time zone**: xTeVe's scheduler honours `TZ` — set it via `extraEnvs`.
- **Plex/Emby discovery**: auto-discovery relies on SSDP/host networking, which
  this chart does not enable. Add xTeVe as a tuner manually using the Service
  address (`http://xteve.<namespace>:34400`).
