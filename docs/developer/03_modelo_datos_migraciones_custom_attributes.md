# 03. Modelo de Datos, Migraciones y Atributos Personalizados

Este documento detalla el esquema relacional en PostgreSQL para el registro y trazabilidad de llamadas telefónicas, las asociaciones de modelos en Ruby on Rails y el funcionamiento del atributo personalizado de tipificación comercial.

---

## 1. Esquema de Base de Datos (`voip_call_logs`)

La tabla `voip_call_logs` fue introducida mediante la migración [20260904170000_create_voip_call_logs_and_tipificacion.rb](file:///home/giantucchi/Proyectos/chatwoot/db/migrate/20260904170000_create_voip_call_logs_and_tipificacion.rb):

```ruby
create_table :voip_call_logs do |t|
  t.bigint  :account_id, null: false
  t.bigint  :user_id
  t.bigint  :conversation_id
  t.bigint  :contact_id
  t.string  :call_id, null: false
  t.string  :phone_number
  t.integer :duration_seconds, default: 0, null: false
  t.string  :status, default: 'completed'
  t.string  :call_category, default: 'ineffective'
  t.string  :disposition
  t.string  :recording_url
  t.jsonb   :metadata, default: {}

  t.timestamps
end
```

### Índices de Rendimiento
Para garantizar consultas de reportería sub-milisegundo sobre millones de registros:
- `[:account_id, :created_at]`: Optimiza el filtrado temporal por rangos (`since` .. `until`).
- `[:account_id, :user_id]`: Optimiza la agregación de métricas de productividad por asesor.
- `[:account_id, :call_category]`: Acelera los conteos de llamadas efectivas, pruebas y no efectivas.
- `[:account_id, :disposition]`: Acelera la agrupación de tipificaciones comerciales.
- `:call_id` (Unique): Garantiza idempotencia ante reintentos de red.

---

## 2. Modelo ActiveRecord (`VoipCallLog`)

El modelo [app/models/voip_call_log.rb](file:///home/giantucchi/Proyectos/chatwoot/app/models/voip_call_log.rb) encapsula la lógica de negocio y categorización:

```ruby
class VoipCallLog < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true

  validates :call_id, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :effective, -> { where(call_category: 'effective') }
  scope :test_calls, -> { where(call_category: 'test') }
  scope :ineffective, -> { where(call_category: 'ineffective') }

  DISPOSITIONS = [
    'Venta',
    'Interesado',
    'Agendado',
    'Volver a llamar',
    'Persona mayor',
    'Saturación',
    'No interesado',
    'Buzón de voz',
    'No contesta',
    'Número equivocado'
  ].freeze

  def effective?
    duration_seconds >= 6
  end

  def test_call?
    duration_seconds.between?(2, 5)
  end

  def formatted_duration
    mins = duration_seconds / 60
    secs = duration_seconds % 60
    format('%02d:%02d', mins, secs)
  end
end
```

---

## 3. Atributo Personalizado de Conversación (`tipificacion`)

Para cumplir el requerimiento de tener **dos métricas separadas** (Tipificación de llamada vs Tipificación de conversación):

1. Se registró en `CustomAttributeDefinition` el atributo:
   - `attribute_key`: `'tipificacion'`
   - `attribute_display_name`: `'Tipificación'`
   - `attribute_model`: `'conversation_attribute'`
   - `attribute_display_type`: `'list'`
   - `attribute_values`: Los 10 estados estándar de la casuística de negocio.
2. Al crearse, este atributo aparece automáticamente en el panel lateral derecho del chat (*"Información de la conversación"*), permitiendo que el vendedor tipifique los chats incluso si no realiza llamadas telefónicas.
3. Si el asesor realiza una llamada y marca la casilla *"Guardar también en conversación"* en el dialer, el controlador actualiza concurrentemente:
   ```ruby
   if conversation.present? && update_conv && disposition.present?
     custom_attrs = (conversation.custom_attributes || {}).dup
     custom_attrs['tipificacion'] = disposition
     conversation.custom_attributes = custom_attrs
     conversation.save(validate: false)
   end
   ```
