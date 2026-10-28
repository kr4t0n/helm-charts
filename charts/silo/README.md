# Silo Helm Chart

> ## Vendored chart: keep local changes to the list below
>
> Unlike most charts here, this one is **not** built on the
> [`common`](../common) library. It is copied from Silo's own repository so
> it can be installed from this repository's Helm index: upstream ships the
> chart only as a folder in its repo, with no Helm repository, OCI chart or
> release asset.
>
> | | |
> |---|---|
> | Upstream | <https://github.com/pgsty/silo> |
> | Upstream path | `helm/silo` |
> | Vendored at | `c3ad836aed0d8a7d23c2e44a5eaa3009d08525e3` (signed tag `RELEASE.2026-10-26T00-00-00Z`) |
> | Upstream chart version | `7.0.3` |
> | Chart last changed upstream | `dcc2f20b`, *Preserve maintenance timeout behavior and prepare SILO 20261026*, 2026-10-26 |
> | License | AGPL-3.0-or-later, see [`LICENSE`](./LICENSE) |
>
> **Local modifications:**
> 1. This banner.
> 2. `LICENSE`, copied from the root of the upstream repo at the same commit.
>    Upstream's chart folder has none.
>
> To install from this repository's index, add it once, then use
> `kr4t0n/silo` where the commands below use `./helm/silo`:
>
> ```bash
> helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
> helm search repo kr4t0n/silo --versions
> ```
>
> **To sync:** copy `helm/silo/` and the root `LICENSE` from upstream at a
> newer release tag, re-apply the local modifications above, update this
> table, and bump `version` in `Chart.yaml` so chart-releaser publishes it.

This chart installs Silo, an independently maintained, S3-compatible object
storage server, on Kubernetes. It supports standalone and distributed modes.
The chart and server are licensed under AGPL-3.0-or-later.

## Prerequisites

- Kubernetes 1.19 or later
- Helm 3
- A PersistentVolume provisioner unless `persistence.enabled=false`

## Install

From this repository:

```bash
helm install silo ./helm/silo \
  --namespace silo --create-namespace \
  --set rootUser=silo-admin \
  --set rootPassword='replace-with-a-long-random-secret'
```

For a disposable standalone installation:

```bash
helm install silo ./helm/silo \
  --namespace silo --create-namespace \
  --set mode=standalone \
  --set replicas=1 \
  --set persistence.enabled=false \
  --set resources.requests.memory=512Mi \
  --set rootUser=silo-admin \
  --set rootPassword='replace-with-a-long-random-secret'
```

The default server and post-install image is `docker.io/pgsty/silo`. The image
contains the `silo` server, `mcli`, and an `mc` compatibility symlink. It does
not contain a `minio` server binary.

## Compatibility contract

The product and delivery names are Silo, while established interfaces remain
compatible:

- `MINIO_*` environment variables and existing values keys are unchanged.
- `/minio/*` API and metrics routes are unchanged.
- `minio_*` Prometheus metrics and `x-minio-*` protocol headers are unchanged.
- Existing storage, including `.minio.sys`, is used without conversion.
- `nameOverride`, `fullnameOverride`, and `serviceAccount.name` can pin existing
  Kubernetes resource identities during an upgrade.

New installations default to Silo resource names and the `silo-sa` service
account.

## Upgrade an existing release

Do not upgrade an existing release without first pinning its current resource
names. Export the complete values and render the candidate chart offline:

```bash
helm get values my-release -n my-namespace -a > values.before-silo.yaml
SILO_TAG='<published-silo-release-tag>'
MCLI_TAG='<published-mcli-release-tag>'

helm template my-release ./helm/silo \
  -n my-namespace \
  -f values.before-silo.yaml \
  --set nameOverride=minio \
  --set fullnameOverride=my-existing-fullname \
  --set serviceAccount.name=minio-sa \
  --set image.repository=pgsty/silo \
  --set mcImage.repository=pgsty/mc \
  --set-string image.tag="${SILO_TAG}" \
  --set-string mcImage.tag="${MCLI_TAG}" \
  > rendered.silo.yaml
```

Compare the old and new manifests. Stop if the candidate changes immutable
selectors, StatefulSet or Service identity, PVC names, Secrets, or storage
mounts. After review, upgrade the chart and image together:

```bash
SILO_TAG='<published-silo-release-tag>'
MCLI_TAG='<published-mcli-release-tag>'
helm upgrade my-release ./helm/silo \
  -n my-namespace \
  -f values.before-silo.yaml \
  --set nameOverride=minio \
  --set fullnameOverride=my-existing-fullname \
  --set serviceAccount.name=minio-sa \
  --set image.repository=pgsty/silo \
  --set mcImage.repository=pgsty/mc \
  --set-string image.tag="${SILO_TAG}" \
  --set-string mcImage.tag="${MCLI_TAG}"
```

Rollback is chart-level: use `helm rollback`, not an image-only downgrade. The
new chart invokes `silo server`; an old image does not provide that executable.
The new image accepts a legacy first argv token of `minio` only to support old
chart commands during the forward migration.

## Persistence and TLS

The default PersistentVolumeClaim mounts at `/export`. Use an existing claim
with:

```bash
helm install silo ./helm/silo --set persistence.existingClaim=PVC_NAME
```

Create a TLS Secret containing `private.key` and `public.crt`, then set:

```bash
helm upgrade --install silo ./helm/silo \
  --set tls.enabled=true \
  --set tls.certSecret=silo-tls
```

Additional trusted CAs can be supplied through `trustedCertsSecret`.

## Existing Secrets and post-install resources

Set `existingSecret` to a Secret containing `rootUser` and `rootPassword`.
Buckets, users, policies, service accounts, and custom commands can be created
with the existing `buckets`, `users`, `policies`, `svcaccts`, and
`customCommands` values. The post-install job uses `mcli` through its `mc`
compatibility command. New custom commands should target `mysilo`; the legacy
`myminio` target remains registered so existing values continue to work.

## Configuration

See [values.yaml](./values.yaml) for the complete values surface and the
[Silo documentation](https://silo.pgsty.com/) for server operations.

To uninstall the chart:

```bash
helm uninstall silo -n silo
```

PersistentVolumeClaims may remain after uninstall; inspect them before any
manual deletion.
