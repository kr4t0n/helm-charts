# registry

A [Docker Registry](https://distribution.github.io/distribution/) (the official
`registry` image) for hosting container images in-cluster. Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install registry kr4t0n/registry -n registry --create-namespace
```

Reach it in-cluster at `registry.<namespace>:5000`, or:

```bash
kubectl -n registry port-forward svc/registry 5000:5000
# docker push 127.0.0.1:5000/my-image
```

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `registry` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Registry port | `5000` |
| `persistence.enabled` | Back `/var/lib/registry` with a PVC | `false` |
| `persistence.size` | PVC size when enabled | `20Gi` |
| `extraEnvs` | `REGISTRY_*` config env vars | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- ⚠️ **Persistence is off by default** (matching the previous chart): pushed
  images live on the container filesystem and are **lost on pod restart**. For
  a durable registry set `persistence.enabled=true` — that mounts a PVC at
  `/var/lib/registry`.
- **Config** is via `REGISTRY_*` environment variables (`extraEnvs`), e.g.
  `REGISTRY_STORAGE_DELETE_ENABLED=true` to allow image deletion.
- **Image version**: `appVersion` tracks the current `registry` 3.1.x (the
  prior `3.0.0` was older than `latest`). Pin `image.tag` for a specific build.
