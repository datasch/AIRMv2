# 🚀 Guía de CI/CD: GitHub Actions + GitHub Container Registry (GHCR) + Coolify

Esta arquitectura permite que **GitHub compile y empaquete la imagen de AIRM en sus servidores de alta velocidad (con caché)** y la publique en `ghcr.io/datasch/airm:latest`. 

Tu VPS con **Coolify solo descargará la imagen lista en ~5-10 segundos** y levantará los servicios sin consumir CPU ni RAM compilando assets ni gemas en tu servidor.

---

## 🔄 Flujo de Trabajo Automatizado

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Desarrollador (Tú)
    participant GH as GitHub Repo (main)
    participant GHA as GitHub Actions (CI Runner)
    participant GHCR as GitHub Container Registry (ghcr.io)
    participant Coolify as Servidor VPS Coolify

    Dev->>GH: git push origin main
    GH->>GHA: Dispara Workflow (build-and-push-ghcr.yml)
    Note over GHA: Compila Dockerfile con Caché (Vite, Ruby, Assets)
    GHA->>GHCR: Sube ghcr.io/datasch/airm:latest
    opt Con Webhook activado
        GHA->>Coolify: Llamada al Webhook de despliegue
        Coolify->>GHCR: docker compose pull
        Coolify->>Coolify: docker compose up -d (Inicio en 10s)
    end
```

---

## 🛠️ Paso 1: Configurar Visibilidad del Paquete en GitHub (Una sola vez)

Cuando GitHub Actions suba la primera imagen a GHCR por primera vez:

1. Ve a tu perfil de GitHub: **https://github.com/datasch?tab=packages**
2. Haz clic en el paquete **`airm`**.
3. Ve a **Package settings** (en la columna lateral derecha).
4. Baja hasta la sección **Danger Zone** y en **Change visibility** selecciona **Public**.
5. *¡Listo!* Al ser público, Coolify puede descargar la imagen directamente sin requerir tokens de autenticación adicionales.

> **Nota (Si prefieres mantener el paquete Privado):**
> En Coolify ve a **Sources / Registries** > **+ Add Registry** > Selecciona **GitHub Container Registry (`ghcr.io`)**, ingresa tu usuario `datasch` y un GitHub Personal Access Token (PAT) con permiso `read:packages`.

---

## 🤖 Paso 2: Despliegue Automático con Webhook de Coolify (Opcional)

Para que Coolify se actualice **100% en automático** cada vez que termine la compilación en GitHub:

1. En tu panel de **Coolify**, entra a la aplicación **AIRM**.
2. Ve a la pestaña **`Webhooks`** en el menú superior.
3. Copia la URL que aparece en **Deploy Webhook** (ejemplo: `https://s3.giantucchi.com/api/v1/deploy?uuid=...`).
4. Ve a tu repositorio en GitHub: **https://github.com/datasch/AIRMv2/settings/secrets/actions**
5. Haz clic en **New repository secret**:
   * **Name**: `COOLIFY_WEBHOOK_URL`
   * **Secret**: Pega la URL del Webhook copiada de Coolify.
6. Haz clic en **Add secret**.

---

## 📦 Paso 3: Configurar Coolify con el Docker Compose Optimizado

En tu panel de Coolify (en el recurso de AIRM):

1. En la sección **Docker Compose content**, asegúrate de que use la imagen de GHCR (ya configurada en `docker-compose.prod.yaml`):

