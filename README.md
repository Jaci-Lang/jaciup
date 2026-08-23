# jaciup

**jaciup** is the toolchain manager for Jaci (the Luau fork). It installs,
updates, and switches between toolchain versions, and puts `luau`,
`luau-analyze`, `luau-compile`, and `klur` on your PATH. Same model as
`rustup`, for the Jaci ecosystem. Written in pure Luau, shipped as a single
binary.

A **toolchain** is one version of the Jaci engine (`luau`, `luau-analyze`,
`luau-compile`, `luau-ast`) plus the KLUR layer (`klur`), installed to
`~/.jaciup/toolchains/<version>/`. jaciup writes small shims into
`~/.jaciup/bin` that point at the active toolchain, so one PATH entry works
everywhere.

## Install

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Jaci-Lang/jaciup/main/scripts/install.sh | bash
```

Windows (PowerShell):

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Jaci-Lang/jaciup/main/scripts/install.ps1 -OutFile install.ps1
./install.ps1
```

The installer places `jaciup` in `~/.jaciup/bin`, installs and activates
the latest toolchain, adds the bin directory to your PATH, and configures
your shell (bash, zsh, fish, PowerShell). Open a new shell and `luau` /
`klur` are ready. Add `--no-toolchain` to install jaciup alone.

## Usage

```bash
jaciup show                       # active and installed toolchains
jaciup toolchain install 0.313.0  # install a specific version
jaciup default 0.313.0            # set the default toolchain
jaciup which luau                 # where `luau` resolves
jaciup doctor                     # diagnose toolchains, shims, PATH
jaciup run dev luau script.luau   # run under a specific toolchain
```

## Project pinning

Drop a `jaciup-toolchain.toml` in a repository and every `luau`/`klur` call
inside it uses the pinned toolchain:

```toml
[toolchain]
channel = "0.313.0"
```

## Layout

```
~/.jaciup/
├── bin/           # shims (luau, klur, ...) — this directory goes on PATH
├── toolchains/    # installed toolchains, one directory per version
└── settings.toml  # default toolchain, registry mirror
```

## License

MIT License (c) 2026 Júlia Klee.
