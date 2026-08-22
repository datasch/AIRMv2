#!/bin/sh

set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take precedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
eval "$(docker/entrypoints/helpers/pg_database_url.rb)"
POSTGRES_PORT=${POSTGRES_PORT:-5432}
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  echo "Postgres is unavailable - sleeping 2s..."
  sleep 2
done

echo "Database ready to accept connections."

# Check bundle first; only run bundle install if gems are missing (e.g. in local dev volume mounts)
bundle check || bundle install

# Auto-prepare / migrate database on startup if production
if [ "$RAILS_ENV" = "production" ]; then
  echo "Checking database and running migrations..."
  bundle exec rails db:chatwoot_prepare || bundle exec rails db:migrate || true
fi

# Execute the main process of the container
exec "$@"
