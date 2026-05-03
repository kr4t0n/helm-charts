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
- A `ReadWriteOnce` storage class (PVC is required by default for
  persistence). Disable with `--set persistence.enabled=false` if you
  just want an ephemeral demo.
- An **arm64** node — the published image is `linux/arm64` only.
  Pin pods with `--set nodeSelector."kubernetes.io/arch"=arm64`.

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
| `persistence.existingClaim` | Use an existing PVC instead of creating one                 | `""`                  |
| `persistence.size`        | PVC requested size                                            | `10Gi`                |
| `persistence.storageClass`| PVC storage class                                             | `""`                  |
| `env.JAVALIN_DATA`        | Path the backend uses for inputs/outputs                      | `/data`               |
| `extraEnv`                | Extra env entries (full Kubernetes shape)                     | `[]`                  |
| `resources`               | Pod resource requests/limits                                  | `{}`                  |
| `nodeSelector`            | Node selectors                                                | `{}`                  |
| `tolerations`             | Tolerations                                                   | `[]`                  |
| `affinity`                | Affinity rules                                                | `{}`                  |
| `podSecurityContext`      | Pod-level security context                                    | non-root, uid/gid 1001|
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

### Pin to arm64 nodes

```yaml
nodeSelector:
  kubernetes.io/arch: arm64
```

## Uninstall

```bash
helm uninstall javalin -n javalin
# Persistent volume is NOT deleted — clean up manually if you don't need it:
kubectl delete pvc -n javalin -l app.kubernetes.io/instance=javalin
```
