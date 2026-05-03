# https://github.com/BerriAI/litellm
FROM ghcr.io/berriai/litellm-database:main-latest
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add your setup here
# Example: RUN

RUN apk add --no-cache curl nano

# Bake default config and routing callback into image
COPY config.default.yaml /app/config.default.yaml
COPY hermes_router.py /app/hermes_router.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 12321

ENTRYPOINT ["/entrypoint.sh"]
