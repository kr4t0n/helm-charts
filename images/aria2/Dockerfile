# syntax=docker/dockerfile:1

ARG ALPINE_IMAGE=alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

# AriaNg is static files, so it is unpacked once on the build platform.
FROM --platform=$BUILDPLATFORM ${ALPINE_IMAGE} AS ariang

ARG ARIANG_VERSION=1.3.15
ADD --checksum=sha256:d2317e441966ad31f1e342cb6a6cc1c51808fb0a10cf6e39cb30b0517b3e7823 \
    https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VERSION}/AriaNg-${ARIANG_VERSION}.zip /tmp/ariang.zip

# AriaNg's default RPC address is <page host>:6800 over http. Default to the page's
# own port and scheme instead, so it finds /jsonrpc through nginx or any ingress
# in front of it. grep fails the build if a new AriaNg release changes the source.
RUN mkdir /out && unzip -q /tmp/ariang.zip -d /out \
 && default='rpcPort:"6800",rpcInterface:"jsonrpc",protocol:"http",' \
 && grep -lF "$default" /out/js/aria-ng-*.min.js \
 && sed -i 's|rpcPort:"6800",rpcInterface:"jsonrpc",protocol:"http",|rpcPort:location.port\|\|(location.protocol==="https:"?"443":"80"),rpcInterface:"jsonrpc",protocol:location.protocol==="https:"?"https":"http",|' /out/js/aria-ng-*.min.js \
 && ! grep -qF "$default" /out/js/aria-ng-*.min.js

FROM ${ALPINE_IMAGE}

ARG ARIA2_VERSION
ARG ARIANG_VERSION=1.3.15
LABEL org.opencontainers.image.title="aria2" \
      org.opencontainers.image.description="aria2 download daemon with the AriaNg web UI, served by nginx on one port" \
      org.opencontainers.image.version="${ARIA2_VERSION}" \
      org.opencontainers.image.source="https://github.com/kr4t0n/helm-charts"

RUN test -n "${ARIA2_VERSION}" || { echo "ARIA2_VERSION build arg is required" >&2; exit 1; }
RUN apk add --no-cache "aria2~${ARIA2_VERSION}" nginx \
 && install -d -o 65532 -g 65532 /config /downloads

COPY --from=ariang /out /usr/share/ariang
COPY aria2.conf /etc/aria2/aria2.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
