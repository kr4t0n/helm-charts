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
| `strategy` | Deployment update strategy | `{type: Recreate}` |
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
  Pin `image.tag` explicitly if you need a specific build.
- **Update strategy**: `Recreate`, so the old pod stops before the new one
  starts. The pod is a singleton on ReadWriteOnce volumes, and two BamBuddy
  versions must never run on one SQLite database while it migrates.
- **Time zone**: set `TZ` via `extraEnvs` for correct local times.

## Upgrading from 0.2.x (chart 0.6.1 and older)

Chart 0.6.2 moves the app from 0.2.4.7 to 1.3.1. The container keeps its port
(8000), its volumes (`/app/data`, `/app/logs`), its `PUID`/`PGID` entrypoint
and its `/health` endpoint, so the chart's templates don't change.

1. **Back up the data volume first.** BamBuddy migrates its database at start.
   On SQLite it also rebuilds tables once so that ids are never reused, and
   1.3.0 rewrites rows in place (archives, folder owners, costs). The app takes
   no copy of its own in Docker, and upstream documents no downgrade. So the
   backup, restored together with the old image, is the way back.
2. **Keep the `Recreate` default**, or scale the Deployment to 0 before the
   upgrade. A release that overrides `strategy` with `RollingUpdate` starts
   the new version next to the old one.
3. **Check the settings whose defaults now act.** The global "Auto-archive
   prints" switch is read from 1.3.0 on, so if it is off, prints started
   outside BamBuddy are no longer archived. "Restore plate for finish photo"
   is on by default and now moves the bed. Queued jobs whose filament doesn't
   match a loaded tray wait for a manual start. The plate-clear confirmation
   defaults to off. Upstream's release notes for 0.2.4.8 through 1.3.1 list
   the rest.
