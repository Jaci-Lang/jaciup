# jaciup

**jaciup** is the official, pure Luau toolchain installer and version manager for the Jaci & Luau ecosystem (inspired by `rustup`).

---

## Features

- **Seamless Toolchain Management**: Install, update, list, and switch between multiple Jaci/Luau versions.
- **Universal Binary Shims**: Provides automatic PATH shims (`luau`, `luau-analyze`, `luau-compile`, `luau-ast`, `klur`).
- **Project Pinning**: Automatically detects and respects `jaciup-toolchain.toml` or `jaci-toolchain.toml` per directory.
- **Cross-Platform Shell Integration**: Auto-configures `bash`, `zsh`, `fish`, `powershell`, and Windows system PATH.
- **100% Pure Luau**: Zero external runtime dependencies. Compiles to a single standalone executable.

---

## Quick Start

```sh
# Initialize jaciup and setup PATH shims
jaciup init

# Show active and installed toolchains
jaciup show

# Set the default global toolchain
jaciup default 0.10.0

# Install a specific release
jaciup toolchain install 0.10.0

# Link a local development build
jaciup toolchain link dev /path/to/jaci/build

# Query binary path for active toolchain
jaciup which luau

# Run a command under a specific toolchain
jaciup run 0.9.0 luau script.luau
```

---

## Project Toolchain Pinning (`jaciup-toolchain.toml`)

Pin your project's compiler and runtime version by adding a `jaciup-toolchain.toml` in your repository:

```toml
[toolchain]
channel = "0.10.0"
```

Any invocation of `luau`, `luau-analyze`, or `klur` inside that directory will automatically use the pinned toolchain.

---

## License

MIT License (c) 2026 Júlia Klee.
