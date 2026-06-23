# bambuddy

[BamBuddy](https://hub.docker.com/r/maziggy/bambuddy) — a self-hosted companion
/ dashboard for Bambu Lab 3D printers. Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install bambuddy kr4t0n/bambuddy -n bambuddy --create-namespace
```

Then open the web UI:

```bash
kubectl -n bambuddy port-forward svc/bambuddy 8000:8000
# http://127.0.0.1:8000
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `maziggy/bambuddy` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8000` |
| `persistence.size` | Size for the `data` and `logs` volumes | `4Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars from an existing Secret | disabled |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** creates two PVCs: `<release>-data` (`/app/data`) and
  `<release>-logs` (`/app/logs`), each sized from `persistence.size`.
- **Image version**: `appVersion` tracks a published `maziggy/bambuddy` tag.
  (The chart's previous `0.2.3b1` was removed from the registry; pin
  `image.tag` explicitly if you need a specific build.)
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.
