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
# Note: node:20-slim has 'node' user with UID 1000, we rename it to 'qwen'
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
    gosu \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Rename existing 'node' user/group to 'qwen' (node:20-slim has node:node with 1000:1000)
RUN groupmod -n $USER_NAME node \
    && usermod -l $USER_NAME -d /home/$USER_NAME -m node

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

# Create entrypoint script that matches host UID/GID
RUN cat <<'ENTRYPOINT_SCRIPT' > /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# Get the UID/GID of the /workspace directory (mounted from host)
if [ -d "/workspace" ]; then
    WORKSPACE_UID=$(stat -c '%u' /workspace)
    WORKSPACE_GID=$(stat -c '%g' /workspace)

    # Only modify if workspace is owned by a non-root user and differs from current user
    if [ "$WORKSPACE_UID" != "0" ] && [ "$WORKSPACE_UID" != "$(id -u qwen)" ]; then
        # Modify qwen user's UID/GID to match workspace owner
        groupmod -g "$WORKSPACE_GID" qwen 2>/dev/null || true
        usermod -u "$WORKSPACE_UID" -g "$WORKSPACE_GID" qwen 2>/dev/null || true

        # Fix ownership of home directory
        chown -R qwen:qwen /home/qwen 2>/dev/null || true
    fi
fi

# Execute the command as qwen user
exec gosu qwen "$@"
ENTRYPOINT_SCRIPT
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set git safe directory for the workspace (as qwen user)
RUN gosu qwen git config --global --add safe.directory /workspace

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["qwen"]
