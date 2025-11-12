# https://hub.docker.com/r/atlassian/confluence-server/dockerfile/
FROM atlassian/confluence:10.0
LABEL maintainer "https://github.com/yongxinL/docker-library"

# environments
ENV CONF_HOME=/opt/atlassian/confluence

# Define build-time arguments for plugin URLs
# This value is passed from the docker-compose file during the build process.
ARG SAML_SSO_PLUGIN_URL="https://marketplace.atlassian.com/artifacts/b4637d80-9c9d-43cc-8c7c-7bd6508accf1/download?buildNumber=2205006002"

# add drivers
COPY ./plugins/atlassian-agent.jar $CONF_HOME/bin

# add base plugins
RUN set -eux; \
    curl -Lso "$CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.miniorange.samlsso.for.confluence.jar" "${SAML_SSO_PLUGIN_URL}"; \
    chown confluence:root "$CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins"; \
    chmod 550 "$CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins";

# update user group and env
RUN echo '\nexport CATALINA_OPTS="-javaagent:/opt/atlassian/confluence/bin/atlassian-agent.jar ${CATALINA_OPTS}"' >> $CONF_HOME/bin/setenv.sh
