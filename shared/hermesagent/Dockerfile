# https://github.com/nousresearch/hermes-agent
FROM nousresearch/hermes-agent:latest
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add your setup here
# Example: RUN

# 'hermes' user (uid 10000) already exists in the base image.
# tini as PID 1: correct signal forwarding + zombie reaping for
# the gateway + dashboard child processes.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini nano \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt/hermes/.venv/bin"
ENV HOME="/opt/data"

# Bake default profile files into the image at a path that will NOT be
# shadowed by the /opt/data volume mount. start-gateways.sh copies these
# into /opt/data (and per-profile dirs) only when files are absent.
# env.example is copied as .env (rename avoids gitignore, Hermes reads .env).
COPY default/ /opt/hermes-defaults/

COPY start-gateways.sh /usr/local/bin/start-gateways.sh
COPY init-profile.sh   /usr/local/bin/init-profile.sh
RUN chmod +x /usr/local/bin/start-gateways.sh /usr/local/bin/init-profile.sh

# Dashboard port only — gateway (8642) is internal/outbound, never published.
EXPOSE 12329

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/start-gateways.sh"]
