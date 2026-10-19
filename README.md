# customized helm charts

- `charts/`: Helm charts, published by chart-releaser (`.github/workflows/release.yml`).
  Most build on the in-repo `common` library chart.
- `images/`: container images for charts that have no official upstream image,
  each with its own build workflow:
  - `images/derper`: Tailscale DERP relay (`kr4t0n/derper`), see its README.
