# https://doc.owncloud.com/ocis/
ARG IMAGE_TAG=8.2.0
FROM owncloud/ocis:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

USER root

RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl

COPY entrypoint.sh /usr/local/bin/ocis-entrypoint

RUN chmod +x /usr/local/bin/ocis-entrypoint

USER ocis-user

ENTRYPOINT ["/usr/local/bin/ocis-entrypoint"]
