# comfyui

[ComfyUI](https://github.com/Comfy-Org/ComfyUI) — the node-graph frontend and
backend for generative image/video pipelines. This chart deploys the **CPU-only**
build ([`yanwk/comfyui-boot:cpu`](https://hub.docker.com/r/yanwk/comfyui-boot)),
intended as a *graph orchestrator*: the workflow executes in-cluster while the
actual model inference is delegated to remote APIs. Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install comfyui kr4t0n/comfyui -n comfyui --create-namespace
```

Then open the web UI:

```bash
kubectl -n comfyui port-forward svc/comfyui 8188:8188
# http://127.0.0.1:8188
```

First start is slow: the image is ~3.4GB to pull, and the entrypoint copies the
bundled ComfyUI into the (empty) PVC before serving.

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `yanwk/comfyui-boot` |
| `image.tag` | CPU build tag (dated; `cpu` is the rolling tag) | `cpu-20260824` |
| `service.port` | Web UI / API port | `8188` |
| `persistence.enabled` | Back `/root` with a PVC | `true` |
| `persistence.size` | PVC size | `20Gi` |
| `extraEnvs` | Extra env vars (`CLI_ARGS`, `TZ`, API keys) | `[]` |
| `existingSecret.{enabled,name}` | `envFrom` a Secret holding provider API keys | disabled |
| `extraVolumes` / `extraVolumeMounts` | e.g. an NFS share for outputs | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **CPU-only by design.** The `cpu` image is built without the CUDA/ROCm
  runtimes and sets `CLI_ARGS=--cpu`, so ComfyUI never probes for a GPU and no
  device plugin, node selector or toleration is needed. Local model execution
  still *works*, just slowly — this chart assumes you won't do it.
- **Remote inference / API keys.** Nothing in the chart forces remote execution;
  it comes from the nodes you use:
  - *ComfyUI API Nodes* (the built-in Comfy Org ones) authenticate from the
    browser — sign in or paste an API key in the UI. It is stored under
    `/root/ComfyUI/user`, i.e. on the PVC, so it survives restarts. There is no
    server-side env var for it. `--comfy-api-base` (via `CLI_ARGS`) repoints
    them at a different API host.
  - *Third-party nodes* (OpenAI, fal, Replicate, an OpenAI-compatible endpoint,
    …) read process env vars. Put those keys in a Secret and reference it with
    `existingSecret`, rather than inlining them into `extraEnvs`.
- **One PVC holds the whole install.** `/root` is the image's storage root: the
  ComfyUI checkout, `custom_nodes/`, `pip --user` packages, `models/`, `input/`,
  `output/` and `user/` (settings + saved workflows). That means nodes installed
  through the bundled ComfyUI-Manager — and their pip deps — persist across pod
  restarts. It also means `persistence.enabled=false` throws away every node you
  install; keep it on. 20Gi is sized for an API-driven setup with an empty
  `models/`; raise it if you pull local checkpoints.
- **No built-in authentication.** ComfyUI ships none, and the container runs as
  root. Keep the Service `ClusterIP` and port-forward, or put an authenticating
  proxy in front before enabling `ingress`.
- **Ingress and long jobs.** The UI streams progress over a websocket and remote
  API calls can run for minutes, so raise your controller's proxy timeouts (for
  ingress-nginx, `nginx.ingress.kubernetes.io/proxy-read-timeout: "600"` and
  `proxy-send-timeout`) via `ingress.annotations`.
- **Upgrades with a ReadWriteOnce PVC.** The Deployment uses the default rolling
  update, so the replacement pod can sit in `ContainerCreating` until the old
  pod releases the volume. Scale to 0 first (or delete the old pod) if an
  upgrade appears stuck.
- **Image version.** `appVersion` is the ComfyUI release bundled in the image
  (the newest stable tag at image build time); `image.tag` is the image's own
  dated CPU build. Bump both together when moving to a newer build, or set
  `image.tag: cpu` to always take the latest.
