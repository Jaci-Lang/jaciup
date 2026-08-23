--!strict
-- Universal binary shims and dynamic command proxying for Jaciup

local Env = require("../core/env")
local Platform = require("../core/platform")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Process = require("@klur/process")

local Proxy = {}

local SHIMMED_BINARIES = {
    "luau",
    "luau-analyze",
    "luau-compile",
    "luau-ast",
    "klur",
}

function Proxy.generatePosixShim(binaryName: string): string
    local script = [==[#!/usr/bin/env sh
# Jaciup auto-generated proxy shim for %s

set -e

# Resolve target executable using jaciup which
if command -v jaciup >/dev/null 2>&1; then
    TARGET="$(jaciup which %s 2>/dev/null)"
    if [ -n "$TARGET" ] && [ -x "$TARGET" ]; then
        exec "$TARGET" "$@"
    fi
fi

# Fallback to standard jaciup home layout
JACIUP_DIR="${JACIUP_HOME:-$HOME/.jaciup}"
if [ -f "$JACIUP_DIR/settings.toml" ]; then
    DEFAULT_TC="$(grep -E '^default_toolchain[[:space:]]*=' "$JACIUP_DIR/settings.toml" | head -n1 | sed -E 's/.*=[[:space:]]*"([^"]+)".*/\1/')"
    if [ -n "$DEFAULT_TC" ] && [ -x "$JACIUP_DIR/toolchains/$DEFAULT_TC/%s" ]; then
        exec "$JACIUP_DIR/toolchains/$DEFAULT_TC/%s" "$@"
    fi
fi

echo "jaciup: error: no toolchain installed providing '%s'" >&2
echo "Run 'jaciup toolchain install latest' or 'jaciup default <version>' to install one." >&2
exit 1
]==]
    return string.format(script, binaryName, binaryName, binaryName, binaryName, binaryName)
end

function Proxy.generateWindowsShim(binaryName: string): string
    local script = [==[@echo off
rem Jaciup auto-generated proxy shim for %s

for /f "tokens=*" %%%%i in ('jaciup which %s 2^>nul') do set "TARGET=%%%%i"
if defined TARGET (
    if exist "%%TARGET%%" (
        "%%TARGET%%" %%*
        exit /b %%ERRORLEVEL%%
    )
)

echo jaciup: error: no toolchain installed providing '%s' >&2
echo Run 'jaciup toolchain install latest' to install one. >&2
exit /b 1
]==]
    return string.format(script, binaryName, binaryName, binaryName)
end

function Proxy.installShims(): boolean
    Env.ensureDirectories()
    local binDir = Env.getBinDir()

    for _, bin in ipairs(SHIMMED_BINARIES) do
        if Platform.isWindows() then
            local cmdPath = Path.join(binDir, bin .. ".cmd")
            Fs.writeFile(cmdPath, Proxy.generateWindowsShim(bin))
        else
            local shimPath = Path.join(binDir, bin)
            Fs.writeFile(shimPath, Proxy.generatePosixShim(bin))
            Process.spawn("chmod", { "+x", shimPath })
        end
    end

    return true
end

return Proxy
