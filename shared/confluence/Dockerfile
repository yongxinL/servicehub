# https://hub.docker.com/r/atlassian/confluence-server/dockerfile/

ARG IMAGE_TAG=10.2

FROM atlassian/confluence:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# environments
ENV CONF_HOME=/opt/atlassian/confluence

# Semicolon-separated plugin-file=url entries passed from compose/webapp.yml.
ARG WEBAPP_CONF_PLUGINS

# add addiontal plugins from local
COPY ./plugins/*.tar.gz $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/

# add base plugins
RUN set -eux; \
    tar -xzf $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.custom.confluence.mcp.connector.tar.gz -C $CONF_HOME/bin/; \
    rm -rf $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.custom.confluence.mcp.connector.tar.gz; \
    old_ifs="$IFS"; \
    IFS=';'; \
    set -f; \
    set -- ${WEBAPP_CONF_PLUGINS}; \
    set +f; \
    IFS="$old_ifs"; \
    [ "$#" -eq 4 ]; \
    for plugin; do \
        case "$plugin" in \
            *=*) ;; \
            *) echo "Invalid Confluence plugin entry: $plugin" >&2; exit 1 ;; \
        esac; \
        plugin_file="${plugin%%=*}"; \
        plugin_url="${plugin#*=}"; \
        case "$plugin_file" in \
            ""|*/*) echo "Invalid Confluence plugin filename: $plugin_file" >&2; exit 1 ;; \
        esac; \
        curl --fail --location --show-error --progress-bar \
            --output "$CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/$plugin_file" \
            "$plugin_url"; \
    done; \
    chown confluence:root $CONF_HOME/bin/com.custom.confluence.mcp.connector.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar; \
    chmod 550 $CONF_HOME/bin/com.custom.confluence.mcp.connector.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar;

# update user group and env
RUN echo '\nexport CATALINA_OPTS="-javaagent:/opt/atlassian/confluence/bin/com.custom.confluence.mcp.connector.jar ${CATALINA_OPTS}"' >> $CONF_HOME/bin/setenv.sh
