# Rust Setup for Qt Creator on Ubuntu 24 Workspace

## Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

## Install Rust Analyzer

```bash
rustup component add rust-analyzer
```

## Verify Installation

```bash
rust-analyzer --version
```

or

```bash
which rust-analyzer
```

## Configure Qt Creator

If Qt Creator cannot start the bundled Rust Language Server:

1. Open **Edit → Preferences → Language Client**.
2. Locate the Rust Language Server configuration.
3. Replace the bundled executable path with the path returned by:

```bash
which rust-analyzer
```

Example:

```text
/home/developer/.cargo/bin/rust-analyzer
```
