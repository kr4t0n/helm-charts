# home-assistant

[Home Assistant](https://www.home-assistant.io/) — open-source home automation.
Packaged from the
[linuxserver/homeassistant](https://hub.docker.com/r/linuxserver/homeassistant)
image and built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install home-assistant kr4t0n/home-assistant -n home-assistant --create-namespace
```

Then open the web UI:

```bash
kubectl -n home-assistant port-forward svc/home-assistant 8123:8123
# http://127.0.0.1:8123
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `linuxserver/homeassistant` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Web UI port | `8123` |
| `persistence.size` | Config volume (`/config`) size | `10Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Mount a USB device, dbus socket, etc. | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (all Home
  Assistant configuration and state live here).
- **Time zone**: set `TZ` via `extraEnvs` — important for automations.
- **Device / host access** (Zigbee/Z-Wave USB sticks, mDNS discovery) isn't
  configured by this chart; add it via `extraVolumes`/`extraVolumeMounts` and
  pod settings as needed for your setup.
