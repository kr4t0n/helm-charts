# transmission

[Transmission](https://transmissionbt.com/) with its web UI. Packaged from the
[linuxserver/transmission](https://hub.docker.com/r/linuxserver/transmission)
image and built on the shared [`common`](../common) library chart.

## Install

Put the web UI credentials in a Secret, then install:

```bash
kubectl create namespace transmission
kubectl -n transmission create secret generic transmission-auth \
  --from-literal=USER=admin --from-literal=PASS="$(openssl rand -hex 16)"
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install transmission kr4t0n/transmission -n transmission \
  --set existingSecret.enabled=true --set existingSecret.name=transmission-auth
```

Then open the web UI:

```bash
kubectl -n transmission port-forward svc/transmission 9091:9091
# http://127.0.0.1:9091
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/transmission` |
| `image.tag` | linuxserver build tag and index digest (amd64 and arm64) | `4.1.4-r0-ls371`, by digest |
| `service.port` | Web UI and RPC port | `9091` |
| `extraPorts` | Extra container ports (BitTorrent `51413` TCP+UDP) | bttcp/btudp |
| `persistence.size` | Config volume (`/config`) size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `existingSecret.{enabled,name}` | Load env vars (`USER`, `PASS`) from a Secret | disabled |
| `extraEnvs` | Extra env vars (`PUID`, `PGID`, `TZ`, `PEERPORT`, …) | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Mount `/downloads` (and `/watch`) | `[]` |
| `securityContext` | Capabilities for linuxserver's root init | see below |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>-config` at `/config`
  (`settings.json`, torrent files and resume state). The init chowns it to
  `PUID:PGID` recursively on every start.
- **The image owns part of `settings.json`.** On every start linuxserver's init
  writes these settings from the environment, so edits made in the web UI do
  not survive a restart:
  - `USER` + `PASS` set ⇒ authentication on with those credentials; either one
    unset ⇒ authentication **off**.
  - `WHITELIST` / `HOST_WHITELIST` set ⇒ the RPC IP / host whitelist on with
    that list; unset ⇒ the whitelist **off**.
  - `PEERPORT` and `UMASK`, when set.

  Everything else in `settings.json` is the daemon's own. It saves the file on
  exit, overwriting edits made while it runs, so change those settings in the
  web UI.
- **Capabilities.** The chart drops all capabilities and adds back the four the
  init needs: `CHOWN` to chown `/config`, `SETUID` / `SETGID` to drop to
  `PUID:PGID`, and `DAC_OVERRIDE` for root to rewrite `settings.json`, which
  the chown hands to `PUID`. Without `DAC_OVERRIDE` the rewrite fails, and the
  daemon starts with authentication off whatever `USER` / `PASS` say. Docker mods
  (`DOCKER_MODS`) install packages at start and may need more.
- **Downloads**: mount a volume at `/downloads` via
  `extraVolumes`/`extraVolumeMounts`. Completed downloads land in
  `/downloads/complete` and in-progress ones in `/downloads/incomplete`. The
  init chowns `/downloads` and those two directories to `PUID:PGID`, but not
  their contents.
- **Watch folder**: `.torrent` files dropped into `/watch` are added
  automatically and renamed to `*.torrent.added`. Nothing is mounted there by
  default: it is only useful as a volume shared with whatever produces the
  files, since adding through the web UI or RPC covers everything else. Without
  a mount the daemon logs `Couldn't watch '/watch'` once per start, which is
  harmless.
- **BitTorrent port**: `51413` (TCP+UDP) is declared on the **pod** via
  `extraPorts` but is **not** published by the Service. To accept inbound peers,
  add a matching `service.extraPorts` entry and an appropriate Service type or
  host setup. To use another port, set `PEERPORT` and change both `extraPorts`
  entries to match.
- **Alternative web UIs**: the built-in UI needs no setup. For another one, copy
  its files onto the config volume (e.g. `/config/web`, with `index.html` at
  its top) and set `TRANSMISSION_WEB_HOME=/config/web` in `extraEnvs`. The
  image no longer bundles any. Its old theme paths
  (`/flood-for-transmission`, `/transmission-web-control`, …) now serve only a
  notice page.
- **Probes** are TCP checks on the web port, because with `USER`/`PASS` set
  every HTTP path answers `401`.
- **Time zone and ids**: set `TZ`, `PUID` and `PGID` (both default to `911`) via
  `extraEnvs`.
