#!/usr/bin/env sh

set -eu

: "${DATABASE_APP_PASSWORD:?Required migration variable DATABASE_APP_PASSWORD is missing.}"
: "${DATABASE_URL:?Required migration variable DATABASE_URL is missing.}"
: "${PGDATABASE:?Required migration variable PGDATABASE is missing.}"
: "${PGHOST:?Required migration variable PGHOST is missing.}"
: "${PGPASSWORD:?Required migration variable PGPASSWORD is missing.}"
: "${PGPORT:?Required migration variable PGPORT is missing.}"
: "${PGUSER:?Required migration variable PGUSER is missing.}"

echo "Creating or updating the least-privilege SupportDesk database login."

psql \
	--set=ON_ERROR_STOP=1 \
	--set=app_password="$DATABASE_APP_PASSWORD" \
	--set=database_name="$PGDATABASE" <<'SQL'
SELECT format('CREATE ROLE supportdesk_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (
	SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'supportdesk_app'
) \gexec

SELECT format('ALTER ROLE supportdesk_app WITH LOGIN PASSWORD %L', :'app_password') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO supportdesk_app', :'database_name') \gexec
GRANT USAGE, CREATE ON SCHEMA public TO supportdesk_app;

SELECT format('ALTER TABLE %I.%I OWNER TO supportdesk_app', schemaname, tablename)
FROM pg_catalog.pg_tables
WHERE schemaname = 'public' \gexec

SELECT format('ALTER SEQUENCE %I.%I OWNER TO supportdesk_app', sequence_schema, sequence_name)
FROM information_schema.sequences
WHERE sequence_schema = 'public' \gexec
SQL

unset DATABASE_APP_PASSWORD PGPASSWORD PGUSER

echo "Applying committed Prisma migrations as supportdesk_app."
./node_modules/.bin/prisma migrate deploy
echo "Database bootstrap and migrations completed successfully."
