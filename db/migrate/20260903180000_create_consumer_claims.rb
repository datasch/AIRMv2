# frozen_string_literal: true

class CreateConsumerClaims < ActiveRecord::Migration[7.0]
  def change
    create_table :consumer_claims do |t|
      t.string :ticket_code, null: false, index: { unique: true }
      t.string :claim_type, null: false, default: 'reclamo' # 'reclamo' (disconformidad bien/servicio) or 'queja' (atención)
      t.string :status, null: false, default: 'pending' # 'pending', 'in_review', 'resolved', 'rejected'

      # Consumidor reclamante
      t.string :document_type, null: false # 'DNI', 'CE', 'RUC', 'PASAPORTE'
      t.string :document_number, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone, null: false
      t.string :email, null: false
      t.string :address, null: false
      t.string :department
      t.string :province
      t.string :district
      t.boolean :is_minor, default: false
      t.string :parent_name

      # Bien contratado
      t.string :good_type, null: false, default: 'servicio' # 'producto' or 'servicio'
      t.decimal :amount_claimed, precision: 10, scale: 2
      t.string :currency, default: 'PEN'
      t.text :product_description, null: false

      # Detalle de la reclamación
      t.text :details, null: false
      t.text :consumer_order, null: false

      # Gestión Super Admin
      t.text :admin_notes
      t.text :admin_response
      t.datetime :resolved_at
      t.string :resolved_by

      t.timestamps
    end
  end
end
