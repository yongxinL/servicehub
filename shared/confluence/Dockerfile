# https://hub.docker.com/r/atlassian/confluence-server/dockerfile/

ARG CONF_TAG=16

FROM atlassian/confluence:${CONF_TAG}
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# environments
ENV CONF_HOME=/opt/atlassian/confluence

# Define build-time arguments for plugin URLs
# This value is passed from the docker-compose file during the build process.
ARG SAML_SSO_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.resolution.atlasplugins.samlsso.Confluence/202608271001/DATACENTER/artifact"
ARG TABLE_FILTER_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.stiltsoft.confluence.plugin.tablefilter.tablefilter/53107650/DATACENTER/artifact"
ARG QUESTION_PLUGIN_URL="https://marketplace.atlassian.com/download/app/com.atlassian.confluence.plugins.confluence-questions/1088000102/DATACENTER/artifact"

# add drivers
COPY ./atlassian-agent-131.tar.gz $CONF_HOME/bin

# add addiontal plugins
COPY ./plugins/*.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/

# add base plugins
RUN set -eux; \
    tar -xzf $CONF_HOME/bin/atlassian-agent-131.tar.gz -C $CONF_HOME/bin/; \
    rm -rf $CONF_HOME/bin/atlassian-agent-131.tar.gz; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.resolution.atlasplugins.samlsso.Confluence.jar ${SAML_SSO_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.stiltsoft.confluence.plugin.tablefilter.tablefilter.jar ${TABLE_FILTER_PLUGIN_URL}; \
    curl -Lso $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/com.atlassian.confluence.plugins.confluence-questions.jar ${QUESTION_PLUGIN_URL}; \
    chown confluence:root $CONF_HOME/bin/atlassian-agent.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar; \
    chmod 550 $CONF_HOME/bin/atlassian-agent.jar $CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins/*.jar;

# update user group and env
RUN echo '\nexport CATALINA_OPTS="-javaagent:/opt/atlassian/confluence/bin/atlassian-agent.jar ${CATALINA_OPTS}"' >> $CONF_HOME/bin/setenv.sh