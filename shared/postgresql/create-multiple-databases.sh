#!/bin/bash

set -e
set -u

function create_database() {
	local database="$1"
	echo "  Ensuring database '$database' exists..."

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
		-- Create database if it doesn't exist
		SELECT 'CREATE DATABASE "$database"'
		WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec

		-- Grant privileges to superuser (optional but explicit)
		GRANT ALL PRIVILEGES ON DATABASE "$database" TO "$POSTGRES_USER";
	EOSQL
}

if [ -n "${POSTGRES_DB_LIST:-}" ]; then
	echo "Multiple database creation requested: $POSTGRES_DB_LIST"
	for db in $(echo "$POSTGRES_DB_LIST" | tr ',' ' '); do
		create_database "$db"
	done
	echo "Multiple databases created"
fi