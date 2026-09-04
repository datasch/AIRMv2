# 04. API Endpoints, Rutas y Controladores

Este documento describe la API RESTful implementada en Ruby on Rails para la gestión de VoIP, el registro de llamadas y la entrega de datos para los paneles de reportería.

---

## 1. Definición de Rutas (`config/routes.rb`)

Todas las rutas están encapsuladas bajo el namespace de la cuenta autenticada (`/api/v1/accounts/:account_id/voip`):

```ruby
resource :voip, only: [], controller: 'voip' do
  get  :config, action: :show_config
  post :config, action: :update_config
  get  :agents
  post :agents, action: :update_agent
  post :call_status
  post :log_call
  post :call_contact
  get  :click_to_call_reports
  get  :database_reports
  get  'recordings/:id', action: :recording, as: :recording
end
```

---

## 2. Especificación de Endpoints

### A. Registro de Llamada y Tipificación (`POST /log_call`)
Registra una llamada finalizada o cancelada, calcula su categoría de efectividad y opcionalmente actualiza la conversación:

- **Payload:**
  ```json
  {
    "conversation_id": 1234,
    "phone_number": "+51913086096",
    "duration_seconds": 15,
    "status": "completed",
    "call_id": "call_1788460000_abc123",
    "disposition": "Venta",
    "update_conversation_tipificacion": true
  }
  ```
- **Lógica de Categorización:**
  - `duration_seconds >= 6` $\rightarrow$ `'effective'` (Efectiva).
  - `duration_seconds.between?(2, 5)` $\rightarrow$ `'test'` (Prueba).
  - De lo contrario $\rightarrow$ `'ineffective'` (No efectiva).
- **Respuesta (200 OK):**
  ```json
  {
    "success": true,
    "call_id": "call_1788460000_abc123",
    "call_category": "effective"
  }
  ```

---

### B. Reporte de Click-to-call (`GET /click_to_call_reports`)
Calcula los indicadores de workforce, gráficos de volumen por día, por hora y desglose de tipificaciones.

- **Query Parameters:**
  - `since`: Fecha inicial en formato ISO-8601 (ej. `2026-08-01T00:00:00Z`).
  - `until`: Fecha final en formato ISO-8601.
  - `all_agents`: `true` para incluir todos los agentes incluso con 0 llamadas.
- **Estructura de Respuesta:**
  ```json
  {
    "metrics": {
      "total_calls": 128,
      "effective_calls": 84,
      "test_calls": 12,
      "ineffective_calls": 32,
      "effective_percentage": 65.6,
      "tmo_seconds": 145,
      "tmo_formatted": "02:25"
    },
    "calls_by_day": [
      { "date": "2026-09-01", "total": 24, "effective": 18, "effective_pct": 75.0 }
    ],
    "calls_by_hour": [
      { "hour": "09:00", "count": 14 },
      { "hour": "10:00", "count": 22 }
    ],
    "dispositions_summary": [
      { "disposition": "Venta", "count": 35, "percentage": 27.3 },
      { "disposition": "Interesado", "count": 25, "percentage": 19.5 }
    ],
    "agent_workforce": [
      {
        "id": 1,
        "name": "Juan Pérez",
        "email": "juan@empresa.com",
        "total_calls": 45,
        "effective_calls": 32,
        "effective_percentage": 71.1,
        "tmo_seconds": 160,
        "tmo_formatted": "02:40",
        "ineffective_calls": 10,
        "test_calls": 3,
        "dispositions": { "Venta": 15, "Interesado": 10 }
      }
    ],
    "recent_calls": [
      {
        "id": 101,
        "call_id": "call_1788460000_abc123",
        "phone_number": "+51913086096",
        "agent_name": "Juan Pérez",
        "duration_seconds": 45,
        "duration_formatted": "00:45",
        "status": "completed",
        "call_category": "effective",
        "disposition": "Venta",
        "recording_url": "/api/v1/accounts/1/voip/recordings/call_1788460000_abc123",
        "created_at": "04/09/2026 15:30"
      }
    ]
  }
  ```

---

### C. Reporte de Efectividad de Base de Datos (`GET /database_reports`)
Segmenta la prospección saliente, la tasa de respuesta y las vueltas de la base de datos (ciclos de tickets reabiertos/resueltos).

- **Query Parameters:**
  - `range`: `'hour'` (últimas 24h), `'day'` (últimos 7 días), `'week'` (último mes), `'month'` (histórico), `'year'`.
- **Estructura de Respuesta:**
  ```json
  {
    "summary": {
      "total_outbound": 1540,
      "total_incoming": 620,
      "total_prospects_contacted": 890,
      "total_prospects_replied": 415,
      "response_rate": 46.6,
      "total_resolutions": 780,
      "multi_turn_conversations": 210,
      "avg_turns": 1.45,
      "max_turns": 6,
      "range_type": "month"
    },
    "turns_distribution": {
      "1_vuelta": 570,
      "2_vueltas": 140,
      "3_vueltas": 50,
      "4_mas_vueltas": 20
    },
    "time_series": [
      {
        "timestamp": "2026-09-01",
        "outbound": 120,
        "incoming": 55,
        "resolutions": 48
      }
    ]
  }
  ```

---

## 3. Políticas de Seguridad y Enmascaramiento

1. **Aislamiento Multi-Tenant:**
   Todos los queries se ejecutan a través del proxy de sesión `Current.account`, impidiendo cualquier fuga cross-tenant de llamadas o audios.
2. **Enmascaramiento de Teléfonos:**
   El número telefónico pasa por `PhoneMaskerService.can_view_full_phone?`. Si el usuario no tiene permisos de visualización total, el número es ofuscado automáticamente (ej. `+51913***096`).
3. **Control de Acceso Administrativo:**
   Las acciones que modifican la infraestructura (`update_config`, `update_agent`) exigen rol de administrador (`check_admin_authorization`).
