# https://github.com/us/crw.git
FROM lightpanda/browser:latest
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add your setup here
# Example: RUN

# Change the exposed port for documentation
EXPOSE 12362/tcp

# Override the default command to use the new port
CMD ["/bin/lightpanda", "serve", "--host", "0.0.0.0", "--port", "12362", "--log-level", "info"]