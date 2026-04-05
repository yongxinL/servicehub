#!/bin/bash

set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "  Creating database '$database'"
	mariadb -u"root" -p"$MARIADB_ROOT_PASSWORD" <<-EOSQL
	   CREATE DATABASE IF NOT EXISTS \`$database\`;
	   GRANT ALL ON \`$database\`.* TO '$MARIADB_USER'@'%';
EOSQL
}

if [ -n "$MARIADB_DB_LIST" ]; then
	echo "Multiple database creation requested: $MARIADB_DB_LIST"
	for db in $(echo $MARIADB_DB_LIST | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created ..."
fi