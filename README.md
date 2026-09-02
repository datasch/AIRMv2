<!-- cspell:disable -->
# 🚀 AIRM (AI Relationship Management)

<p align="center">
  <img src="public/brand-assets/logo.svg" width="480" alt="AIRM Logo"/>
</p>

<p align="center">
  <strong>Plataforma Soberana de AI Relationship Management (AIRM), CRM Omnicanal, Telefonía VoIP WebRTC y Asistentes Autónomos de Inteligencia Artificial</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.2.0--Enterprise-06b6d4?style=for-the-badge&logo=shield" alt="Version 2.2.0 Enterprise">
  <img src="https://img.shields.io/badge/Ruby_on_Rails-7.1-cc0000?style=for-the-badge&logo=rubyonrails" alt="Rails 7.1">
  <img src="https://img.shields.io/badge/Vue.js-3.5-4FC08D?style=for-the-badge&logo=vuedotjs" alt="Vue 3">
  <img src="https://img.shields.io/badge/PostgreSQL-16_+_pgvector-336791?style=for-the-badge&logo=postgresql" alt="PostgreSQL pgvector">
  <img src="https://img.shields.io/badge/WhatsApp-QR_+_Meta_Cloud_API-25D366?style=for-the-badge&logo=whatsapp" alt="WhatsApp Engine">
  <img src="https://img.shields.io/badge/VoIP-Asterisk_PBX_+_SIP_Trunk-E03C11?style=for-the-badge&logo=asterisk" alt="VoIP Asterisk">
  <img src="https://img.shields.io/badge/AI_Engine-Ian_Studio_Copilot-8b5cf6?style=for-the-badge&logo=openai" alt="Ian Studio">
  <img src="https://img.shields.io/badge/Automations-n8n_Workflow-FF6584?style=for-the-badge&logo=n8n" alt="n8n Engine">
  <img src="https://img.shields.io/badge/Despliegue-Coolify_/_Docker-2496ED?style=for-the-badge&logo=docker" alt="Coolify Ready">
</p>

---

## 🌟 Descripción General

**AIRM** es una suite empresarial de vanguardia diseñada para centralizar comunicaciones, automatizar ventas e impulsar la conversión comercial mediante Inteligencia Artificial y telefonía en la nube. 

AIRM integra en una sola plataforma:
1. **Agentes Inteligentes y Copilotos (Ian Studio)** con recuperación de información aumentada (RAG sobre `pgvector` y `Qdrant`).
2. **Conexión Híbrida de WhatsApp:** Pasarela multidispositivo **WhatsApp QR** y **Meta WhatsApp Cloud API**.
3. **Telefonía VoIP WebRTC & Troncales SIP:** Marcador telefónico en el navegador compatible con **Asterisk PBX**, **Vicidial**, **FreePBX** y softswitches mayoristas.
4. **Seguridad y Prevención de Fuga de Datos (DLP):** Enmascaramiento dinámico de teléfonos para proteger las bases de datos frente a asesores comerciales.
5. **Pipeline CRM Kanban & Automatizaciones:** Embudos de conversión visuales y orquestación con **n8n**, **Cal.com**, pasarelas de pago y ERPs.

---

## ⚡ Módulos y Capacidades del Sistema

### 🤖 1. Ian Studio — Motor de Inteligencia Artificial & Copiloto
* **Asistentes Comerciales Autónomos:** Califican prospectos, responden consultas técnicas y agendan citas 24/7 sin intervención humana inicial.
* **Knowledge Hub (RAG con pgvector):** Ingesta de manuales, catálogos en PDF y preguntas frecuentes para alimentar respuestas contextuales y precisas.
* **Transferencia Fluida a Asesores:** Detección de intención de compra con inyección automática del resumen de la IA en notas privadas del chat.
* **Copiloto en Tiempo Real:** Sugerencias inteligentes de respuestas y tono de mensaje para los agentes conectados.

### 📱 2. Conectividad WhatsApp Omnicanal
* **WhatsApp QR Multidispositivo:** Vinculación instantánea mediante código QR directo, sin requerir verificaciones de Meta.
* **Meta WhatsApp Cloud API:** Conexión oficial para despliegues masivos y campañas corporativas.
* **Canales Unificados:** Instagram Direct, Facebook Messenger, Telegram, Correo Electrónico y Live Chat Widget dentro de la misma bandeja.

### 📞 3. Telefonía VoIP & Troncales SIP
* **Marcador Softphone WebRTC Integrado:** Llamadas salientes y entrantes directas desde la interfaz web sin instalar aplicaciones externas.
* **Soporte de Troncal Mayorista:** Configuración nativa para troncales SIP por credenciales (Usuario/Contraseña) o por autorización de IP de Origen (*Gateway IP*).
* **Marcación con Máscara (Caller ID):** Soporte para visualización de máscara telefónica saliente.
* **Asignación de Extensiones SIP:** Mapeo de extensiones individuales y claves seguras por cada agente.

