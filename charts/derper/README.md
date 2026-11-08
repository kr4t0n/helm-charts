# derper

Tailscale [DERP relay](https://tailscale.com/kb/1118/custom-derp-servers) server,
from the `kr4t0n/derper` image built in this repo (`images/derper`). Built on the
`common` library chart (>= 0.6.0).

One release runs one DERP node. The pod uses the node's network, so clients reach
it at the node's public address; there is no Service.

## Prerequisites

- **Open ports** on the node's firewall or security group: `service.port` (TCP,
  default 56443) and `stun.port` (UDP, default 3478). Keep `httpPort.port` (TCP,
  default 56480) closed: derper binds it on every interface, and only the kubelet
  on the node needs it.
- **DNS:** `hostname` resolves to the node's public address.
- **cert-manager** with an issuer that can sign `hostname` (or an existing TLS
  Secret).
- **tailscaled on the node** when `verifyClients.enabled` (the default).

## Example

```yaml
hostname: derp-sh.example.com
certificate:
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
nodeSelector:
  kubernetes.io/hostname: edge-node-1
resources:
  requests: { cpu: 50m, memory: 64Mi }
  limits: { memory: 256Mi }
```

Then add the node to the tailnet policy's `derpMap`:

```json
"derpMap": {
  "Regions": {
    "902": {
      "RegionID": 902, "RegionCode": "sh", "RegionName": "Shanghai",
      "Nodes": [{ "Name": "902a", "RegionID": 902, "HostName": "derp-sh.example.com", "DERPPort": 56443 }]
    }
  }
}
```

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `hostname` | Public DNS name; the certificate and the DERP map `HostName` | **required** |
| `service.port` | DERP over TLS (`-a`) | `56443` |
| `stun.enabled` / `stun.port` | STUN server (UDP) | `true` / `3478` |
| `httpPort.enabled` / `httpPort.port` | Plain-HTTP listener (`-http-port`) for the probes; off means `-http-port=-1` and no default probes | `true` / `56480` |
| `verifyClients.enabled` | Admit only tailnet devices, via the node's tailscaled | `true` |
| `verifyClients.socket` | Host path of the tailscaled socket | `/var/run/tailscale/tailscaled.sock` |
| `probes` | Replaces the default probes (see [Probes](#probes)) | `{}` |
| `certificate.create` | Render a cert-manager `Certificate` for `hostname` | `true` |
| `certificate.issuerRef` | Issuer for that Certificate | **required with create** |
| `certificate.existingSecret` | TLS Secret to use when `create` is false | `""` |
| `certReloader.enabled` | Sidecar that restarts derper when the certificate changes | `true` |
| `certReloader.intervalSeconds` | How often the sidecar checks | `60` |
| `extraArgs` | Extra derper flags, appended | `[]` |
| `priorityClassName` | Pod priority class | `""` |

Everything else (`image`, `resources`, `podSecurityContext`, `securityContext`,
`extraEnvs`, `extraVolumes`, `extraVolumeMounts`, `podAnnotations`,
`nodeSelector`, `tolerations`, `affinity`) follows the `common` library contract.

## How it works

- **Flags:** the chart sets `-hostname`, `-a=:<port>`, `-http-port`
  (`httpPort.port`, or `-1` for no plain-HTTP listener), `-certmode=manual`,
  `-certdir=/certs`, `-c` (node key on an emptyDir), `-stun`, `-stun-port` and
  `-verify-clients`.
- **Certificate files:** derper reads `<hostname>.crt` / `.key` from `-certdir`,
  with characters outside `[A-Za-z0-9.-]` stripped from the name. The chart maps
  the Secret's `tls.crt` / `tls.key` to those names.
- **Renewal:** derper loads the certificate once, at startup. The `cert-reloader`
  sidecar shares the pod's PID namespace and sends derper SIGTERM when the mounted
  certificate changes; derper exits cleanly and the kubelet restarts it with the
  new certificate. Relayed connections drop for a few seconds.
- **SNI:** derper rejects TLS handshakes whose SNI is not `hostname`, so a probe
  against the pod IP fails the handshake. That is why the probes use the
  plain-HTTP listener.
- **Updates:** the strategy is `Recreate`, because a replacement pod cannot bind
  the node's ports while the old one holds them.
- **Node key:** it lives on an emptyDir, so a new pod gets a new key, while a
  container restart keeps it. Clients learn the server key when they connect, so
  this needs no client-side change.

## Probes

With `verifyClients.enabled` and `httpPort.enabled` on and `probes` left empty,
the chart sets:

```yaml
readiness:
  httpGet: { host: 127.0.0.1, path: /debug/check, port: http-plain }
  periodSeconds: 10
  timeoutSeconds: 10
  failureThreshold: 3
liveness:
  httpGet: { host: 127.0.0.1, path: /debug/check, port: http-plain }
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 5
```

- **What they catch:** `/debug/check` runs derper's consistency check. With
  `-verify-clients` that check asks the node's tailscaled for its status, with a
  5-second timeout, and returns 500 when tailscaled is down, hung, or reachable
  only through a stale socket. The socket is a file bind mount, which keeps the
  inode the container started with. After tailscaled restarts on the node,
  derper keeps dialing the dead socket and rejects every client.
- **What they do:** readiness marks the pod not Ready about 30 s after the check
  starts failing. There is no Service, so this changes only the pod's status.
  Liveness restarts the derper container after five failures in a row, about
  2–2.5 minutes. The new container binds the socket at its current path and keeps
  the node key; the `cert-reloader` sidecar keeps running. While tailscaled stays
  down, derper restarts with the kubelet's back-off, up to 5 minutes apart.
- **Why 127.0.0.1:** the plain-HTTP listener serves `/debug` only to loopback and
  tailnet addresses. Under host networking, 127.0.0.1 is the node's loopback.
  Pod Security's baseline level forbids a probe `host` from Kubernetes 1.34, but
  host networking and the hostPath socket already need a privileged namespace.
  An `-a` with an address in `extraArgs` binds the listener to that address
  alone, and the probes reach it only if that address is 127.0.0.1.
- **Duplicate connections:** the check also fails while one client key holds two
  connections. A client that reconnects after a network change leaves its old
  connection open until a keepalive write fails, up to about 80 s, which the
  liveness window rides out. Two live devices sharing one node key, such as a
  cloned machine, keep it failing and restart derper every few minutes. Set your
  own `probes`, or `httpPort.enabled: false`, to turn the defaults off.
