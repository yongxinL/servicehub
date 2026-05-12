# https://github.com/us/crw.git
FROM ghcr.io/us/crw:latest
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add your setup here
# Example: RUN

# install additional utilities + gettext-base for envsubst (used by entrypoint.sh)
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl nano gettext-base \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# entrypoint.sh substitutes FIRECRAWL_API_KEY into config.docker.toml before starting.
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["crw-server"]