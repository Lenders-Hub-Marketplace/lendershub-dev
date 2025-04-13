
#!/bin/bash

# Usage: ./setup_env.sh --env=local | --env=staging | --env=production
ENV="local"

# Parse environment argument
for ARG in "$@"; do
  case $ARG in
    --env=*)
      ENV="${ARG#*=}"
      shift
      ;;
    *)
      ;;
  esac
done

# Sanitize ENV
if [[ ! "$ENV" =~ ^(local|staging|production)$ ]]; then
  echo "❌ Invalid environment: $ENV. Use --env=local, --env=staging, or --env=production"
  exit 1
fi

echo "🔧 Generating .env files for environment: $ENV"

# Define services and base ports
declare -A SERVICES=(
  [lendershub-core]=8001
  [lendershub-wallet]=8002
  [lendershub-backend]=8003
  [lendershub-platform]=8004
  [lendershub-ai]=8005
  [lendershub-devhq]=8006
  [lendershub-mobile]=8007
)

# Create .env files per service
for SERVICE in "${!SERVICES[@]}"; do
  PORT=${SERVICES[$SERVICE]}
  DB_NAME="${SERVICE//-/_}_${ENV}_db"
  DB_USER="${SERVICE//-/_}_user"
  DB_PASS="${SERVICE//-/_}_pass"

  mkdir -p "$SERVICE"

  cat <<EOL > "$SERVICE/.env.$ENV"
APP_NAME=${SERVICE^}
APP_ENV=$ENV
APP_PORT=$PORT
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=$([[ $ENV == "production" ]] && echo "false" || echo "true")
APP_TIMEZONE=UTC
APP_URL=http://localhost:$PORT

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

SESSION_DRIVER=database
SESSION_LIFETIME=120

CACHE_STORE=database
QUEUE_CONNECTION=database
BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local

REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_FROM_ADDRESS="${SERVICE}@lendershubmarketplace.com"
MAIL_FROM_NAME="\${APP_NAME}"

VITE_APP_NAME="\${APP_NAME}"

# Microservices URLs
LENDERSHUB_CORE_URL=http://localhost:8001
LENDERSHUB_WALLET_URL=http://localhost:8002
LENDERSHUB_BACKEND_URL=http://localhost:8003
LENDERSHUB_PLATFORM_URL=http://localhost:8004
LENDERSHUB_AI_URL=http://localhost:8005
LENDERSHUB_DEVHQ_URL=http://localhost:8006
LENDERSHUB_GATEWAY_URL=http://localhost:8010
EOL

  echo "✅ $SERVICE/.env.$ENV created"
done

# Create global root .env
cat <<EOL > ".env.$ENV"
APP_NAME=LendersHub
APP_ENV=$ENV
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=$([[ $ENV == "production" ]] && echo "false" || echo "true")
APP_URL=http://localhost:8001

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=lendershub_core_${ENV}_db
DB_USERNAME=lendershub_core_user
DB_PASSWORD=lendershub_core_pass

SESSION_DRIVER=database
SESSION_LIFETIME=120

LENDERSHUB_CORE_URL=http://localhost:8001
LENDERSHUB_WALLET_URL=http://localhost:8002
LENDERSHUB_BACKEND_URL=http://localhost:8003
LENDERSHUB_PLATFORM_URL=http://localhost:8004
LENDERSHUB_AI_URL=http://localhost:8005
LENDERSHUB_DEVHQ_URL=http://localhost:8006
LENDERSHUB_GATEWAY_URL=http://localhost:8010
EOL

echo "🌐 Root .env.$ENV created"

# Grant database privileges
for SERVICE in "${!SERVICES[@]}"; do
  DB_NAME="${SERVICE//-/_}_${ENV}_db"
  DB_USER="${SERVICE//-/_}_user"
  PSQL_CMD="GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
  echo "🛡️  $PSQL_CMD"
  sudo -u postgres psql -c "$PSQL_CMD"
done

echo "🎉 $ENV environment setup complete!"

