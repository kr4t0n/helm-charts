# kikoeru

[Kikoeru](https://github.com/umonaca/kikoeru-express) — a self-hosted audio
library server (originally for DLsite ASMR / audio works) with a web player.
Packaged from the [number17/kikoeru](https://hub.docker.com/r/number17/kikoeru)
image and built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install kikoeru kr4t0n/kikoeru -n kikoeru --create-namespace
```

Then open the web UI:

```bash
kubectl -n kikoeru port-forward svc/kikoeru 8888:8888
# http://127.0.0.1:8888
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `number17/kikoeru` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8888` |
| `persistence.size` | Size for each of the `sqlite`/`covers`/`config` volumes | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Mount your audio library | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** creates three PVCs — `<release>-sqlite` (database),
  `<release>-covers` (cover-art cache) and `<release>-config` — each sized from
  `persistence.size`.
- **Your audio library** is mounted via `extraVolumes` + `extraVolumeMounts`
  (e.g. an NFS share), then scanned from the Kikoeru admin UI.
- **Image version**: `number17/kikoeru` publishes date-stamped tags
  (`vX.Y.Z-YYYYMMDD`), so `appVersion` tracks a specific build. Pin `image.tag`
  to a different build if needed.
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.
