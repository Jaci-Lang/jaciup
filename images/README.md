# Jaci / Luau runner images

Docker images for running Jaci and Luau in CI containers and on
self-hosted GitHub Actions runners. The design mirrors the **rustup** model:

- The `jaciup` version manager is a **pre-existing published artifact**
  (produced by the `bootstrap` / `release` workflows before any image is
  built). The image **consumes** it; it does not build it.
- The image installs `jaciup`, then runs `jaciup toolchain install <version>`
  to pull the Jaci engine from the releases API
  (`https://pop.squareweb.app`). This is the same flow a developer runs
  locally: install the manager, install the toolchain.

This is why the bootstrap is a prerequisite: the `new-release` workflow uses
`jaciup` to build the release binaries, so `jaciup` must already exist before
the image can be built.

## Layout

| File | Platform | Method |
| --- | --- | --- |
| `Dockerfile.ubuntu` | Linux x86_64 | rustup: install `jaciup`, then `jaciup toolchain install` |
| `Dockerfile.macos` | macOS (x86_64 / arm64) | engine-only: download the `jaci` engine directly |
| `Dockerfile.windows` | Windows x86_64 | engine-only: download the `jaci` engine directly |
| `build.sh` | all | build / push the three images |

macOS and Windows use the **engine-only** bootstrap because `jaciup`
currently publishes only a Linux artifact. When a `jaciup` artifact for those
platforms exists, switch those files to the same flow as `Dockerfile.ubuntu`.

## Build

```sh
# Build all three (latest toolchain):
./images/build.sh

# Pin a toolchain version (the image tag encodes it, like rust images):
./images/build.sh --toolchain 0.310.0

# Pin the jaciup bootstrap version too:
./images/build.sh --toolchain 0.310.0 --jaciup 0.1.0

# Build and push:
./images/build.sh --push
```

Or build one platform directly:

```sh
DOCKER_BUILDKIT=1 docker build \
  --build-arg TOOLCHAIN_VERSION=0.310.0 \
  --build-arg JACIUP_VERSION=0.1.0 \
  -f images/Dockerfile.ubuntu -t jaci/jaci:0.310.0 .
```

## Verify

```sh
docker run --rm jaci/jaci:0.310.0 luau --version
docker run --rm jaci/jaci:0.310.0 jaciup show
```

## Pinning

- **Toolchain version** (`TOOLCHAIN_VERSION`): passed to
  `jaciup toolchain install`. Accepts `latest`, `stable`, or an exact
  version (e.g. `0.310.0`). This is what the image tag encodes.
- **Jaciup bootstrap version** (`JACIUP_VERSION`): which `jaciup` release
  to install. Defaults to `latest`.

The releases API returns relative `download_url` values
(e.g. `/v1/releases/0.310.0/artifacts/<id>/x.zip?product=jaci`); the
Dockerfiles join them to the registry base (`https://pop.squareweb.app`)
to make them fetchable.

## Self-hosted runners

For self-hosted GitHub Actions runners, bake the image onto the runner
and add the shim directory to `PATH` (or rely on `jaciup` shims in
`~/.jaciup/bin`). The image exposes the toolchain on `PATH` via
`ENV PATH="/root/.jaciup/bin:${PATH}"` on the ubuntu variant.
