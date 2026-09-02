<!-- cspell:disable -->
# 🚀 AIRM by Giantucchi (AI Relationship Management)

<p align="center">
  <img src="public/brand-assets/logo.svg" width="480" alt="AIRM by Giantucchi Logo"/>
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
  <img src="https://img.shields.io/badge/VoIP-Asterisk_PBX_+_VoIPRabbit-E03C11?style=for-the-badge&logo=asterisk" alt="VoIP Asterisk">
  <img src="https://img.shields.io/badge/AI_Engine-Ian_Studio_Copilot-8b5cf6?style=for-the-badge&logo=openai" alt="Ian Studio">
  <img src="https://img.shields.io/badge/Automations-n8n_Workflow-FF6584?style=for-the-badge&logo=n8n" alt="n8n Engine">
  <img src="https://img.shields.io/badge/Despliegue-Coolify_/_Docker-2496ED?style=for-the-badge&logo=docker" alt="Coolify Ready">
</p>

---

## 🌟 Descripción General

**AIRM by Giantucchi** es una suite empresarial de vanguardia diseñada para centralizar comunicaciones, automatizar ventas e impulsar la conversión comercial mediante Inteligencia Artificial y telefonía en la nube. 

Heredando la estética oficial y la infraestructura de **Giantucchi** (`giantucchi.com`), AIRM integra en una sola plataforma:
1. **Agentes Inteligentes y Copilotos (Ian Studio)** con recuperación de información aumentada (RAG).
2. **Conexión Híbrida de WhatsApp:** Pasarela multidispositivo **WhatsApp QR** y **Meta WhatsApp Cloud API**.
3. **Telefonía VoIP WebRTC & Troncales SIP:** Marcador telefónico en el navegador compatible con **VoIPRabbit**, **Asterisk PBX** y **Vicidial**.
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
* **Meta WhatsApp Cloud API (Meta Verified Tech Provider):** Conexión certificada por Meta para despliegues masivos y campañas oficiales.
* **Canales Unificados:** Instagram Direct, Facebook Messenger, Telegram, Correo Electrónico y Live Chat Widget dentro de la misma bandeja.

### 📞 3. Telefonía VoIP & Troncales SIP (VoIPRabbit / Asterisk)
* **Marcador Softphone WebRTC Integrado:** Llamadas salientes y entrantes directas desde la interfaz web sin instalar aplicaciones externas.
* **Soporte de Troncal Mayorista (VoIPRabbit):** Configuración nativa para troncales SIP por credenciales (`JoseMaster`) o por autorización de IP de Origen (*Gateway IP*).
* **Marcación con Máscara (Caller ID):** Soporte para visualización de máscara telefónica (ej: `51913086096` / `+51 913 086 096`).
* **Asignación de Extensiones SIP:** Mapeo de extensiones individuales (1001, 1002...) y claves seguras por cada agente.

### 🔒 4. Data Loss Prevention (DLP) & Búsqueda Ciega (*Blind Search*)
* **Enmascaramiento de Teléfonos:** Los asesores comerciales con permisos restringidos visualizan números protegidos (ej: `+51 913 ••• •096` o `5191•••096@s.whatsapp.net`).
* **Protección de Base de Datos:** Los asesores pueden buscar prospectos y marcar llamadas sin poder exportar ni copiar la base de datos real.
* **Supervisión para Administradores:** Los administradores mantienen acceso transparente y control total de auditoría.

### 📊 5. Pipeline CRM Kanban & Gestión de Tratos
* **Embudos Comerciales Visuales:** Organización de prospectos por etapas (Nuevo Lead, Contactado, Asesoría Agendada, Ganado, Perdido).
* **Asignación de Valor Estimado:** Métricas de valor de pipeline y seguimiento de metas por ejecutivo de cuentas.

### ⚙️ 6. Super Admin Suite & Identidad Visual Giantucchi
* **Paleta Dark OLED (`#000000` / `#050505`):** Resplandores multicromáticos (`#06b6d4`, `#3b82f6`, `#8b5cf6`, `#ec4899`, `#f97316`) y bordes de cristal fino.
* **Toggle Dinámico Dark/Light Mode:** En el panel `/super_admin` para personalización en tiempo real.
* **Isotipo Oficial de Giantucchi AI (Ian):** Hexágono con 12 nodos radiales en contenedor squircle negro de alto contraste.

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
    end

    subgraph External["Integraciones y Proveedores"]
        WA_QR["Pasarela WhatsApp QR"]
        Meta_API["Meta Cloud API (WhatsApp/IG/FB)"]
        VoIP_Trunk["VoIPRabbit / Asterisk PBX (149.20.185.4)"]
        n8n["n8n Automation Engine"]
        Cal["Cal.com Citas & Recordatorios"]
        Payments["Culqi & Stripe (Links de Pago)"]
    end

    Entry --> WA_QR & Meta_API & VoIP_Trunk
    WA_QR & Meta_API --> Web
    VoIP_Trunk <--> Web
    Web <--> DB & Redis & Sidekiq
    Web <--> Ian
    Web --> DLP
    Web <--> n8n & Cal & Payments
```

---

## 🚀 Despliegue en Producción (Docker / Coolify)

### 1. Variables de Entorno (`.env`)

```env
# Configuración del Sistema
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
FRONTEND_URL=https://airm.giantucchi.com
HELPCENTER_URL=https://airm.giantucchi.com/hc/inicio/es_PE

# Seguridad y Criptografía
SECRET_KEY_BASE=tu_clave_secreta_64_caracteres
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=tu_clave_hex_32_bytes
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=tu_clave_hex_32_bytes
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=tu_clave_hex_32_bytes

# Base de Datos PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot_production
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=tu_password_seguro

# Caché y Colas Redis
REDIS_URL=redis://default:tu_redis_password@redis:6379/0

# Telefonía VoIP & Asterisk / VoIPRabbit
ASTERISK_ENABLED=true
ASTERISK_WS_URL=wss://voip.giantucchi.com:8089/ws
ASTERISK_SIP_DOMAIN=giantucchi.com
ASTERISK_CALLER_ID=51913086096
VOIP_GATEWAY_IP=95.216.197.185

# Correo Transaccional (SMTP)
MAILER_SENDER_EMAIL=hola@giantucchi.com
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=tu_correo@giantucchi.com
SMTP_PASSWORD=tu_app_password_16_caracteres
SMTP_ENABLE_STARTTLS_AUTO=true
```

### 2. Comandos de Inicialización

```bash
# Crear y migrar la base de datos
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

# Sembrar datos iniciales requeridos
docker compose run --rm rails bundle exec rails db:seed

# Levantar todos los servicios
docker compose up -d
```

---

## ⚖️ Aspectos Legales e Institucionales

* **Titular de la Plataforma:** Giantucchi Inc EIRL
* **RUC:** 20612896501
* **Domicilio Legal:** Av. Larco 1052, Miraflores, Lima, Perú
* **Contacto:** [hola@giantucchi.com](mailto:hola@giantucchi.com) | +51 913 086 096
* **Centro de Ayuda Oficial:** [https://airm.giantucchi.com/hc/inicio/es_PE](https://airm.giantucchi.com/hc/inicio/es_PE)
* **Términos y Privacidad:** Conforme a la Ley N° 29733 (Perú) y regulaciones internacionales de protección de datos (GDPR).

---

<p align="center">
  <sub>Desarrollado con orgullo por el equipo de ingeniería de <strong>Giantucchi</strong>. © 2024–2026. Todos los derechos reservados.</sub>
</p>
