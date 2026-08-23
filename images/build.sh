#!/usr/bin/env bash
# Build and (optionally) push the Jaci/Luau runner images.
#
# Usage:
#   ./images/build.sh                       # build all three, no push
#   ./images/build.sh --push                # build and push
#   ./images/build.sh --toolchain 0.310.0   # pin the toolchain version
#   ./images/build.sh --jaciup 0.1.0        # pin the jaciup bootstrap version
#
# The image tag encodes the toolchain version, exactly like rust images do
# (rust-lang/rust:1.75.0). The `jaciup` bootstrap is a pre-existing published
# artifact: this script consumes it, it does not build it.
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${TAG:-jaci/jaci:latest}"
TOOLCHAIN_VERSION="${TOOLCHAIN_VERSION:-latest}"
JACIUP_VERSION="${JACIUP_VERSION:-latest}"
PUSH=0

for arg in "$@"; do
    case "$arg" in
        --push) PUSH=1 ;;
        --toolchain=*) TOOLCHAIN_VERSION="${arg#*=}" ;;
        --jaciup=*) JACIUP_VERSION="${arg#*=}" ;;
        -h|--help)
            grep -E '^#' "$0" | sed -e 's/^# //;1,2d'
            exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Encode the pinned toolchain version into the image tag.
case "$TOOLCHAIN_VERSION" in
    latest|stable|"") TAG="jaci/jaci:latest" ;;
    *) TAG="jaci/jaci:${TOOLCHAIN_VERSION}" ;;
esac

echo "Image tag:        $TAG"
echo "Toolchain:        $TOOLCHAIN_VERSION"
echo "Jaciup bootstrap: $JACIUP_VERSION"

build() {
    local dockerfile="$1"
    DOCKER_BUILDKIT=1 docker build \
        --build-arg TOOLCHAIN_VERSION="$TOOLCHAIN_VERSION" \
        --build-arg JACIUP_VERSION="$JACIUP_VERSION" \
        -f "images/$dockerfile" -t "$TAG" .
}

build Dockerfile.ubuntu
build Dockerfile.macos
build Dockerfile.windows

if [ "$PUSH" -eq 1 ]; then
    echo "Pushing $TAG ..."
    docker push "$TAG"
fi

echo "Done: $TAG"
