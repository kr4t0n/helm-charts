# common — shared Helm library chart

A Helm [library chart](https://helm.sh/docs/topics/library_charts/) that holds
the deployment / service / ingress / pvc / label boilerplate shared by the
application charts in this repo. It renders nothing on its own; application
charts depend on it and call its named templates from one-line stubs.

## Usage

1. Declare the dependency in the application chart's `Chart.yaml`:

   ```yaml
   dependencies:
     - name: common
       version: ">=0.2.2 <1.0.0"
       repository: file://../common
   ```

   Use a range, not an exact pin. An exact pin makes every library bump fail
   `helm dependency update` for that chart until it is edited, which breaks CI
   for the whole repo at once.

2. Vendor it: `helm dependency build charts/<app>`.

3. Reduce each template to a single include:

   ```yaml
   # templates/deployment.yaml
   {{- include "common.deployment" . }}
   # templates/service.yaml   -> {{- include "common.service" . }}
   # templates/ingress.yaml   -> {{- include "common.ingress" . }}
   # templates/pvc.yaml       -> {{- include "common.pvc" . }}
   ```

4. Put all per-application variation in `values.yaml` (see the table below).

## Templates

| Template             | Renders                                                       |
|----------------------|--------------------------------------------------------------|
| `common.deployment`  | Single-container `Deployment` (ports, env, volumes, probes…) |
| `common.service`     | `Service` exposing `http` + `service.extraPorts`             |
| `common.ingress`     | `Ingress` from `ingress.{className,hosts,tls}`               |
| `common.pvc`         | One `PersistentVolumeClaim` per `persistence.volumes` entry  |
| `common.labels` / `common.selectorLabels` / `common.fullname` / `common.image` | helpers |

## Values contract

| Key                          | Description                                              | Default        |
|------------------------------|----------------------------------------------------------|----------------|
| `image.repository`           | Container image                                          | —              |
| `image.tag`                  | Image tag; falls back to `Chart.appVersion` when empty  | `""`           |
| `image.pullPolicy`           | Pull policy                                              | `IfNotPresent` |
| `replicaCount`               | Replicas                                                | `1`            |
| `strategy`                   | Verbatim Deployment update strategy                     | unset          |
| `service.{type,port}`        | Service type and primary `http` port                    | —              |
| `service.hostPort`           | Bind `http` on the host as well                         | `false`        |
| `service.extraPorts`         | Extra Service ports                                     | `[]`           |
| `extraPorts`                 | Extra container ports                                   | `[]`           |
| `workingDir`                 | Container working directory                             | unset          |
| `resources`                  | Resource requests/limits                               | `{}`           |
| `existingSecret.{enabled,name}` | `envFrom` a pre-existing Secret                     | disabled       |
| `extraEnvs`                  | Additional `env` entries                               | `[]`           |
| `probes.{startup,liveness,readiness}` | Verbatim container probes             | unset          |
| `podSecurityContext`         | Pod-level `securityContext`                             | unset          |
| `securityContext`            | Container-level `securityContext`                       | unset          |
| `persistence.enabled`        | Create PVCs and mount them                             | `true`         |
| `persistence.storageClass`   | Default StorageClass (empty ⇒ cluster default)         | `""`           |
| `persistence.accessModes`    | Default access modes                                   | `[ReadWriteOnce]` |
| `persistence.volumes`        | Map of `name → {mountPath, size, [storageClass], [accessModes], [subPath], [existingClaim], [claimNameSuffix], [annotations]}` | — |
| `extraVolumes` / `extraVolumeMounts` | Free-form additions                            | `[]`           |
| `extraInitContainers`        | Init containers to run before the app container         | `[]`           |
| `podAnnotations` / `imagePullSecrets` | Pod-level settings                            | unset          |
| `nodeSelector` / `tolerations` / `affinity` | Scheduling                              | unset          |

### Init containers

`extraInitContainers` is a raw list of container specs, passed through to
`spec.template.spec.initContainers` verbatim. Mounts are not injected — to reach
a `persistence.volumes` entry, mount its pod volume, which is named
`<key>-volume` (not the PVC name):

```yaml
persistence:
  volumes:
    data:
      mountPath: /root

extraInitContainers:
  - name: fix-perms
    image: busybox:1.36
    command: ["sh", "-c", "chown -R 1000:1000 /root"]
    securityContext:
      runAsUser: 0
    volumeMounts:
      - name: data-volume   # <key>-volume
        mountPath: /root
```

### Security contexts

Two separate API objects, following the `helm create` naming convention:

- `podSecurityContext` → `spec.template.spec.securityContext` (pod-level:
  `runAsUser`, `runAsGroup`, `fsGroup`, `fsGroupChangePolicy`, `supplementalGroups`…)
- `securityContext` → the container's `securityContext` (container-level:
  `allowPrivilegeEscalation`, `capabilities`, `readOnlyRootFilesystem`…)

Both are passed through verbatim and are independently optional.

