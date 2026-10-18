# xray

[Xray-core](https://github.com/XTLS/Xray-core) — a proxy server supporting VLESS,
VMess, Trojan and Shadowsocks over the RAW, XHTTP, WebSocket and gRPC transports,
with TLS or REALITY security. This chart runs the official
`ghcr.io/xtls/xray-core` image (distroless, uid 65532) as a single Deployment.
Built on the shared [`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install xray kr4t0n/xray -n xray --create-namespace \
  --set existingConfigSecret=xray-inbounds
```

The defaults alone start Xray with no inbound. Add one before it does anything.

## How the config is assembled

The image runs `xray -confdir /usr/local/etc/xray/`, which loads every `*.json`
file in that directory and merges them in filename order. The chart mounts the
directory from up to two Secrets:

| Source | File | Use for |
|---|---|---|
| `config` (values) | `00_config.json` | log, routing, outbounds, DNS — anything non-secret |
| `existingConfigSecret` | each key, e.g. `10_inbounds.json` | inbounds carrying client ids and the REALITY private key |

The merge rules:

- Top-level objects in a later file override or extend earlier ones.
- `inbounds` and `outbounds` merge by `tag`. A later element replaces an earlier
  one with the same tag, and untagged or new inbounds are appended.
- New outbounds are *prepended*, unless the filename contains `tail`. The first
  outbound is the default route, so an outbound added in the Secret becomes the
  default.

Changes to `config` roll the pod through a checksum annotation. Changes to
`existingConfigSecret` do not, and Xray does not hot-reload, so restart it:
`kubectl -n xray rollout restart deploy/xray`.

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.tag` | Bare version, without the GitHub release's `v` | `26.3.27` |
| `service.port` | Port the inbound must listen on; Service and hostPort target it | `8443` |
| `service.hostPort` | Also bind `service.port` on the node | `false` |
| `strategy` | Set `type: Recreate` with `hostPort` | `{}` |
| `config` | Non-secret config, rendered to `00_config.json` | direct + block outbounds, private IPs blocked |
| `existingConfigSecret` | Secret whose keys are mounted alongside | `""` |
| `extraPorts` / `service.extraPorts` | A second inbound, e.g. on UDP | `[]` |
| `ingress.*` | For HTTP-based transports only (XHTTP, WS, gRPC) | disabled |
| `probes` | Verbatim probes — see Notes before enabling | `{}` |
| `podSecurityContext` / `securityContext` | Non-root, read-only root fs, no capabilities | hardened |
| `resources` | Requests / limits | `{}` |

See [`values.yaml`](./values.yaml) for the full list.

## Example: VLESS + REALITY + Vision

Generate the credentials with the same image:

```bash
docker run --rm ghcr.io/xtls/xray-core:26.3.27 uuid
docker run --rm ghcr.io/xtls/xray-core:26.3.27 x25519   # PrivateKey -> server, Password (PublicKey) -> clients
openssl rand -hex 8                                       # a shortId
```

Then provide the inbound as a Secret. With External Secrets, the values stay in
the secret store and only the template lives in Git:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: xray-inbounds
  namespace: xray
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: xray-inbounds
    template:
      data:
        10_inbounds.json: |
          {
            "inbounds": [{
              "tag": "vless-reality",
              "port": 8443,
              "protocol": "vless",
              "settings": {
                "clients": [{ "id": "{{ .uuid }}", "flow": "xtls-rprx-vision" }],
                "decryption": "none"
              },
              "streamSettings": {
                "network": "raw",
                "security": "reality",
                "realitySettings": {
                  "target": "www.apple.com:443",
                  "serverNames": ["www.apple.com"],
                  "privateKey": "{{ .privateKey }}",
                  "shortIds": ["{{ .shortId }}"]
                }
              },
              "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true }
            }]
          }
  data:
    - { secretKey: uuid, remoteRef: { key: xray-secret, property: uuid } }
    - { secretKey: privateKey, remoteRef: { key: xray-secret, property: privateKey } }
    - { secretKey: shortId, remoteRef: { key: xray-secret, property: shortId } }
```

The client needs the uuid, `flow: xtls-rprx-vision`, the server name, the public
key (`password` in Xray clients, `public-key` in mihomo), the shortId and a
browser `fingerprint` such as `chrome`.

### Exposing it

REALITY has to see the client's raw TLS handshake, so it cannot sit behind an
ingress that terminates TLS. Use one of these:

- **TCP passthrough on an existing 443 entrypoint.** Traefik routes by SNI
  before its HTTP routers, so connections for the REALITY server name go to
  Xray untouched, and everything else is served as usual:

  ```yaml
  apiVersion: traefik.io/v1alpha1
  kind: IngressRouteTCP
  metadata:
    name: xray
    namespace: xray
  spec:
    entryPoints: [websecure]
    routes:
      - match: HostSNI(`www.apple.com`)
        services:
          - name: xray
            port: 8443
    tls:
      passthrough: true
  ```

- **hostPort on a node.** Clients should reach REALITY on 443, so listen on
  443 and allow a non-root bind with the namespaced (and Kubernetes-safe) sysctl:

  ```yaml
  service:
    port: 443
    hostPort: true
  strategy:
    type: Recreate
  podSecurityContext:
    sysctls:
      - name: net.ipv4.ip_unprivileged_port_start
        value: "443"
  ```

  Remember to change the inbound's `port` to match.

## Notes

- **Choose the REALITY target carefully.** It must speak TLS 1.3 and be
  reachable from the node, and clients send its name as their SNI. On 26.3.27,
  `www.apple.com`, `dl.google.com`, `www.samsung.com` and `www.lovelive-anime.jp`
  completed the handshake. `www.microsoft.com` did not: authentication
  succeeded, but the handshake stalled while mirroring Microsoft's 8 KB
  certificate chain and its post-quantum ServerHello.
- **"Listening on non-443 ports may get your IP blocked" is about the public
  port.** Xray logs it whenever the inbound's own port isn't 443. Behind a
  passthrough on 443 that is a false alarm. With `hostPort`, take it seriously.
- **Private destinations are blocked by default.** The pod sits inside the
  cluster network, so without the `geoip:private` rule any client could proxy
  into cluster Services, pods and anything else the node can route to.
  `domainStrategy: IPIfNonMatch` resolves domain destinations first, so names
  such as `kubernetes.default.svc` are caught too. If you replace `routing` in
  your own config, keep an equivalent rule.
- **No probes by default.** A TCP probe only shows the port is open. Against a
  REALITY inbound, each probe also makes Xray dial the target, because REALITY
  connects to it before it reads the ClientHello. Xray starts in well under a
  second and exits on a bad config, so the pod status already reflects health.
- **The container port is named `http`**, as in every `common`-based chart,
  whatever protocol it carries.
- **Sizing.** An idle server with the default config and one REALITY inbound
  uses about 8 MiB. Memory grows with concurrent connections.

## Uninstall

```bash
helm uninstall xray -n xray
```
