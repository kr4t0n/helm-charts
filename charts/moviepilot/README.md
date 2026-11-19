# moviepilot

[MoviePilot](https://github.com/jxxghp/MoviePilot) — a media automation tool
(subscriptions, search, organizing). Packaged from the
[jxxghp/moviepilot-v3](https://hub.docker.com/r/jxxghp/moviepilot-v3) image and
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
| `image.repository` | Image | `jxxghp/moviepilot-v3` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `strategy` | Deployment update strategy | `{type: Recreate}` |
| `service.port` | Web UI port | `8080` |
| `persistence.size` | Config volume (`/config`) size | `4Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars from a Secret | disabled |
| `extraVolumes` / `extraVolumeMounts` | Mount a media library | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** creates one PVC, `<release>` (`/config`, config + data,
  `4Gi`). V3 caches its browser (CloakBrowser) on it too, in
  `/config/.browser/cloakbrowser`, unless `CLOAKBROWSER_CACHE_DIR` points
  elsewhere.
- **Image version**: pinned to `appVersion` 3.2.6 of the `moviepilot-v3`
  image. Not the `moviepilot-v3t` free-threaded build, which upstream calls
  experimental. Chart 0.6.1 and older ran the `moviepilot-v2` image; see
  [Upgrading from V2](#upgrading-from-v2).
- **Update strategy**: `Recreate`, so the old pod stops before the new one
  starts. The pod is a singleton on ReadWriteOnce volumes, and two MoviePilot
  pods must never run on one `/config`.
- **AI agent**: off by default. Add `AI_AGENT_ENABLE: "false"` to `extraEnvs`
  to pin it off: V3 reads the process environment ahead of `/config/app.env`,
  and its web settings refuse to change a value the environment sets.
  CVE-2026-77931 (the agent's command tool) is not fixed in V3: the advisory
  covers MoviePilot through 3.1.5 and names no fixed version.
- **Admin password**: V3 ignores `SUPERUSER_PASSWORD` and keeps the password
  hash in its database. Existing V2 accounts carry over.
- **Time zone**: set `TZ` via `extraEnvs`.

## Upgrading

- **To 0.6.4:** the chart no longer creates `<release>-playwright`. V3 never
  writes to `/moviepilot/.cache/ms-playwright`; its browser cache is on the
  config volume. Upgrading makes Helm delete the PVC. If its PersistentVolume's
  reclaim policy is `Retain`, the PV and its storage stay behind, to delete by
  hand. To keep the volume (say, for a plugin that launches Playwright's own
  Chromium), add it back before upgrading:

  ```yaml
  persistence:
    volumes:
      playwright:
        mountPath: /moviepilot/.cache/ms-playwright
        size: 1Gi
  ```

## Upgrading from V2

Chart 0.6.2 moves the image from `jxxghp/moviepilot-v2` (2.15.6, the last V2
release) to `jxxghp/moviepilot-v3`. V3 keeps the same `/config` and database,
but its first start migrates the database schema in place, and V2 can't read
it afterwards. Rolling the release back alone doesn't undo that, so:

1. **Back up the config volume first**, `<release>` (`/config`), with no
   MoviePilot pod running, and check that the copy is complete before V3
   starts. A Longhorn snapshot of a detached volume completes only once the
   volume is attached again. The V2 release's `<release>-playwright` holds only
   V2's Chromium download, and this chart deletes it (see
   [Upgrading](#upgrading)).
2. **Never run V2 and V3 on one `/config`.** Keep this chart's `Recreate`
   default, or scale the Deployment to 0 before the upgrade. A release that
   overrides `strategy` with `RollingUpdate` starts V3 next to V2.
3. **Don't count on V3's own copy.** V3 copies the database to
   `/config/database_backup` before a migration only when `DB_BACKUP_ENABLE` is
   `"true"`, and it defaults to false. That copy sits on the same volume, so it
   doesn't replace the backup in step 1.
4. **The way back is that backup.** Scale V3 to 0, restore the config volume,
   then roll back to the V2 chart. With Longhorn, a backup restores only into a new
   volume, which you bind in place of the claim; a snapshot revert keeps the
   existing volume.

Upstream's guide covers plugins, sites and the checks to run after the switch:
[V3 切换说明](https://wiki.movie-pilot.org/zh/upgrade) and
[docs/v2-to-v3-overview.md](https://github.com/jxxghp/MoviePilot/blob/v3/docs/v2-to-v3-overview.md).
