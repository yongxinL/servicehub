# https://github.com/stalwartlabs/stalwart
# All-in-one Mail & Collaboration server (IMAP, JMAP, SMTP, CalDAV, CardDAV, WebDAV)

ARG IMAGE_TAG=latest

FROM stalwartlabs/stalwart:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates coreutils curl inotify-tools jq ldap-utils openssl procps util-linux \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/stalwart-entrypoint.sh
COPY acme-export.sh /usr/local/bin/acme-export.sh
RUN chmod 0755 /usr/local/bin/stalwart-entrypoint.sh /usr/local/bin/acme-export.sh \
 && mkdir -p /var/lib/stalwart/tls \
 && chown -R 2000:2000 /var/lib/stalwart

# Runs as root: the entrypoint chowns the mounted data volume, renders
# /etc/stalwart/config.json, then drops to uid/gid 2000 via setpriv.
WORKDIR /var/lib/stalwart

ENTRYPOINT ["/usr/local/bin/stalwart-entrypoint.sh"]
