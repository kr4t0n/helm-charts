# javalin Helm chart

Deploy [javalin](https://github.com/kr4t0n/javalin) — a self-hosted
JavDB scraper that emits Kodi/Jellyfin-compatible NFO files and
artwork — into any Kubernetes cluster.

## TL;DR

```bash
helm repo add javalin https://kr4t0n.github.io/javalin
helm repo update
helm install javalin javalin/javalin --namespace javalin --create-namespace
kubectl port-forward -n javalin svc/javalin 8000:8000
open http://127.0.0.1:8000
```

## Requirements

- Kubernetes 1.24+
- Helm 3.10+
- A `ReadWriteOnce` storage class. `persistence.enabled: false` renders no
  data volume at all — see *Ephemeral `/data`* below if you want a demo
  install without a PVC.
- The published image is **multi-arch** (`linux/amd64` + `linux/arm64`),
  so any modern Kubernetes cluster will pull the right variant
  automatically.

## Why a single replica?

javalin keeps its job queue and `curl_cffi` session in process. Two
replicas would race for the same RWO volume and produce inconsistent
NFOs, so the chart hard-codes `replicas: 1` with a `Recreate` rollout
strategy.

## Configuration

| Key                       | Description                                                   | Default               |
|---------------------------|---------------------------------------------------------------|-----------------------|
| `image.repository`        | Container image                                               | `kr4t0n/javalin`      |
| `image.tag`               | Image tag (defaults to `Chart.appVersion` when unset)         | `""`                  |
| `image.pullPolicy`        | Image pull policy                                             | `IfNotPresent`        |
| `imagePullSecrets`        | Secrets used to pull the image                                | `[]`                  |
| `service.type`            | Kubernetes Service type                                       | `ClusterIP`           |
| `service.port`            | Service port                                                  | `8000`                |
| `ingress.enabled`         | Create an Ingress object                                      | `false`               |
| `ingress.className`       | Ingress class                                                 | `""`                  |
| `ingress.hosts`           | Ingress host rules                                            | `[javalin.local /]`   |
| `ingress.tls`             | TLS blocks                                                    | `[]`                  |
| `persistence.enabled`     | Mount a PVC at `/data`                                        | `true`                |
| `persistence.volumes.data.existingClaim` | Use an existing PVC instead of creating one    | unset                 |
| `persistence.size`        | PVC requested size                                            | `10Gi`                |
| `persistence.storageClass`| PVC storage class                                             | `""`                  |
| `persistence.volumes.data.mountPath` | Where the data PVC lands (match `JAVALIN_DATA`)    | `/data`               |
| `extraEnvs`               | Container env, incl. `JAVALIN_DATA` and any proxy vars        | `JAVALIN_DATA=/data`  |
| `probes.{startup,liveness,readiness}` | Health probes against `/api/outputs`              | enabled               |
| `strategy`                | Deployment update strategy                                    | `Recreate`            |
| `podSecurityContext` / `securityContext` | Pod- and container-level security context  | uid 1000, gid 100     |
| `extraEnv`                | Extra env entries (full Kubernetes shape)                     | `[]`                  |
| `resources`               | Pod resource requests/limits                                  | `{}`                  |
| `nodeSelector`            | Node selectors                                                | `{}`                  |
| `tolerations`             | Tolerations                                                   | `[]`                  |
| `affinity`                | Affinity rules                                                | `{}`                  |
| `podSecurityContext`      | Pod-level security context                                    | non-root, uid 1000 / gid 100 |
| `securityContext`         | Container-level security context                              | drop ALL caps         |

See [`values.yaml`](./values.yaml) for the full list with comments.

## Examples

### Expose via Ingress (Traefik)

```yaml
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: javalin.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: javalin-tls
      hosts:
        - javalin.example.com
```

### Bring your own PVC

```yaml
persistence:
  enabled: true
      existingClaim: my-existing-media-pvc
```

### Use different uid/gid

The image defaults to uid `1000` / gid `100` (the typical NAS user).
Override the chart values to match your storage class / node convention:

```yaml
podSecurityContext:
  runAsUser: 1500
  runAsGroup: 1500
  fsGroup: 1500            # MUST match the gid you want on the PVC
  runAsNonRoot: true
securityContext:
  runAsUser: 1500
  runAsGroup: 1500
```

If you're upgrading from chart `0.1.x` (which defaulted to uid 1001),
the kubelet will recursively reapply ownership matching the new
`fsGroup` to the existing PVC on the next pod start, so writes resume
without manual chown.

### Route traffic through an HTTP proxy

When the cluster's egress can't reach `javdb.com` directly (common in
restricted regions or corporate networks), add the proxy variables to
`extraEnvs`. Set the upper- *and* lower-case spellings so libcurl and any
Python HTTP client downstream both pick them up:

```yaml
extraEnvs:
  - name: JAVALIN_DATA
    value: /data
  - name: HTTP_PROXY
    value: "http://proxy.corp.example.com:8080"
  - name: http_proxy
    value: "http://proxy.corp.example.com:8080"
  - name: HTTPS_PROXY
    value: "http://proxy.corp.example.com:8080"
  - name: https_proxy
    value: "http://proxy.corp.example.com:8080"
  # Bypass the proxy for in-cluster traffic.
  - name: NO_PROXY
    value: "localhost,127.0.0.1,.svc,.svc.cluster.local,.cluster.local"
  - name: no_proxy
    value: "localhost,127.0.0.1,.svc,.svc.cluster.local,.cluster.local"
```

`extraEnvs` replaces the whole list, so keep `JAVALIN_DATA` when you add to it.

### Ephemeral `/data`

`persistence.enabled: false` renders no data volume at all. For a demo install
with scratch space that is wiped on pod restart, mount an `emptyDir` yourself:

```yaml
persistence:
  enabled: false
extraVolumes:
  - name: data
    emptyDir: {}
extraVolumeMounts:
  - name: data
    mountPath: /data
```

## Uninstall

```bash
helm uninstall javalin -n javalin
# Persistent volume is NOT deleted — clean up manually if you don't need it:
kubectl delete pvc -n javalin -l app.kubernetes.io/instance=javalin
```