```yaml
podSecurityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  fsGroupChangePolicy: OnRootMismatch

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

Three things that bite in practice:

- **`fsGroup` grants group access to every file on every mounted volume.** It is
  not just a chown: the kubelet ORs permission bits in — `0660` on files, `0770`
  plus setgid on directories — and never removes any. A `0600` private key
  becomes `0660`, which OpenSSH then refuses; a `0700` directory becomes `2770`.
  That is the right trade for a volume holding data and the wrong one for a
  volume holding credentials, where a targeted init container that chowns a
  single path is safer. `fsGroup` is also pod-wide and cannot be scoped to one
  volume, so every extra mount — including a shared NFS export — gets the same
  treatment.
- **`fsGroup` recursively walks the volume on every mount.** On a large volume
  that can add minutes to pod start, and the pod is not Ready in the meantime.
  Set `fsGroupChangePolicy: OnRootMismatch` so the kubelet only walks when the
  root does not already match. Note the match test covers the setgid bit and
  group rwx, not just the gid — a volume at mode `0755` is a mismatch even when
  its group is already correct, so the first walk happens regardless.
- **Whether `fsGroup` applies at all depends on the CSI driver.** Check
  `kubectl get csidrivers -o custom-columns=NAME:.metadata.name,P:.spec.fsGroupPolicy`.
  `File` applies it unconditionally; `ReadWriteOnceWithFSType` applies it only to
  RWO volumes that declare an `fsType`, so a raw-block PV is silently skipped;
  the in-tree NFS plugin ignores it entirely.
- **`runAsNonRoot: true` fails closed.** If the image's default user is root
  and no `runAsUser` is given, the kubelet refuses to start the container with
  `CreateContainerConfigError` rather than running it. Set `runAsUser`
  alongside it, and check the image actually supports that uid.
- **`readOnlyRootFilesystem: true` needs writable scratch space.** Most images
  write to `/tmp` at minimum; add an `emptyDir` via `extraVolumes` /
  `extraVolumeMounts` for each path the app writes to outside its data volume.

Fields set at both levels are resolved by Kubernetes, not this library: the
container-level value wins for the container, while `fsGroup` is pod-only and
has no container-level equivalent.

### Update strategy

`strategy` is passed through verbatim to `spec.strategy`. Left unset, Kubernetes
applies its default (`RollingUpdate` with `maxSurge: 25%`,
`maxUnavailable: 25%`).

```yaml
strategy:
  type: Recreate
```

**Set `Recreate` for any singleton app on a ReadWriteOnce volume or a hostPort.**
At `replicaCount: 1` the default percentages round to `maxSurge: 1` (up) and
`maxUnavailable: 0` (down) — "keep one pod available, you may briefly run two".
So Kubernetes starts the replacement *before* retiring the old pod, while the
old pod still holds the volume. What follows depends on scheduling, and neither
branch is good:

- **Different node** — `Multi-Attach error`; the new pod is stuck and the old
  one may not be removed, so the rollout deadlocks until
  `progressDeadlineSeconds` (600s) marks it failed. The old pod keeps serving,
  so this is easy to miss.
- **Same node** — ReadWriteOnce is per *node*, not per pod, so the new pod
  mounts the volume successfully and two instances run against the same state.

`Recreate` terminates the old pod first, releasing the volume before the
replacement needs it, at the cost of a short downtime window. That is the right
trade for a self-hosted singleton; it is the wrong trade for a stateless
replicated service, which is why this is opt-in rather than the library default.

Rolling update parameters can be tuned explicitly instead:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
```

Kubernetes rejects `rollingUpdate` when `type: Recreate`; the library passes the
value through unvalidated, so that pairing is the chart's responsibility.

Because `strategy` sits outside the pod template, changing it alone never
triggers a rollout — and when a chart adopts it, the new strategy and the new
pod template land in the same apply, so the first rollout already uses it.

### Probes

Each of `probes.startup`, `probes.liveness` and `probes.readiness` is a verbatim
Kubernetes probe object, passed straight through. Any probe kind works —
`httpGet`, `exec`, `tcpSocket`, `grpc` — because the library does not interpret
the contents. All three are independently optional; omit `probes` entirely and
the rendered Deployment is unchanged.

```yaml
probes:
  startup:
    httpGet: { path: /api/v1/status, port: http }
    periodSeconds: 5
    failureThreshold: 120     # tolerate a 10-minute first boot
  readiness:
    httpGet: { path: /api/v1/status, port: http }
    periodSeconds: 10
  liveness:
    httpGet: { path: /api/v1/status, port: http }
    periodSeconds: 30
```

**A readiness probe is the difference between a slow start and an outage.**
Without one, a pod reports `Ready` the moment its process is created, so the
Service routes traffic to a port nothing is listening on yet and callers get
connection refused. With one, the pod stays out of the Service until it answers,
and shows `0/1 Running` so the cause is visible.

**Set `startup` whenever you set `liveness` on an app with a slow first boot.**
Liveness begins counting immediately, so on an app that migrates a database or
builds an index at startup it will kill the container mid-migration and retry
forever against half-applied state. The startup probe holds liveness off until
the app answers once; size its `failureThreshold × periodSeconds` to the worst
first boot you expect, not the typical one.

Port names work in probes (`port: http` above) because the container's primary
port is always named `http`.

## Backward compatibility (in-place upgrades)

The library reproduces the pre-library charts' resource names and selector so an
existing release upgrades in place — no PVC rename, no immutable-selector error:

- **Resource name** == `.Release.Name` (set `fullnameOverride` to change).
- **Selector** == `app: <release>` (the standard `app.kubernetes.io/*` labels are
  added *additively*, never to the selector).
- **PVC names** are controlled per volume with `claimNameSuffix`:
  - omit it → `<release>-<key>` (matches the suffixed multi-PVC charts, e.g.
    `kikoeru-sqlite`);
  - set it to `""` → `<release>` (matches single-PVC charts whose legacy PVC was
    named exactly after the release, e.g. `tautulli`);
  - set it to a string → `<release>-<string>`.

Image tags are left to each chart; keep `image.tag: latest` to preserve current
behaviour, or pin to a real published tag (and bump `appVersion`) deliberately.

## Versioning

Bump `version` in `Chart.yaml` on any template change, then re-run
`helm dependency build` for each consuming chart so the vendored copy and
`Chart.lock` update.
