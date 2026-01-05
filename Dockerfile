# Rootless Dockerfile for Qwen Code CLI
# Based on https://github.com/QwenLM/qwen-code

# Build stage
FROM docker.io/library/node:20-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up npm global package folder
RUN mkdir -p /usr/local/share/npm-global
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Copy source code
COPY . /home/node/app
WORKDIR /home/node/app

# Install dependencies and build packages
RUN npm ci \
    && npm run build --workspaces \
    && npm pack -w @qwen-code/qwen-code --pack-destination ./packages/cli/dist \
    && npm pack -w @qwen-code/qwen-code-core --pack-destination ./packages/core/dist

# Runtime stage
FROM docker.io/library/node:20-slim

ARG SANDBOX_NAME="qwen-code-sandbox"
ARG CLI_VERSION_ARG
ENV SANDBOX="$SANDBOX_NAME"
ENV CLI_VERSION=$CLI_VERSION_ARG

# Create non-root user for rootless operation
ARG USER_NAME=qwen
ARG USER_UID=1000
ARG USER_GID=1000

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    man-db \
    curl \
    dnsutils \
    less \
    jq \
    bc \
    gh \
    git \
    unzip \
    rsync \
    ripgrep \
    procps \
    psmisc \
    lsof \
    socat \
    ca-certificates \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create user group and user (if they don't already exist)
RUN groupadd --gid $USER_GID $USER_NAME 2>/dev/null || true \
    && useradd --uid $USER_UID --gid $USER_GID -m $USER_NAME 2>/dev/null || true \
    && echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME

# Set up npm global package folder with proper permissions for non-root user
RUN mkdir -p /home/$USER_NAME/.npm-global \
    && chown -R $USER_UID:$USER_GID /home/$USER_NAME/.npm-global

# Set npm configuration for non-root user
ENV NPM_CONFIG_PREFIX=/home/$USER_NAME/.npm-global
ENV PATH=/home/$USER_NAME/.npm-global/bin:$PATH

# Copy built packages from builder stage
COPY --from=builder /home/node/app/packages/cli/dist/*.tgz /tmp/
COPY --from=builder /home/node/app/packages/core/dist/*.tgz /tmp/

# Install packages globally as root first, then fix permissions
RUN npm install -g /tmp/*.tgz \
    && npm cache clean --force \
    && rm -rf /tmp/*.tgz

# Create workspace directory with proper permissions
RUN mkdir -p /workspace \
    && chown -R $USER_UID:$USER_GID /workspace

# Switch to non-root user
USER $USER_NAME
WORKDIR /workspace

# Set git safe directory for the workspace
RUN git config --global --add safe.directory /workspace

# Default entrypoint
CMD ["qwen"]
