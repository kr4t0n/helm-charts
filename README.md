# customized helm charts

- `charts/`: Helm charts, published by chart-releaser (`.github/workflows/release.yml`).
  Most build on the in-repo `common` library chart.
- `images/`: container images for charts that have no official upstream image,
  each with its own build workflow:
  - `images/derper`: Tailscale DERP relay (`kr4t0n/derper`), see its README.

## Setup

- Prerequisites: [pre-commit](https://pre-commit.com) and [gitleaks](https://github.com/gitleaks/gitleaks) on `PATH`.
- Run `pre-commit install` once per clone, so gitleaks scans each commit with `.gitleaks.toml`. CI runs the same scan over the whole history.
