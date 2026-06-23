# tautulli

[Tautulli](https://github.com/Tautulli/Tautulli) — a monitoring and tracking
tool for [Plex Media Server](https://plex.tv) (watch history, statistics,
notifications). Built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install tautulli kr4t0n/tautulli -n media --create-namespace
```

Then open the web UI:

```bash
kubectl -n media port-forward svc/tautulli 8181:8181
# http://127.0.0.1:8181
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/tautulli` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8181` |
| `persistence.size` | Config volume (`/config`) size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config`.
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.
- **Upgrades** are in-place safe: the chart preserves the pre-library resource
  names and `app: <release>` selector, so existing PVCs are reused and no
  immutable-selector change occurs (only additive `app.kubernetes.io/*` labels).
