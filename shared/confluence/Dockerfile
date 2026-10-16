# https://hub.docker.com/r/atlassian/confluence-server/dockerfile/

ARG IMAGE_TAG=10.2

FROM atlassian/confluence:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# environments
ENV CONF_HOME=/opt/atlassian/confluence

# Variable-length plugin-file=url entries, one per line, passed from
# compose/webapp.yml. Semicolons are also accepted for older single-line values.
ARG WEBAPP_CONF_PLUGINS

# add additional plugins from local
COPY ./plugins/*.tar.gz $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/

# add base plugins
COPY install-plugins.sh /usr/local/bin/install-confluence-plugins
RUN /usr/local/bin/install-confluence-plugins

# update user group and env
RUN echo '\nexport CATALINA_OPTS="-javaagent:/opt/atlassian/confluence/bin/com.custom.confluence.mcp.connector.jar ${CATALINA_OPTS}"' >> $CONF_HOME/bin/setenv.sh
