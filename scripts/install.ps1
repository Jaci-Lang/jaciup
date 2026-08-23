# Install jaciup - the Jaci & Luau toolchain manager (Windows).
#
#   iwr -UseBasicParsing https://raw.githubusercontent.com/Jaci-Lang/jaciup/main/scripts/install.ps1 -OutFile install.ps1
#   ./install.ps1
#
# Installs jaciup to $env:USERPROFILE\.jaciup (override with JACIUP_HOME),
# adds the bin directory to the user PATH, then runs `jaciup init` to
# install the shims (luau, klur, ...) and patch the PowerShell profile.

$ErrorActionPreference = "Stop"

$Base = "https://pop.squareweb.app"
$ZipName = "jaciup-x86_64-pc-windows-msvc.zip"
$InstallDir = if ($env:JACIUP_HOME) { $env:JACIUP_HOME } else { Join-Path $env:USERPROFILE ".jaciup" }
$BinDir = Join-Path $InstallDir "bin"

# Fetch-Latest-Release <product>: return the release object (assets list).
function Fetch-Latest-Release([string]$product) {
    $api = "$Base/v1/releases/latest?product=$product"
    try {
        return (Invoke-RestMethod -Uri $api -UseBasicParsing)
    }
    catch {
        return $null
    }
}

# Resolve-Asset <product> <name>: return the download_url of the latest
# release asset, or $null. The releases API is briefly inconsistent while
# a release is being published; retry before giving up.
function Resolve-Asset([string]$product, [string]$name) {
    for ($i = 1; $i -le 3; $i++) {
        $rel = Fetch-Latest-Release $product
        if ($rel) {
            $asset = $rel.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
            if ($asset) { return $asset.download_url }
        }
        Write-Host "Attempt $i : could not resolve $name; retrying in $($i * 5)s..."
        Start-Sleep -Seconds ($i * 5)
    }
    return $null
}

$url = Resolve-Asset "jaciup" $ZipName
if (-not $url) {
    Write-Error "No prebuilt jaciup ($ZipName) in the latest release yet. Re-run this script after the next jaciup release."
}
if ($url.StartsWith("/")) { $url = "$Base$url" }

$tmp = Join-Path $env:TEMP "jaciup-install-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    Write-Host "Downloading $url ..."
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp "jaciup.zip") -UseBasicParsing

    # Verify the published sha256 sidecar asset when present (single
    # attempt: a missing sidecar must not cost 15s of retries).
    $rel = Fetch-Latest-Release "jaciup"
    $sidecar = if ($rel) { $rel.assets | Where-Object { $_.name -eq "$ZipName.sha256" } | Select-Object -First 1 } else { $null }
    if ($sidecar) {
        $sidecarUrl = $sidecar.download_url
        if ($sidecarUrl.StartsWith("/")) { $sidecarUrl = "$Base$sidecarUrl" }
        try {
            $expected = (Invoke-WebRequest -Uri $sidecarUrl -UseBasicParsing).Content.Trim().Split(" ")[0]
            $actual = (Get-FileHash (Join-Path $tmp "jaciup.zip") -Algorithm SHA256).Hash.ToLower()
            if ($expected.ToLower() -ne $actual) {
                throw "sha256 mismatch (expected $expected, got $actual)"
            }
            Write-Host "sha256 verified"
        }
        catch {
            if ("$_" -like "*mismatch*") { throw }
            Write-Warning "Could not fetch the published checksum; skipping verification"
        }
    }
    else {
        Write-Warning "No published checksum; skipping verification"
    }

    Expand-Archive (Join-Path $tmp "jaciup.zip") -DestinationPath (Join-Path $tmp "extract") -Force
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    Copy-Item (Join-Path $tmp "extract" "jaciup.exe") (Join-Path $BinDir "jaciup.exe") -Force
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# Add the bin directory to the user PATH (idempotent).
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
    Write-Host "Added $BinDir to the user PATH (takes effect in new terminals)."
}

# Shims (luau, klur, ...) and the PowerShell profile patch.
& (Join-Path $BinDir "jaciup.exe") init

Write-Host ""
Write-Host "jaciup installed: $BinDir\jaciup.exe"
Write-Host "Open a new terminal, then run:  jaciup toolchain install latest"
