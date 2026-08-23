#!/usr/bin/env bash
# Install jaciup - the Jaci & Luau toolchain manager.
#
#   curl -fsSL https://raw.githubusercontent.com/Jaci-Lang/jaciup/main/scripts/install.sh | bash
#
# Installs jaciup to ~/.jaciup (override with JACIUP_HOME), then runs
# `jaciup init` to install the shims (luau, klur, ...) and patch the
# shell PATH for bash, zsh, and fish.
#
# Options:
#   --with-toolchain   Also install the latest engine + KLUR toolchain.

set -euo pipefail

BASE_URL="https://pop.squareweb.app"
INSTALL_DIR="${JACIUP_HOME:-$HOME/.jaciup}"
WITH_TOOLCHAIN=0

for arg in "$@"; do
    case "$arg" in
        --with-toolchain) WITH_TOOLCHAIN=1 ;;
        -h|--help)
            echo "Usage: install.sh [--with-toolchain]"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS-$ARCH" in
    Linux-x86_64)
        JACIUP_ZIP="jaciup-x86_64-unknown-linux-gnu.zip"
        ENGINE_ZIP="luau-x86_64-unknown-linux-gnu.zip"
        ;;
    Darwin-x86_64)
        # The macOS asset is x86_64; Apple Silicon runs it through Rosetta.
        JACIUP_ZIP="jaciup-x86_64-apple-darwin.zip"
        ENGINE_ZIP="luau-x86_64-apple-darwin.zip"
        ;;
    Darwin-arm64|Darwin-arm)
        JACIUP_ZIP="jaciup-x86_64-apple-darwin.zip"
        ENGINE_ZIP="luau-x86_64-apple-darwin.zip"
        ;;
    *)
        JACIUP_ZIP=""
        ENGINE_ZIP=""
        ;;
esac

# find_asset <product> <name> -> prints the download_url (single attempt).
find_asset() {
    local product="$1" name="$2" resp
    resp="$(curl -fsSL "$BASE_URL/v1/releases/latest?product=$product" || true)"
    printf '%s' "$resp" \
        | jq -r "(.assets // [])[] | select(.name==\"$name\") | .download_url" 2>/dev/null \
        | head -n 1
}

# resolve_asset <product> <name> -> prints the download_url (or fails).
# The releases API is briefly inconsistent while a release is published;
# retry before giving up.
resolve_asset() {
    local product="$1" name="$2" attempt url
    url=""
    for attempt in 1 2 3; do
        url="$(find_asset "$product" "$name")"
        if [[ -n "$url" && "$url" != "null" ]]; then
            printf '%s' "$url"
            return 0
        fi
        echo "Attempt $attempt: could not resolve $name; retrying in $((attempt * 5))s..." >&2
        sleep $((attempt * 5))
    done
    return 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# download_verify <product> <zip_name> <url> <dest>: fetch and verify the
# published sha256 (the "<zip_name>.sha256" sidecar asset, when present).
download_verify() {
    local product="$1" name="$2" url="$3" dest="$4"
    local expected="" actual="" sidecar=""
    [[ "$url" == /* ]] && url="$BASE_URL$url"
    curl -fSL --retry 3 -o "$dest" "$url"
    sidecar="$(find_asset "$product" "$name.sha256")"
    if [[ -n "$sidecar" && "$sidecar" != "null" ]]; then
        [[ "$sidecar" == /* ]] && sidecar="$BASE_URL$sidecar"
        expected="$(curl -fsSL "$sidecar" 2>/dev/null | awk '{print $1; exit}' || true)"
    fi
    if [[ -n "$expected" ]]; then
        actual="$( (shasum -a 256 "$dest" 2>/dev/null || sha256sum "$dest") | awk '{print $1}' )"
        if [[ "$expected" != "$actual" ]]; then
            echo "error: sha256 mismatch for $dest" >&2
            echo "  expected: $expected" >&2
            echo "  actual:   $actual" >&2
            exit 1
        fi
        echo "sha256 verified"
    else
        echo "warning: no published checksum for $name; skipping verification"
    fi
}

build_from_source() {
    command -v git >/dev/null 2>&1 \
        || { echo "error: git is required for the source build" >&2; exit 1; }
    [[ -n "$ENGINE_ZIP" ]] \
        || { echo "error: no engine available for platform $OS-$ARCH" >&2; exit 1; }

    echo "Cloning jaciup and klur..."
    git clone -q --depth 1 https://github.com/Jaci-Lang/jaciup.git "$TMP/jaciup"
    # klur must be a sibling of jaciup: .luaurc aliases @klur to ../klur/src/std.
    git clone -q --depth 1 https://github.com/Jaci-Lang/klur.git "$TMP/klur"

    local eurl
    eurl="$(resolve_asset jaci "$ENGINE_ZIP")" \
        || { echo "error: no engine $ENGINE_ZIP in the latest Jaci release" >&2; exit 1; }
    download_verify jaci "$ENGINE_ZIP" "$eurl" "$TMP/engine.zip"
    rm -rf "$TMP/engine"
    mkdir -p "$TMP/engine"
    unzip -o -q "$TMP/engine.zip" -d "$TMP/engine"
    chmod +x "$TMP/engine/luau"

    echo "Building jaciup with the Jaci engine..."
    (
        cd "$TMP/jaciup"
        mkdir -p dist
        "$TMP/engine/luau" --build src/init.luau --direct -o dist/jaciup
    )
    install -m 0755 "$TMP/jaciup/dist/jaciup" "$INSTALL_DIR/bin/jaciup"
}

JACIUP_BIN="$INSTALL_DIR/bin/jaciup"
mkdir -p "$INSTALL_DIR/bin"

echo "Installing jaciup to $INSTALL_DIR"
if [[ -n "$JACIUP_ZIP" ]] && URL="$(resolve_asset jaciup "$JACIUP_ZIP")"; then
    echo "Downloading $JACIUP_ZIP..."
    download_verify jaciup "$JACIUP_ZIP" "$URL" "$TMP/jaciup.zip"
    unzip -o -q "$TMP/jaciup.zip" -d "$TMP/extract"
    install -m 0755 "$TMP/extract/jaciup" "$JACIUP_BIN"
    # A prebuilt release can be stale or broken; probe it before trusting it.
    if ! "$JACIUP_BIN" --version 2>&1 | grep -qvi "error"; then
        echo "The prebuilt binary failed its version probe; building from source..."
        build_from_source
    fi
elif [[ -n "$JACIUP_ZIP" ]]; then
    echo "No prebuilt jaciup for this platform in the latest release; building from source..."
    build_from_source
else
    build_from_source
fi

# Shims (luau, klur, ...) and shell PATH patches (bash, zsh, fish).
"$JACIUP_BIN" init

if [[ "$WITH_TOOLCHAIN" -eq 1 ]]; then
    "$JACIUP_BIN" toolchain install latest
fi

echo ""
echo "jaciup installed: $JACIUP_BIN"
echo "Shell PATH updated for bash, zsh, and fish (open a new shell, or run:)"
echo "  export PATH=\"$INSTALL_DIR/bin:\$PATH\""
echo ""
if [[ "$WITH_TOOLCHAIN" -eq 1 ]]; then
    echo "Toolchain installed. Try:  luau --version && klur version"
else
    echo "Next step - install a toolchain:"
    echo "  jaciup toolchain install latest"
fi
