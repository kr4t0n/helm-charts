# derper

Tailscale [DERP relay](https://tailscale.com/kb/1118/custom-derp-servers) server,
from the `kr4t0n/derper` image built in this repo (`images/derper`). Built on the
`common` library chart (>= 0.6.0).

One release runs one DERP node. The pod uses the node's network, so clients reach
it at the node's public address; there is no Service.

## Prerequisites

- **Open ports** on the node's firewall or security group: `service.port` (TCP,
  default 56443) and `stun.port` (UDP, default 3478).
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
| `verifyClients.enabled` | Admit only tailnet devices, via the node's tailscaled | `true` |
| `verifyClients.socket` | Host path of the tailscaled socket | `/var/run/tailscale/tailscaled.sock` |
| `certificate.create` | Render a cert-manager `Certificate` for `hostname` | `true` |
| `certificate.issuerRef` | Issuer for that Certificate | **required with create** |
| `certificate.existingSecret` | TLS Secret to use when `create` is false | `""` |
| `certReloader.enabled` | Sidecar that restarts derper when the certificate changes | `true` |
| `certReloader.intervalSeconds` | How often the sidecar checks | `60` |
| `extraArgs` | Extra derper flags, appended | `[]` |
| `priorityClassName` | Pod priority class | `""` |

Everything else (`image`, `resources`, `probes`, `podSecurityContext`,
`securityContext`, `extraEnvs`, `extraVolumes`, `extraVolumeMounts`,
`podAnnotations`, `nodeSelector`, `tolerations`, `affinity`) follows the `common`
library contract.

## How it works

- **Flags:** the chart sets `-hostname`, `-a=:<port>`, `-http-port=-1` (no plain
  HTTP listener), `-certmode=manual`, `-certdir=/certs`, `-c` (node key on an
  emptyDir), `-stun`, `-stun-port` and `-verify-clients`.
- **Certificate files:** derper reads `<hostname>.crt` / `.key` from `-certdir`,
  with characters outside `[A-Za-z0-9.-]` stripped from the name. The chart maps
  the Secret's `tls.crt` / `tls.key` to those names.
- **Renewal:** derper loads the certificate once, at startup. The `cert-reloader`
  sidecar shares the pod's PID namespace and sends derper SIGTERM when the mounted
  certificate changes; derper exits cleanly and the kubelet restarts it with the
  new certificate. Relayed connections drop for a few seconds.
- **SNI:** derper rejects TLS handshakes whose SNI is not `hostname`, so a probe
  against the pod IP fails the handshake. That is why no probes are set by
  default.
- **Updates:** the strategy is `Recreate`, because a replacement pod cannot bind
  the node's ports while the old one holds them.
- **Node key:** it lives on an emptyDir, so a new pod gets a new key. Clients learn
  the server key when they connect, so this needs no client-side change.
