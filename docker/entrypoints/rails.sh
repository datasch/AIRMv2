#!/bin/sh

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take precedence over individual connection params.
eval "$(docker/entrypoints/helpers/pg_database_url.rb)"
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_USERNAME=${POSTGRES_USERNAME:-postgres}

PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY > /dev/null 2>&1
do
  echo "Postgres ($POSTGRES_HOST:$POSTGRES_PORT) is unavailable - sleeping 2s..."
  sleep 2
done

echo "Database ready to accept connections."

# Only run migrations when starting web server, avoiding concurrent migration conflicts with sidekiq
case "$*" in
  *puma*|*rails\ s*|*server*|"")
    if [ "$RAILS_ENV" = "production" ]; then
      echo "Running database setup and migrations..."
      bundle exec rails db:chatwoot_prepare || bundle exec rails db:migrate || true
    fi
    ;;
esac

# Execute the main process of the container
exec "$@"
