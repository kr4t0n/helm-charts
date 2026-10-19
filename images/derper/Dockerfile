# syntax=docker/dockerfile:1

# Cross-compile on the build platform: derper is pure Go, so no emulation is needed.
FROM --platform=$BUILDPLATFORM golang:1.27.2-alpine3.24@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS build

ARG TAILSCALE_VERSION
ARG TARGETOS
ARG TARGETARCH

ENV CGO_ENABLED=0 \
    GOTOOLCHAIN=auto

RUN test -n "${TAILSCALE_VERSION}" || { echo "TAILSCALE_VERSION build arg is required" >&2; exit 1; }
# Cross-compiled installs land in $GOPATH/bin/<os>_<arch>/ instead of $GOPATH/bin/.
RUN GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      go install -trimpath -ldflags="-s -w" "tailscale.com/cmd/derper@v${TAILSCALE_VERSION}" \
 && install -D "$(find /go/bin -type f -name derper)" /out/derper

FROM gcr.io/distroless/static-debian13:nonroot@sha256:e2e927ec666bae08560abb3c55d0659eceabb657f56b6782ab500a9fc7f555e3

ARG TAILSCALE_VERSION
LABEL org.opencontainers.image.title="derper" \
      org.opencontainers.image.description="Tailscale DERP relay server, built from tailscale.com/cmd/derper" \
      org.opencontainers.image.version="${TAILSCALE_VERSION}" \
      org.opencontainers.image.source="https://github.com/kr4t0n/helm-charts"

COPY --from=build /out/derper /usr/local/bin/derper

USER 65532:65532
ENTRYPOINT ["/usr/local/bin/derper"]
