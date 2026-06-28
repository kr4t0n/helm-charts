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
| `persistence.enabled` | Back `/var/lib/registry` with a PVC | `true` |
| `persistence.size` | PVC size | `20Gi` |
| `extraEnvs` | `REGISTRY_*` config env vars | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **Persistence is on by default**: a PVC is mounted at `/var/lib/registry`, so
  pushed images survive pod restarts/rescheduling. Set `persistence.enabled=false`
  for an ephemeral registry (images on the container filesystem, lost on restart).
  Alternatively, point it at object storage (S3/GCS/…) via `REGISTRY_STORAGE_*`
  in `extraEnvs` and leave persistence off.
- **Config** is via `REGISTRY_*` environment variables (`extraEnvs`), e.g.
  `REGISTRY_STORAGE_DELETE_ENABLED=true` to allow image deletion.
- **Image version**: `appVersion` tracks the current `registry` 3.1.x (the
  prior `3.0.0` was older than `latest`). Pin `image.tag` for a specific build.
