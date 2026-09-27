# moviepilot

[MoviePilot](https://github.com/jxxghp/MoviePilot) — a media automation tool
(subscriptions, search, organizing). Packaged from the
[jxxghp/moviepilot-v2](https://hub.docker.com/r/jxxghp/moviepilot-v2) image and
built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install moviepilot kr4t0n/moviepilot -n moviepilot --create-namespace
```

Then open the web UI:

```bash
kubectl -n moviepilot port-forward svc/moviepilot 8080:8080
# http://127.0.0.1:8080
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `jxxghp/moviepilot-v2` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8080` |
| `persistence.size` | Config volume (`/config`) size | `4Gi` |
| `persistence.volumes.playwright.size` | Playwright cache volume size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars from a Secret | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount a media library | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** creates two PVCs: `<release>` (`/config`, config + data,
  `4Gi`) and `<release>-playwright` (`/moviepilot/.cache/ms-playwright`, the
  Playwright/Chromium cache, `1Gi`).
- **Image version**: pinned to `appVersion` 2.15.6, the final release of the
  `moviepilot-v2` image. MoviePilot V3 is published as a separate image
  (`jxxghp/moviepilot-v3`) and migrates the database on first start, so it is
  not reachable by bumping the tag here.
- **Time zone**: set `TZ` via `extraEnvs`.
