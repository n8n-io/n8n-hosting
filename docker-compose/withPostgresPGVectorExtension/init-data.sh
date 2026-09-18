#!/bin/bash
set -e;


if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
		GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
	EOSQL
	
	# Create vector extension and embeddings table
	echo "Creating vector extension and embeddings table..."
	if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE EXTENSION IF NOT EXISTS vector;

		CREATE TABLE IF NOT EXISTS embeddings (
		  id SERIAL PRIMARY KEY,
		  embedding vector,
		  text text,
		  created_at timestamptz DEFAULT now()
		);
	EOSQL
	then
		echo "ERROR: Failed to create vector extension or embeddings table"
		exit 1
	fi
	echo "Vector extension and embeddings table created successfully"
else
	echo "SETUP INFO: No Environment variables given!"
fi
