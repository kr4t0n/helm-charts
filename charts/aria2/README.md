# aria2

[aria2](https://aria2.github.io/) with the [AriaNg](https://github.com/mayswind/AriaNg)
web UI. Packaged from the [`kr4t0n/aria2`](../../images/aria2) image built in
this repo, and built on the shared [`common`](../common) library chart.

## Install

The image refuses to start without an RPC secret, so create one first:

```bash
kubectl create namespace aria2
kubectl -n aria2 create secret generic aria2 --from-literal=RPC_SECRET="$(openssl rand -hex 16)"
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install aria2 kr4t0n/aria2 -n aria2 \
  --set existingSecret.enabled=true --set existingSecret.name=aria2
```

Then open AriaNg and enter the secret under *AriaNg Settings → RPC*:

```bash
kubectl -n aria2 port-forward svc/aria2 8080:8080
# http://127.0.0.1:8080
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `kr4t0n/aria2` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | AriaNg + `/jsonrpc` port | `8080` |
| `args` | Extra aria2c options (override the image's `aria2.conf`) | `[]` |
| `extraPorts` | Extra container ports (e.g. a BitTorrent port) | `[]` |
| `persistence.volumes.config` | `/config`: session + DHT state | `1Gi` |
| `persistence.volumes.downloads` | `/downloads`: download directory | `20Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `existingSecret.{enabled,name}` | Load env vars (`RPC_SECRET`) from a Secret | disabled |
| `podSecurityContext` | uid/gid the app runs and writes as | `65532` |
| `extraEnvs` | Extra env vars (e.g. `TZ`) | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **One port.** nginx serves AriaNg and proxies `/jsonrpc` (HTTP and
  WebSocket) to aria2c, so one Service port and one Ingress host cover both.
  AriaNg defaults its RPC address to the page's own host, port and scheme, so it
  works through a port-forward or an HTTPS ingress without editing.
- **Authentication is the RPC secret.** The UI itself is open; to keep it
  private, put the ingress behind an auth middleware (e.g. oauth2-proxy).
- **Users.** By default the pod runs as uid 65532, and `fsGroup` makes the
  chart's own PVCs writable. The image never chowns `/downloads`.
- **Shared downloads volume.** Mount a volume other apps own and run as its
  owner. Drop `fsGroup`: CSI drivers with fsGroupPolicy `File` (csi-driver-nfs,
  for one) would regroup every file on it. Without `fsGroup`, the fresh config
  PVC stays root-owned, so use the image's root mode, the linuxserver pattern.
  It starts as root, runs `chown -R PUID:PGID /config`, then runs nginx and
  aria2c as `PUID:PGID`:

  ```yaml
  persistence:
    volumes:
      downloads:
        existingClaim: downloads
  extraEnvs:
    - { name: PUID, value: "1000" }
    - { name: PGID, value: "100" }
  podSecurityContext:
    runAsUser: 0
    runAsGroup: 0
    runAsNonRoot: false
    fsGroup: null
  securityContext:
    capabilities:
      drop: [ALL]
      add: [CHOWN, SETUID, SETGID]
  ```

- **BitTorrent port**: none is declared by default, and aria2c picks from its
  default 6881–6999 range when a torrent runs. To accept inbound peers, fix the
  port and declare it:

  ```yaml
  args:
    - --listen-port=6888
    - --dht-listen-port=6888
  extraPorts:
    - { name: bttcp, containerPort: 6888, protocol: TCP }
    - { name: btudp, containerPort: 6888, protocol: UDP }
  ```

  Add matching `service.extraPorts` entries and an appropriate Service type or
  host setup to take them through the Service.
