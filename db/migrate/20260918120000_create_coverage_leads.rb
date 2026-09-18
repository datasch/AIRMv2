# frozen_string_literal: true

class CreateCoverageLeads < ActiveRecord::Migration[7.0]
  def change
    create_table :coverage_leads do |t|
      t.bigint :account_id, null: false
      t.bigint :datatable_id
      t.string :phone_number
      t.string :empresa
      t.string :sector
      t.string :macro_sector
      t.string :contacto_sugerido
      t.string :ubicacion
      t.string :departamento
      t.string :ciudad_distrito
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lon, precision: 10, scale: 6
      t.string :sitio_web
      t.text :oferta_solucion
      t.text :mensaje_whatsapp
      t.string :estado, default: 'Por Contactar'
      t.datetime :fecha_ingreso
      t.datetime :fecha_envio
      t.string :agente_nombre
      t.bigint :contact_id
      t.bigint :conversation_id
      t.bigint :user_id
      t.datetime :fecha_asignacion
      t.datetime :fecha_respuesta
      t.string :tiempo_operativo
      t.string :alerta_tiempo
      t.string :etiqueta
      t.string :monto_venta
      t.string :producto_interes
      t.string :motivo_perdida
      t.text :interaccion_log
      t.datetime :synced_at
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    add_index :coverage_leads, [:account_id, :datatable_id], unique: true, name: 'idx_cov_leads_account_datatable'
    add_index :coverage_leads, [:account_id, :phone_number], name: 'idx_cov_leads_account_phone'
    add_index :coverage_leads, [:account_id, :departamento], name: 'idx_cov_leads_account_dpto'
    add_index :coverage_leads, [:account_id, :macro_sector], name: 'idx_cov_leads_account_macro_sector'
    add_index :coverage_leads, [:account_id, :estado], name: 'idx_cov_leads_account_estado'
    add_index :coverage_leads, [:account_id, :user_id], name: 'idx_cov_leads_account_user'
    add_index :coverage_leads, [:account_id, :contact_id], name: 'idx_cov_leads_account_contact'
  end
end
