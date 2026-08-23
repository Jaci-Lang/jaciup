# AGENTS.md for Jaciup (@jaciup/)

## Identity & Philosophy
`jaciup` is the official, pure Luau toolchain installer and version manager for Jaci and Luau.
Modeled after `rustup`, `jaciup` provides deterministic toolchain management, automated cross-platform environment setup, seamless binary shims, and project toolchain freezing (`jaciup-toolchain.toml`).

## Technical Invariants
1. **100% Pure Luau**: All toolchain resolution, CLI parsing, platform detection, shell profile patching, and shim management are implemented in standard Luau.
2. **Directory Layout**:
   - `~/.jaciup/`: Root state directory.
   - `~/.jaciup/settings.toml`: Global configuration (default toolchain, mirror URLs, telemetry off).
   - `~/.jaciup/bin/`: Universal shims (`jaciup`, `luau`, `luau-analyze`, `luau-compile`, `luau-ast`, `klur`).
   - `~/.jaciup/toolchains/<channel>/`: Installed toolchain binaries (`luau`, `luau-analyze`, `luau-compile`, `luau-ast`, etc.).
   - `~/.jaciup/downloads/`: Download cache with SHA-256 verification.
3. **Cross-Platform Compatibility**: Supports Linux (x64, arm64), macOS (x64, Apple Silicon arm64), and Windows (x64).
4. **Shell Support**: Auto-configures `bash`, `zsh`, `fish`, `powershell`, and Windows system environment.
5. **Project Pinning**: Respects `jaciup-toolchain.toml` or `jaci-toolchain.toml` in current directory and parent directories.
6. **Code Style**: Pure imperative English, strict type checking (`--!strict`), modular architecture, test-driven with unit tests.
