# Qwen Code CLI - Rootless Docker Image

A rootless Docker image for [Qwen Code](https://github.com/QwenLM/qwen-code) CLI, automatically built and published to GitHub Container Registry (GHCR).

## Features

- **Rootless**: Runs as non-root user (`qwen`) for enhanced security
- **Multi-architecture**: Supports `linux/amd64` and `linux/arm64`
- **Automated builds**: GitHub Actions workflow for automatic releases
- **GHCR hosted**: Images available from GitHub Container Registry

## Quick Start

### Pull the image

```bash
docker pull ghcr.io/YOUR_USERNAME/qwen-cli-docker:latest
```

### Run interactively

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  ghcr.io/YOUR_USERNAME/qwen-cli-docker:latest
```

### Run with API key

```bash
docker run -it --rm \
  -e DASHSCOPE_API_KEY=your-api-key \
  -v $(pwd):/workspace \
  ghcr.io/YOUR_USERNAME/qwen-cli-docker:latest
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest build from main branch |
| `v*.*.*` | Semantic version releases |
| `sha-*` | Specific commit builds |

## Building Locally

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/qwen-cli-docker.git
cd qwen-cli-docker

# Clone qwen-code source
git clone --depth 1 https://github.com/QwenLM/qwen-code.git qwen-code-src

# Copy rootless Dockerfile
cp Dockerfile qwen-code-src/

# Build the image
docker build -t qwen-code:local ./qwen-code-src
```

## Rootless Design

This image runs as a non-root user (`qwen`, UID 1000) with:
- Home directory at `/home/qwen`
- npm global packages at `/home/qwen/.npm-global`
- Working directory at `/workspace`
- Sudo access available if needed

## GitHub Actions Workflow

The workflow triggers on:
- Push to `main` or `master` branch
- Git tags matching `v*`
- Pull requests (build only, no push)
- Manual dispatch with optional version input

## License

See the [Qwen Code repository](https://github.com/QwenLM/qwen-code) for license information.
