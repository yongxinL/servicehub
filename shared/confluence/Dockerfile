# https://hub.docker.com/r/atlassian/confluence-server/dockerfile/

ARG IMAGE_TAG=10.2

FROM atlassian/confluence:${IMAGE_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# environments
ENV CONF_HOME=/opt/atlassian/confluence

# Define build-time arguments for plugin URLs
# This value is passed from the docker-compose file during the build process.
ARG SAML_SSO_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.resolution.atlasplugins.samlsso.Confluence/202608271001/DATACENTER/artifact"
ARG DRAWIO_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.mxgraph.confluence.plugins.diagramly/1600100300/DATACENTER/artifact"
ARG TABLE_FILTER_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.stiltsoft.confluence.plugin.tablefilter.tablefilter/53107650/DATACENTER/artifact"
ARG QUESTION_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.atlassian.confluence.plugins.confluence-questions/1088000102/DATACENTER/artifact"
ARG FORMAT_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.appanvil.aura.aura/400110540/DATACENTER/artifact"

# add addiontal plugins from local
COPY ./plugins/*.tar.gz $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/

# add base plugins
RUN set -eux; \
    tar -xzf $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.custom.confluence.mcp.connector.tar.gz -C $CONF_HOME/bin/; \
    rm -rf $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.custom.confluence.mcp.connector.tar.gz; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.resolution.atlasplugins.samlsso.Confluence.jar ${SAML_SSO_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.mxgraph.confluence.plugins.diagramly.jar ${DRAWIO_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.stiltsoft.confluence.plugin.tablefilter.tablefilter.jar ${TABLE_FILTER_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.atlassian.confluence.plugins.confluence-questions.jar ${QUESTION_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.appanvil.aura.aura.jar ${FORMAT_PLUGIN_URL}; \
    chown confluence:root $CONF_HOME/bin/com.custom.confluence.mcp.connector.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar; \
    chmod 550 $CONF_HOME/bin/com.custom.confluence.mcp.connector.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar;

# update user group and env
RUN echo '\nexport CATALINA_OPTS="-javaagent:/opt/atlassian/confluence/bin/com.custom.confluence.mcp.connector.jar ${CATALINA_OPTS}"' >> $CONF_HOME/bin/setenv.sh