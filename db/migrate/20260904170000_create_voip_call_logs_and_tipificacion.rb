# frozen_string_literal: true

class CreateVoipCallLogsAndTipificacion < ActiveRecord::Migration[7.0]
  def up
    create_table :voip_call_logs do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.bigint :conversation_id
      t.bigint :contact_id
      t.string :call_id, null: false
      t.string :phone_number
      t.integer :duration_seconds, default: 0, null: false
      t.string :status, default: 'completed'
      t.string :call_category, default: 'ineffective'
      t.string :disposition
      t.string :recording_url
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :voip_call_logs, [:account_id, :created_at], name: 'idx_voip_call_logs_account_created'
    add_index :voip_call_logs, [:account_id, :user_id], name: 'idx_voip_call_logs_account_user'
    add_index :voip_call_logs, [:account_id, :call_category], name: 'idx_voip_call_logs_account_category'
    add_index :voip_call_logs, [:account_id, :disposition], name: 'idx_voip_call_logs_account_disposition'
    add_index :voip_call_logs, :call_id, unique: true, name: 'idx_voip_call_logs_call_id'

    # Seed CustomAttributeDefinition 'tipificacion' for all existing accounts
    dispositions = [
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
    ]

    Account.find_each do |account|
      cad = account.custom_attribute_definitions.find_or_initialize_by(
        attribute_key: 'tipificacion',
        attribute_model: 'conversation_attribute'
      )
      cad.attribute_display_name = 'Tipificación'
      cad.attribute_display_type = 'list'
      cad.attribute_values = dispositions
      cad.attribute_description = 'Tipificación comercial de la conversación / chat'
      cad.save(validate: false)
    end
  end

  def down
    drop_table :voip_call_logs, if_exists: true
    CustomAttributeDefinition.where(attribute_key: 'tipificacion', attribute_model: 'conversation_attribute').delete_all
  end
end
