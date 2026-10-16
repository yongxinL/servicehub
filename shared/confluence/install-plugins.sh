#!/bin/sh

set -eu

plugins_dir="$CONF_HOME/confluence/WEB-INF/atlassian-bundled-plugins"
agent_archive="$plugins_dir/com.custom.confluence.mcp.connector.tar.gz"

tar --warning=no-unknown-keyword -xzf "$agent_archive" -C "$CONF_HOME/bin/"
rm -f "$agent_archive"

plugins=$(printf '%s' "${WEBAPP_CONF_PLUGINS:-}" | tr ';' ' ')
old_ifs="$IFS"
IFS="$(printf '\n ')"
set -f
set -- ${plugins}
set +f
IFS="$old_ifs"

for plugin; do
    case "$plugin" in
        *=*) ;;
        *) echo "Invalid Confluence plugin entry: $plugin" >&2; exit 1 ;;
    esac

    plugin_file="${plugin%%=*}"
    plugin_url="${plugin#*=}"
    case "$plugin_file" in
        ""|*/*) echo "Invalid Confluence plugin filename: $plugin_file" >&2; exit 1 ;;
    esac

    echo "Downloading $plugin_file"
    curl --fail --location --show-error --progress-bar \
        --output "$plugins_dir/$plugin_file" \
        "$plugin_url"
done

chown confluence:root "$CONF_HOME/bin/com.custom.confluence.mcp.connector.jar" "$plugins_dir"/*.jar
chmod 550 "$CONF_HOME/bin/com.custom.confluence.mcp.connector.jar" "$plugins_dir"/*.jar