```yaml
version: '3.8'

services:
  rails:
    image: ghcr.io/datasch/airm:latest
    restart: always
    entrypoint: ["sh", "docker/entrypoints/rails.sh"]
    command: ["bundle", "exec", "puma", "-C", "config/puma.rb"]
    environment:
      - RAILS_ENV=production
      - NODE_ENV=production
      - INSTALLATION_ENV=docker
      - BUNDLE_FORCE_RUBY_PLATFORM=1
      - EXECJS_RUNTIME=Disabled
      - RAILS_SERVE_STATIC_FILES=true
      - SECRET_KEY_BASE=${SECRET_KEY_BASE:-f89b0c8ca72e50112353e8fc153b43a24fc1656cf2492266a5de8ae5374e29d93709bd07ab5fee72bb364f41f00af21967656a66d88341bf9abd9138c40e332d}
      - FRONTEND_URL=${FRONTEND_URL:-https://airm.giantucchi.com}
      - HELPCENTER_URL=${HELPCENTER_URL:-}
      - POSTGRES_DATABASE=${POSTGRES_DATABASE:-chatwoot_production}
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=${POSTGRES_USERNAME:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
      - REDIS_URL=redis://default:${REDIS_PASSWORD:-redispassword}@redis:6379/0
      - GOWA_URL=http://gowa:3000
      - GOWA_PUBLIC_URL=${GOWA_PUBLIC_URL:-http://localhost:3030}
      - ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY:-d0fbefd4b17eac815e2ac70cf26b4dea}
      - ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY:-bd6f095c423938798a37f03f010d48f9}
      - ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT:-9d9aeb46b718bb12080d942bba86db81}
      - MAILER_SENDER_EMAIL=${MAILER_SENDER_EMAIL:-AIRM <soporte@giantucchi.com>}
      - SMTP_ADDRESS=${SMTP_ADDRESS:-}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USERNAME=${SMTP_USERNAME:-}
      - SMTP_PASSWORD=${SMTP_PASSWORD:-}
      - SMTP_AUTHENTICATION=${SMTP_AUTHENTICATION:-plain}
      - SMTP_ENABLE_STARTTLS_AUTO=${SMTP_ENABLE_STARTTLS_AUTO:-true}
    volumes:
      - storage_data:/app/storage
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    expose:
      - "3000"
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:3000/health || exit 1"]
      interval: 20s
      timeout: 10s
      retries: 5
      start_period: 60s

  sidekiq:
    image: ghcr.io/datasch/airm:latest
    restart: always
    entrypoint: ["sh", "docker/entrypoints/rails.sh"]
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    environment:
      - RAILS_ENV=production
      - NODE_ENV=production
      - INSTALLATION_ENV=docker
      - BUNDLE_FORCE_RUBY_PLATFORM=1
      - EXECJS_RUNTIME=Disabled
      - SECRET_KEY_BASE=${SECRET_KEY_BASE:-f89b0c8ca72e50112353e8fc153b43a24fc1656cf2492266a5de8ae5374e29d93709bd07ab5fee72bb364f41f00af21967656a66d88341bf9abd9138c40e332d}
      - FRONTEND_URL=${FRONTEND_URL:-https://airm.giantucchi.com}
      - POSTGRES_DATABASE=${POSTGRES_DATABASE:-chatwoot_production}
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USERNAME=${POSTGRES_USERNAME:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
      - REDIS_URL=redis://default:${REDIS_PASSWORD:-redispassword}@redis:6379/0
      - GOWA_URL=http://gowa:3000
      - ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY:-d0fbefd4b17eac815e2ac70cf26b4dea}
      - ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY:-bd6f095c423938798a37f03f010d48f9}
      - ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT:-9d9aeb46b718bb12080d942bba86db81}
    volumes:
      - storage_data:/app/storage
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  evolution-api:
    image: evoapicloud/evolution-api:v2.2.3
    restart: always
    ports:
      - "8080:8080"
    environment:
      - SERVER_URL=http://evolution-api:8080
      - AUTHENTICATION_TYPE=apikey
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY:-evolution_secret_key_2026}
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://${POSTGRES_USERNAME:-postgres}:${POSTGRES_PASSWORD:-postgres}@postgres:5432/${POSTGRES_DATABASE:-chatwoot_production}?sslmode=disable
      - DATABASE_CONNECTION_CLIENT_NAME=evolution_chatwoot
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://:${REDIS_PASSWORD:-redispassword}@redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=true
      - CHATWOOT_ENABLED=true
      - CHATWOOT_MESSAGE_READ=true
      - CHATWOOT_MESSAGE_DELETE=true
      - WA_BUSINESS_TOKEN_WEBHOOK=true
      - LOG_LEVEL=ERROR,WARN,DEBUG,INFO,LOG,VERBOSE,DARK,WEBHOOKS
      - CORS_ORIGIN=*
    volumes:
      - evolution_instances_data:/evolution/instances
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    environment:
      - POSTGRES_DB=${POSTGRES_DATABASE:-chatwoot_production}
      - POSTGRES_USER=${POSTGRES_USERNAME:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -U ${POSTGRES_USERNAME:-postgres} -d ${POSTGRES_DATABASE:-chatwoot_production}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:alpine
    restart: always
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:-redispassword}"]
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redispassword}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
  storage_data:
  evolution_instances_data:
```

2. En la interfaz de Coolify:
   - En el servicio **`rails`**, en el campo **Domains (FQDN)** asegúrate de colocar: `https://airm.giantucchi.com`.
   - Haz clic en **Save** y luego en **Deploy**.

---

## 🚀 Cómo Desplegar de Ahora en Adelante

1. Haces tus cambios en tu máquina local.
2. Haces commit y push a `main`:
   ```bash
   git add .
   git commit -m "feat: nueva mejora"
   git push origin main
   ```
3. **GitHub Actions** compilará la imagen en la nube automáticamente en la pestaña **Actions** de tu GitHub (`https://github.com/datasch/AIRMv2/actions`).
4. Si configuraste el Webhook del Paso 2, **Coolify se desplegará solo**. Si no, simplemente presionas el botón **Deploy** en Coolify y en **10 segundos** tu aplicación estará en línea y actualizada.
