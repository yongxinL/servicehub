# https://github.com/docker-library/wordpress
FROM wordpress:fpm-alpine
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# 1. Install system dependencies (Nginx, supervisor, and core tools)
RUN apk add --no-cache \
    nginx shadow supervisor

# 2. Use the "Trusted PHP Extension Installer" to handle Imagick & others
# This script automatically pulls the PHP 8.3 compatible version of Imagick.
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Now run the installer for all your needed extensions
RUN install-php-extensions \
    intl \
    zip \
    gd \
    opcache \
    imagick \
    exif \
    fileinfo

# 3. Align www-data UID/GID with host to fix permission issues
ARG WWW_DATA_UID=1000
ARG WWW_DATA_GID=1000

RUN groupmod -g $WWW_DATA_GID www-data && \
    usermod -u $WWW_DATA_UID -g $WWW_DATA_GID www-data

# 4. Copy and update PHP configuration
RUN cp ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^allow_url_fopen.*/allow_url_fopen = on/' ${PHP_INI_DIR}/php.ini && \
    # ADD: Increase memory for file sync/indexing
    sed -i 's/^memory_limit.*/memory_limit = 512M/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^max_execution_time.*/max_execution_time = 300/' ${PHP_INI_DIR}/php.ini && \
    # New additions for stability (Use ;* to match zero or more semicolons)
    sed -i 's/^;*max_input_vars.*/max_input_vars = 3000/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^max_input_time.*/max_input_time = 300/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*realpath_cache_size.*/realpath_cache_size = 4096K/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^output_buffering.*/output_buffering = Off/' ${PHP_INI_DIR}/php.ini && \
    # Opcache settings (using ? to match with or without semicolon)
    sed -i 's/^;*opcache.enable=.*/opcache.enable=1/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.enable_cli=.*/opcache.enable_cli=1/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.memory_consumption=.*/opcache.memory_consumption=128/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.max_wasted_percentage=.*/opcache.max_wasted_percentage=5/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.validate_timestamps=.*/opcache.validate_timestamps=1/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.revalidate_freq=.*/opcache.revalidate_freq=60/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^;*opcache.save_comments=.*/opcache.save_comments=1/' ${PHP_INI_DIR}/php.ini && \
    # Upload settings (Matches your 768M)
    sed -i 's/^post_max_size.*/post_max_size = 768M/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 768M/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^session.use_trans_sid.*/session.use_trans_sid = 0/' ${PHP_INI_DIR}/php.ini && \
    sed -i 's/^zlib.output_compression.*/zlib.output_compression = On/' ${PHP_INI_DIR}/php.ini

# 5. Create necessary directories
RUN mkdir -p /run/nginx \
    /var/log/supervisor \
    /etc/supervisor.d

# 6. Copy Nginx & Supervisor configuration
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/http.d/00-common.inc /etc/nginx/http.d/00-common.inc
COPY etc/nginx/http.d/10-wordpress.inc /etc/nginx/http.d/10-wordpress.inc
COPY etc/supervisord.conf /etc/supervisord.conf

# Expose HTTP port (Nginx)
EXPOSE 80

# Use supervisord as the main process
ENTRYPOINT []
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]