# mise-llvm

A [mise](https://mise.jdx.dev) backend plugin for LLVM/Clang tools with dynamic version discovery and package verification.

## Features

- **Dynamic Version Discovery:** Fetches all available LLVM releases directly from the `llvm/llvm-project` GitHub repository.
- **Package Verification:** Automatically verifies package integrity using GitHub Attestations (`gh`) or GPG signatures.
- **Smart Asset Matching:** Detects your OS and architecture to download the most compatible pre-built binary.
- **Complete Toolchain:** Sets up `PATH`, `LD_LIBRARY_PATH`, and include paths for immediate use.

## Installation

```bash
# Ensure experimental backends are enabled
mise settings set experimental true

# Install the plugin
mise plugin install clang https://github.com/tntd2k2/mise-llvm.git
```

## Usage

This is a backend plugin, which means it can manage multiple tools from the clang ecosystem.

```bash
# Install a specific version
mise install clang:llvm@19.1.0

# Use it globally or locally
mise use -g clang:llvm@latest
```

## Requirements

- **[gh](https://cli.github.com/)**: Required for GitHub Attestation verification (optional but recommended).
- **[gpg](https://gnupg.org/)**: Used as a fallback for signature verification if `gh` is not available.

## Development

### Local Testing

1. Link your plugin for development:
```bash
mise plugin link --force clang .
```

2. Test version listing:
```bash
mise ls-remote clang:llvm
```

3. Run tests:
```bash
mise run test
```

## License

MIT
