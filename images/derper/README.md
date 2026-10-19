# derper image

Tailscale's DERP relay server (`tailscale.com/cmd/derper`), built from source.
Tailscale publishes no official derper image or chart, so this image is built
here at a pinned Tailscale version.

- **Version:** `VERSION` holds the Tailscale release to build, and is also the
  image tag (`kr4t0n/derper:<version>`). A `sha-<commit>` tag is pushed alongside
  it.
- **Base images:** pinned by digest. The binary is static (`CGO_ENABLED=0`) and
  runs as uid/gid 65532 (distroless `nonroot`). The user is numeric so that
  Kubernetes `runAsNonRoot` can verify it.
- **Platforms:** `linux/amd64` and `linux/arm64`, cross-compiled without emulation.
- **CI:** `.github/workflows/derper-image.yml` builds on pull requests and pushes
  to Docker Hub on `main`. It needs the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
  repository secrets.

## Build locally

```bash
docker buildx build --build-arg TAILSCALE_VERSION="$(cat VERSION)" -t derper:dev .
docker run --rm derper:dev -h
```

## Running notes

- As a non-root user, derper needs `-c <path>` pointing at a writable file for its
  node key. It creates the file on first start.
- `--verify-clients` asks the local `tailscaled` over its socket; mount the host's
  `/var/run/tailscale/tailscaled.sock`.
- With `-certmode manual`, derper reads `<hostname>.crt` and `<hostname>.key` from
  `-certdir` **once, at startup**. A renewed certificate takes effect only after a
  restart.
