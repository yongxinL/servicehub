# https://code.forgejo.org/forgejo/runner
# Forgejo Actions runner (successor of gitea/act_runner). Host mode: workflow
# jobs run directly in this container (no job container, no Docker socket) and
# deploy to remote Docker hosts over SSH.

ARG IMAGE_TAG=13

FROM code.forgejo.org/forgejo/runner:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"
LABEL org.opencontainers.image.description="Host-mode Forgejo Runner for SSH-based deployments"

USER root

RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    git \
    jq \
    nodejs \
    npm \
    openssh-client \
    sshpass

COPY entrypoint.sh /usr/local/bin/runner-entrypoint

RUN chmod +x /usr/local/bin/runner-entrypoint

ENTRYPOINT ["/usr/local/bin/runner-entrypoint"]