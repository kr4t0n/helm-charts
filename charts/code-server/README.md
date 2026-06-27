# code-server

[code-server](https://github.com/coder/code-server) — VS Code running in the
browser, backed by a persistent workspace. Packaged from the
[linuxserver/code-server](https://hub.docker.com/r/linuxserver/code-server)
image and built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install code-server kr4t0n/code-server -n code-server --create-namespace
```

Then open the web UI:

```bash
kubectl -n code-server port-forward svc/code-server 8443:8443
# https://127.0.0.1:8443
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/code-server` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8443` |
| `persistence.size` | Config volume (`/config`) size | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `PASSWORD`, `TZ`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars (e.g. `PASSWORD`) from a Secret | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount project directories | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (settings,
  extensions, and the default workspace live here).
- **Auth**: set `PASSWORD` / `SUDO_PASSWORD` via `extraEnvs`, or load them from
  a Secret with `existingSecret`.
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.
