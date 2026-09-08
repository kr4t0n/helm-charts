# climage

[climage](https://github.com/kr4t0n/climage) — a batteries-included container
image for **CLI coding agents**: Node.js, a `uv`/`ruff` Python toolchain, the
command-line utilities agents shell out to (`rg`, `fd`, `jq`, `ffmpeg`, `gh`,
`sqlite3`, …), and the `claude`, `codex` and `skills` CLIs.

The image is an *environment*, not a service. This chart parks one long-lived
pod on the cluster with a **persistent home directory at `/home/climage`**, so
agent credentials, installed skills, runtime `npm install -g` packages and the
uv cache survive restarts. You enter it with `kubectl exec`. Built on the shared
[`common`](../common) library chart.

## Install

```bash
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install climage kr4t0n/climage -n climage --create-namespace
```

Then get a shell:

```bash
kubectl -n climage exec -it deploy/climage -- bash -l
```

Use a login shell (`bash -l`): Debian's `/etc/profile` rewrites `PATH`, and the
image installs a profile snippet that puts `~/.npm-global/bin` and `/opt/uv/bin`
back in front.

First start pulls ~2GB (~1.4GB for `image.tag: slim`), so expect a few minutes in
`ContainerCreating`.

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `kr4t0n/climage` |
| `image.tag` | `latest` (full), `slim`, or an immutable `sha-<short>` | `latest` |
| `service.port` | Port a dev server started *inside* the sandbox should bind | `8080` |
| `workingDir` | Container working directory (image default `/workspace`) | `""` |
| `persistence.enabled` | Back `/home/climage` with a PVC | `true` |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.volumes.home.mountPath` | Where the home PVC lands | `/home/climage` |
| `existingSecret.{enabled,name}` | `envFrom` a Secret holding agent API keys | disabled |
| `extraEnvs` | Extra env vars (`TZ`, `CLIMAGE_INIT`, proxies) | `[]` |
| `extraVolumes` / `extraVolumeMounts` | Bootstrap ConfigMap, SSH key, NFS share | `[]` |
| `extraInitContainers` | Ownership fix-up (see below), workspace seeding | `[]` |
| `resources` | Requests / limits | `{}` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Examples

### Agent credentials from a Secret

```bash
kubectl -n climage create secret generic climage-agent-keys \
  --from-literal=ANTHROPIC_API_KEY=sk-ant-... \
  --from-literal=GH_TOKEN=ghp_...
```

```yaml
existingSecret:
  enabled: true
  name: climage-agent-keys
```

Interactive `claude` / `codex` logins work too — the session is written under
`/home/climage`, i.e. onto the PVC, so it survives a restart.

### Bootstrap each container start

The image entrypoint *sources* the file named by `CLIMAGE_INIT` before running
the command, so it can export environment as well as run setup:

```bash
kubectl -n climage create configmap climage-init --from-file=init.sh
```

```yaml
extraEnvs:
  - name: CLIMAGE_INIT
    value: /etc/climage/init.sh
extraVolumes:
  - name: init
    configMap:
      name: climage-init
extraVolumeMounts:
  - name: init
    mountPath: /etc/climage
    readOnly: true
```

The ConfigMap is not managed by this chart, so editing it does not roll the pod
— `kubectl rollout restart deploy/climage` to pick up a change.

### Persist the workspace too

```yaml
persistence:
  volumes:
    home:
      mountPath: /home/climage
      claimNameSuffix: ""
    workspace:
      mountPath: /workspace
      size: 50Gi
```

That creates a second PVC, `climage-workspace`. The cheaper alternative is
`workingDir: /home/climage/workspace`, which keeps everything on one volume.

### Reach a dev server the agent started

Ad hoc, with no chart change:

```bash
kubectl -n climage port-forward deploy/climage 3000:3000
```

Or point the Service at it by setting `service.port: 3000`.

## Notes

- **No command override, by design.** The image's `CMD` (`climage-idle`) hands
  back a shell when it has a terminal and parks when it does not, so the stock
  `common` Deployment runs it unmodified. This chart therefore needs an image
  built from climage *after* that change; older tags default to `bash`, which
  exits on EOF and lands in `CrashLoopBackOff`.
- **Volume ownership is the one thing to check.** The container is uid/gid 1000
  and the `common` library has no `securityContext`/`fsGroup` support, so a
  provisioner that hands out `root`-owned volumes leaves the agent unable to
  write its own home. Provisioners that create world-writable volumes (rancher
  local-path, most NFS provisioners) are fine as-is; otherwise uncomment the
  `extraInitContainers` chown snippet in [`values.yaml`](./values.yaml), or
  chown the export to `1000:1000` on the storage server.
- **Mounting `$HOME` hides part of the image — harmlessly.** `~/.npm-global` and
  `~/.cache` as created in the build disappear behind the volume and are
  recreated. The toolchain is unaffected: uv interpreters and `uv tool` installs
  live in `/opt/uv`, the agent CLIs in `/usr/local/lib/node_modules`, precisely
  because home gets mounted over in deployments like this one.
- **Persist the whole home, not one directory.** Skills installed by the
  `skills` CLI live in `~/.agents/skills` and are *symlinked* into `~/.claude`
  and Codex's directory; persisting a single agent directory yields dangling
  links.
- **`/workspace` is ephemeral by default.** Only `/home/climage` is persisted
  unless you add a `workspace` volume (above).
- **One replica, and upgrades with a ReadWriteOnce PVC.** The library chart uses
  the default rolling update, so the replacement pod can sit in
  `ContainerCreating` until the old pod releases the volume. Scale to 0 first
  (or delete the old pod) if an upgrade appears stuck.
- **The Service has no listener until you start one.** Nothing in the image
  serves HTTP; `service.port` exists for a dev server an agent starts inside the
  sandbox. Leave the Ingress off unless there is an authenticating proxy in
  front — this is a shell environment, not an app.
- **Sizing.** No CPU limit is set on purpose: an agent's work is bursty
  (compiles, test suites, ffmpeg) and a CPU limit throttles exactly that.
  Consider an `ephemeral-storage` request instead — `/workspace` and `/tmp` come
  out of node disk while `$HOME` does not.

## Uninstall

```bash
helm uninstall climage -n climage
# PVCs are NOT deleted with the release — remove them explicitly:
kubectl -n climage delete pvc -l app.kubernetes.io/instance=climage
```
