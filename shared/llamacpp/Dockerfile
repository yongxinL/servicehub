# https://github.com/ggerganov/llama.cpp
FROM ghcr.io/ggml-org/llama.cpp:server
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add your setup here
# Example: RUN

# Set the active working directory
WORKDIR /app

# Copy the entrypoint script into the active workdir (/app)
COPY entrypoint.sh ./entrypoint.sh

# Grant execution permissions
RUN chmod +x ./entrypoint.sh

# Set the script as the entrypoint
ENTRYPOINT ["./entrypoint.sh"]

