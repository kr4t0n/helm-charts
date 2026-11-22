# cliproxyapi

[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) serves OAuth-backed
coding-assistant subscriptions (Codex, Claude Code, Antigravity, Grok and more)
as OpenAI-, Gemini- and Claude-compatible APIs, with the
[management panel](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)
for logins and settings. Packaged from the upstream
[`eceasy/cli-proxy-api`](https://hub.docker.com/r/eceasy/cli-proxy-api) image,
and built on the shared [`common`](../common) library chart. Upstream ships no
Helm chart.

## Install

The chart refuses to render without client API keys, because upstream serves
every request unauthenticated when it has none. Put the management password in a
Secret, and the client keys in a values file:

```bash
kubectl create namespace cliproxyapi
kubectl -n cliproxyapi create secret generic cliproxyapi-env \
  --from-literal=MANAGEMENT_PASSWORD="$(openssl rand -hex 16)"
cat > cliproxyapi.values.yaml <<EOF
config:
  access:
    api-keys:
      - $(openssl rand -hex 24)
existingSecret:
  enabled: true
  name: cliproxyapi-env
EOF
helm repo add kr4t0n https://kr4t0n.github.io/helm-charts
helm repo update
helm install cliproxyapi kr4t0n/cliproxyapi -n cliproxyapi -f cliproxyapi.values.yaml
```

To keep the keys out of Helm values, seed from your own Secret instead
(`existingConfigSecret`), whose `config.yaml` sets `server.port: 8317` and
`access.api-keys`:

```bash
kubectl -n cliproxyapi create secret generic cliproxyapi-config --from-file=config.yaml
helm install cliproxyapi kr4t0n/cliproxyapi -n cliproxyapi \
  --set existingConfigSecret=cliproxyapi-config \
  --set existingSecret.enabled=true --set existingSecret.name=cliproxyapi-env
```

Then open the panel and sign in with `MANAGEMENT_PASSWORD`:

```bash
kubectl -n cliproxyapi port-forward svc/cliproxyapi 8317:8317
# http://127.0.0.1:8317/management.html
```

Clients use `http://cliproxyapi.cliproxyapi.svc:8317/v1` (or the ingress) with
one of the client keys as the bearer token.

## Configuration

| Key | Description | Default |
|---|---|---|
| `image.repository` | Image | `eceasy/cli-proxy-api` |
| `image.tag` | Tag (empty ⇒ chart `appVersion`) | `""` |
| `service.port` | Proxy API, `/healthz` and management port; also written to `config.server.port` | `8317` |
| `config` | Seed for `config.yaml` (upstream v8 layout); needs `access.api-keys` | client keys empty |
| `existingConfigSecret` | Secret with a `config.yaml` key to seed from instead of `config` | `""` |
| `overwriteConfig` | Re-seed `config.yaml` on every pod start | `false` |
| `args` | Extra CLIProxyAPI flags (e.g. `--local-model`) | `[]` |
| `existingSecret.{enabled,name}` | Load env vars (`MANAGEMENT_PASSWORD`, `GITHUB_TOKEN`, store settings) from a Secret | disabled |
| `persistence.size` | Data volume (`/data`: config, credentials, panel) size | `1Gi` |
| `persistence.storageClass` | StorageClass (empty ⇒ cluster default) | `""` |
| `podSecurityContext` | uid/gid the app runs and writes as | `65532` |
| `extraEnvs` | Extra env vars (e.g. `TZ`; the image defaults to `Asia/Shanghai`) | `[]` |
| `ingress.*` | See [`common`](../common) (className / hosts / tls) | disabled |

See [`values.yaml`](./values.yaml) for the full list.

## Notes

- **The app owns `config.yaml`.** It writes back the generated `server-id`, hashes
  a plaintext `management.secret-key`, and saves every panel edit to the file. So
  the file lives on the data volume, and the chart only seeds it: the
  `seed-config` init container copies the seed in when the volume has no
  `config.yaml`, and logs `keeping /data/config.yaml` otherwise. After the first
  start, **changes to `config` do not reach the running install.** Edit the
  settings in the panel, or set `overwriteConfig: true` to make the values the
  source of truth. Overwrite mode re-seeds on every start, so panel edits last
  only until the next restart. Pin `config.server.server-id` in that mode, or a
  new ID is generated on each start. To re-seed once, delete `/data/config.yaml`
  and restart the pod.
- **Data volume layout.** The volume is the container's working directory and
  `HOME`, so upstream's relative and `~` defaults all land on it:
  `config.yaml`, `.cli-proxy-api/` (OAuth credentials and the `kv.db` store),
  `static/management.html` (downloaded from GitHub on first visit), and `logs/`
  and `plugins/` once file logging or plugins are enabled.
- **Management access.** The management API is off until `MANAGEMENT_PASSWORD`
  or `config.management.secret-key` is set. `MANAGEMENT_PASSWORD` also allows
  non-localhost access, so the panel works through the Service and ingress. A
  config `secret-key` alone needs `management.allow-remote: true` for that, though
  `kubectl port-forward` always counts as localhost.
- **OAuth logins in the panel.** The provider redirects the browser to
  `http://localhost:<port>/…`, a port the pod listens on only during the login
  (1455 Codex, 54545 Claude, 51121 Antigravity). In a cluster that page fails to
  load. Copy the full URL from the address bar into the panel's callback field
  instead. Alternatively, port-forward that port to the pod for the duration of
  the login: `kubectl -n cliproxyapi port-forward deploy/cliproxyapi 1455:1455`.
- **CLI logins** run in the pod and write to the same auth directory, e.g. the
  Codex device-code flow, which needs no callback port:

  ```bash
  kubectl -n cliproxyapi exec -it deploy/cliproxyapi -- \
    /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser --codex-device-login
  ```

- **Streaming through an ingress.** Responses stream as SSE, so turn off proxy
  buffering and raise the read timeout (for ingress-nginx,
  `nginx.ingress.kubernetes.io/proxy-buffering: "off"` and
  `nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"`). Set
  `config.server.trusted-proxies` to the controller's addresses if the logs
  should show client IPs.
- **A singleton.** `replicaCount` above 1 fails to render: replicas cannot share
  `config.yaml` or the bbolt store. The default `Recreate` strategy frees the
  ReadWriteOnce volume before the replacement pod starts.
- **Non-root.** Upstream's image runs as root. The chart runs it as uid 65532,
  and `fsGroup` makes the data PVC writable for that uid.