### 🔒 4. Data Loss Prevention (DLP) & Búsqueda Ciega (*Blind Search*)
* **Enmascaramiento de Teléfonos:** Los asesores comerciales con permisos restringidos visualizan números protegidos (ej: `+51 913 ••• •096`).
* **Protección de Base de Datos:** Los asesores pueden buscar prospectos y marcar llamadas sin poder exportar ni copiar la base de datos real.
* **Supervisión para Administradores:** Los administradores mantienen acceso transparente y control total de auditoría.

### 📊 5. Pipeline CRM Kanban & Gestión de Tratos
* **Embudos Comerciales Visuales:** Organización de prospectos por etapas (Nuevo Lead, Contactado, Asesoría Agendada, Ganado, Perdido).
* **Asignación de Valor Estimado:** Métricas de valor de pipeline y seguimiento de metas por ejecutivo de cuentas.

### ⚙️ 6. Super Admin Suite & Personalización Visual
* **Paleta Dark OLED (`#000000` / `#050505`):** Resplandores multicromáticos y bordes de cristal fino.
* **Toggle Dinámico Dark/Light Mode:** En el panel `/super_admin` para personalización en tiempo real.
* **Consola de Métricas en Vivo:** Visualización de cuentas, agentes, colas de procesamiento y estado de la instancia.

---

## 🏗️ Arquitectura de Servicios

```mermaid
flowchart TD
    Client["Clientes (WhatsApp / Web / IG / Teléfono)"] -->|"Mensajes & Llamadas"| Entry["Gateway de Comunicaciones"]
    
    subgraph Core["AIRM Core Platform (Ruby on Rails 7.1 + Vue 3)"]
        Web["AIRM Application Engine (:3000)"]
        Ian["Ian AI Engine & Copilot"]
        DLP["DLP & Phone Masking Service"]
        Pipeline["CRM Pipeline Kanban"]
    end

    subgraph Infrastructure["Infraestructura y Persistencia"]
        DB[("PostgreSQL 16 + pgvector")]
        Redis[("Redis 7 Cache & PubSub")]
        Sidekiq["Sidekiq Background Workers"]
        VectorDB[("Qdrant Vector Engine")]
    end

    subgraph External["Integraciones y Proveedores"]
        WA_QR["Pasarela WhatsApp QR"]
        Meta_API["Meta Cloud API (WhatsApp/IG/FB)"]
        VoIP_Trunk["Asterisk PBX / SIP Trunk"]
        n8n["n8n Automation Engine"]
        Cal["Cal.com Citas & Recordatorios"]
        Payments["Pasarelas de Pago (Stripe / Culqi)"]
    end

    Entry --> WA_QR & Meta_API & VoIP_Trunk
    WA_QR & Meta_API --> Web
    VoIP_Trunk <--> Web
    Web <--> DB & Redis & Sidekiq & VectorDB
    Web <--> Ian
    Web --> DLP
    Web <--> n8n & Cal & Payments
```

---

## 🚀 Despliegue en Producción (Docker / Coolify)

### 1. Variables de Entorno de Ejemplo (`.env.example`)

```env
# Configuración del Sistema
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
FRONTEND_URL=https://airm.tudominio.com
HELPCENTER_URL=https://airm.tudominio.com/hc/inicio/es_PE

# Seguridad y Criptografía (Generar con: openssl rand -hex 32)
SECRET_KEY_BASE=generar_clave_secreta_64_caracteres_hex
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=generar_clave_hex_32_bytes
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=generar_clave_hex_32_bytes
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=generar_clave_hex_32_bytes

# Base de Datos PostgreSQL
POSTGRES_HOST=airm_postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot_production
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=tu_password_seguro_postgres

# Caché y Colas Redis
REDIS_PASSWORD=tu_password_seguro_redis
REDIS_URL=redis://:tu_password_seguro_redis@airm_redis:6379/0

# Pasarela WhatsApp QR (Evolution API)
EVOLUTION_API_URL=http://evolution-api:8080
EVOLUTION_API_KEY=generar_api_key_segura_evolution

# Base de Datos Vectorial (Qdrant)
Qdrant_API_KEY=generar_api_key_segura_qdrant

# Telefonía VoIP & Asterisk PBX / Troncal SIP
ASTERISK_ENABLED=true
ASTERISK_WS_URL=wss://voip.tudominio.com:8089/ws
ASTERISK_SIP_DOMAIN=tudominio.com
ASTERISK_CALLER_ID=51900000000

# Correo Transaccional (SMTP)
MAILER_SENDER_EMAIL=AIRM <soporte@tudominio.com>
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=tu_correo@tudominio.com
SMTP_PASSWORD=tu_password_smtp_app
SMTP_ENABLE_STARTTLS_AUTO=true
```

### 2. Comandos de Inicialización

```bash
# 1. Crear y migrar la base de datos
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

# 2. Sembrar datos iniciales requeridos
docker compose run --rm rails bundle exec rails db:seed

# 3. Levantar todos los servicios en segundo plano
docker compose up -d
```

---

<p align="center">
  <sub>AIRM Platform — Enterprise AI Relationship Management. © 2024–2026. Todos los derechos reservados.</sub>
</p>
