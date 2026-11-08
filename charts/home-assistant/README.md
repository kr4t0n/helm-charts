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
| `skipPythonCopy` | Link the image's Python tree instead of copying it on every start (see below) | `false` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence** mounts one PVC named `<release>` at `/config` (all Home
  Assistant configuration and state live here).
- **Time zone**: set `TZ` via `extraEnvs` — important for automations.
- **Device / host access** (Zigbee/Z-Wave USB sticks, mDNS discovery) isn't
  configured by this chart; add it via `extraVolumes`/`extraVolumeMounts` and
  pod settings as needed for your setup.

## Python copy at start (`skipPythonCopy`)

The linuxserver image ships its Python as `/usr/local/lib/python3.X.bak`
(1.8 GiB in 2026.11.0-ls263, with every integration's dependencies). On every
container start, its `init-config-homeassistant` script moves it back to
`python3.X` and runs `chown -R abc:abc` on it. The directory sits in an image
layer, so overlayfs can't rename it: `mv` copies the whole tree into the
container's writable layer, which the kubelet counts as ephemeral storage. Each
new container, so every restart, copies it again.

`skipPythonCopy: true` mounts two scripts from [`files/`](./files) over the
image's, from a ConfigMap named `<release>-s6-overrides`:

- `init-config-homeassistant/run` creates the symlink
  `python3.X -> python3.X.bak` instead of the move and the `chown -R`. abc still
  joins the `lsio` group (7310). The image builds the tree as `root:7310` and
  group-writable, so Home Assistant can still install integration requirements
  into it (`uv pip install` with `UV_SYSTEM_PYTHON=true`). New files land in the
  writable layer, as before.
- `svc-homeassistant/run` drops the `.bak` from the name it gives `setcap`.
  Its `find -type d` doesn't match the symlink, so without this change it would
  set the interpreter's capabilities, Bluetooth included, on a file that doesn't
  exist.

**Risks.** Files are no longer owned by abc, so writes depend on the `lsio`
group. A package that root installs under the tree at start (only with
`DOCKER_MODS` pip packages) stays root-owned, and abc can't change it in place.
The scripts are copies of one image build's. They're the scripts of
2026.11.0-ls263 (linuxserver/docker-homeassistant `bc919f9`), so an
`image.tag` override runs them on another build.

**Image bumps.** Diff
`root/etc/s6-overlay/s6-rc.d/{init-config-homeassistant,svc-homeassistant}/run`
in linuxserver/docker-homeassistant between the old and new image's
`org.opencontainers.image.revision`. Carry any change into `files/`, and update
the revision in each file's header.

**Verify on a live pod.**

```bash
# "Linking /usr/local/lib/python3.X ..." replaces "New container detected ..."
kubectl -n home-assistant logs deploy/home-assistant | grep -E 'Linking|New container detected'
# A symlink to python3.X.bak, and the interpreter's capabilities as before
kubectl -n home-assistant exec deploy/home-assistant -- sh -c 'ls -ld /usr/local/lib/python3.*; getcap /usr/local/bin/python3.*'
# The container's writable layer, from the kubelet (rootfs.usedBytes)
kubectl get --raw "/api/v1/nodes/<node>/proxy/stats/summary" \
  | jq '.pods[] | select(.podRef.namespace == "home-assistant") | .containers[] | {name, rootfs: .rootfs.usedBytes}'
```

**Turn it off** with `skipPythonCopy: false`, or drop the key. The next
container runs the image's scripts and copies the tree again. Nothing in
`/config` changes either way.
