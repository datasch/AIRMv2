# Guía de Despliegue Automatizado con GitHub Actions y GHCR (Docker)

Esta guía explica paso a paso cómo compilar automáticamente una imagen Docker al hacer `git push` a GitHub, publicarla en el registro de contenedores de GitHub (**GHCR - GitHub Container Registry**) y desplegarla en tu servidor o Coolify.

---

## Arquitectura del Flujo

```mermaid
graph LR
    Dev[💻 Desarrollador] -->|git push origin main| GH[🐙 GitHub Repo]
    GH -->|Dispara| GA[⚙️ GitHub Actions]
    GA -->|Build Docker Image| GHCR[📦 ghcr.io / Packages]
    GA -.->|Webhook (Opcional)| Coolify[🚀 Servidor / Coolify]
    Coolify -->|docker pull| GHCR
```

---

## Paso 1: Crear el Workflow en el Proyecto

En la raíz de tu proyecto, crea la estructura de directorios y el archivo YAML:

```bash
mkdir -p .github/workflows
touch .github/workflows/build-and-push-ghcr.yml
```

Pega el siguiente contenido dentro de `.github/workflows/build-and-push-ghcr.yml`:

```yaml
name: Build & Push Docker Image to GHCR

on:
  push:
    branches:
      - main      # Rama principal (cambiar a master si aplica)
  workflow_dispatch:  # Permite ejecutar el build manualmente desde la web de GitHub

env:
  REGISTRY: ghcr.io
  # Define la ruta de la imagen: ghcr.io/usuario-u-organizacion/nombre-proyecto
  IMAGE_NAME: ${{ github.repository_owner }}/nombre-del-servicio
  COOLIFY_WEBHOOK_URL: ${{ secrets.COOLIFY_WEBHOOK_URL }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write  # Permiso obligatorio para publicar en GitHub Packages

    steps:
      - name: Clonar repositorio
        uses: actions/checkout@v4

      - name: Configurar Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Autenticación automática en GHCR usando el token nativo de GitHub
      - name: Iniciar sesión en GitHub Container Registry (GHCR)
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Genera etiquetas automáticas: latest, sha corto y branch
      - name: Extraer metadatos para Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=sha,format=short
            type=ref,event=branch

      # Construcción y subida de la imagen con caché acelerado en GitHub
      - name: Compilar y subir imagen Docker
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # Notificación a Coolify para desplegar la nueva versión (Opcional)
      - name: Disparar Webhook de Despliegue en Coolify
        if: env.COOLIFY_WEBHOOK_URL != ''
        run: |
          echo "Disparando despliegue en Coolify..."
          curl -X GET "${COOLIFY_WEBHOOK_URL}" || true
```

> **Nota:** Reemplaza `nombre-del-servicio` en la variable `IMAGE_NAME` por el nombre de tu aplicación o contenedor.

---

## Paso 2: Configurar Permisos de Escritura en GitHub

Por defecto, GitHub Actions tiene permisos de solo lectura. Para permitirle publicar imágenes:

1. Ve a tu repositorio en GitHub y haz clic en **Settings**.
2. En el menú lateral izquierdo, ve a **Actions** > **General**.
3. Baja hasta la sección **Workflow permissions**:
   * Selecciona: **Read and write permissions**.
   * Marca la casilla: **Allow GitHub Actions to create and approve pull requests** (recomendado).
4. Haz clic en **Save**.

---

## Paso 3: Configurar Visibilidad Pública del Paquete

La primera vez que el workflow compile y suba la imagen, el paquete se creará como *privado*. Para que tu servidor VPS o Coolify pueda descargarlo sin necesidad de configurar credenciales Docker complejas:

1. En GitHub, ve al perfil de tu usuario u organización y entra en la pestaña **Packages**.
2. Selecciona el paquete recién subido (ej. `nombre-del-servicio`).
3. En el menú derecho, haz clic en **Package settings**.
4. Desplázate al final de la página (zona de peligro / *Danger Zone*).
5. En **Change package visibility**, cámbialo a **Public**.

---

## Paso 4: Configurar Despliegue Automático en Coolify (Opcional)

Si utilizas Coolify para gestionar tus contenedores:

1. En Coolify, ingresa a tu aplicación o servicio.
2. Ve a la pestaña **Webhooks**.
3. Copia la URL de **Deploy Webhook**.
4. En tu repositorio de GitHub, ve a **Settings** > **Secrets and variables** > **Actions**.
5. Haz clic en **New repository secret**:
   * **Name:** `COOLIFY_WEBHOOK_URL`
   * **Secret:** *(Pega la URL del webhook de Coolify)*
6. Haz clic en **Add secret**.

---

## Paso 5: Uso en tu Servidor (`docker-compose.yml`)

Una vez que la imagen esté en GHCR, puedes consumirla en cualquier servidor con tu archivo `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/tu-usuario/nombre-del-servicio:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
```

---

## Resumen del Flujo de Trabajo Diario

A partir de este momento, el ciclo de desarrollo es 100% automático:

1. Haces tus cambios en el código localmente.
2. Confirmas y subes los cambios:
   ```bash
   git add .
   git commit -m "feat: nueva funcionalidad"
   git push origin main
   ```
3. GitHub Actions compila la imagen en la nube, la publica en GHCR y notifica a tu servidor para reiniciar el contenedor con la nueva versión.
