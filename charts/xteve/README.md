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
| `image.repository` | Image | `alturismo/xteve` |
| `image.tag` | Tag (only `latest` is published) | `latest` |
| `service.port` | Web UI / HDHomeRun port | `34400` |
| `persistence.size` | System-folder volume (`/root/.xteve`) size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Image**: uses [`alturismo/xteve`](https://hub.docker.com/r/alturismo/xteve),
  which runs xTeVe in the foreground, so it stays up under Kubernetes. (The
  alternative `dnsforge/xteve` image expects an interactive TTY — `docker run
  -it` — and its PID 1 exits without one, so the pod goes `Completed`. The
  `common` library doesn't render `tty`/`stdin`, so that image isn't supported
  here without a custom patch.)
- **Persistence** mounts one PVC at `/root/.xteve` (xTeVe's system folder —
  `settings.json`, lineups, EPG cache).
- **Time zone**: xTeVe's scheduler honours `TZ` — set it via `extraEnvs`.
- **Plex/Emby discovery**: SSDP/DLNA auto-discovery won't cross the cluster
  network on a ClusterIP service. Add xTeVe as a tuner manually using the
  Service address (`http://xteve.<namespace>:34400`).
