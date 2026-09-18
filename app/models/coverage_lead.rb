# frozen_string_literal: true

# == Schema Information
#
# Table name: coverage_leads
#
#  id                :bigint           not null, primary key
#  agente_nombre     :string
#  alerta_tiempo     :string
#  ciudad_distrito   :string
#  contacto_sugerido :string
#  departamento      :string
#  empresa           :string
#  estado            :string           default("Por Contactar")
#  etiqueta          :string
#  fecha_asignacion  :datetime
#  fecha_envio       :datetime
#  fecha_ingreso     :datetime
#  fecha_respuesta   :datetime
#  interaccion_log   :text
#  lat               :decimal(10, 6)
#  lon               :decimal(10, 6)
#  macro_sector      :string
#  mensaje_whatsapp  :text
#  monto_venta       :string
#  motivo_perdida    :string
#  oferta_solucion   :text
#  phone_number      :string
#  producto_interes  :string
#  raw_data          :jsonb
#  sector            :string
#  sitio_web         :string
#  synced_at         :datetime
#  tiempo_operativo  :string
#  ubicacion         :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  contact_id        :bigint
#  conversation_id   :bigint
#  datatable_id      :bigint
#  user_id           :bigint
#
# Indexes
#
#  idx_cov_leads_account_contact       (account_id,contact_id)
#  idx_cov_leads_account_datatable     (account_id,datatable_id) UNIQUE
#  idx_cov_leads_account_dpto          (account_id,departamento)
#  idx_cov_leads_account_estado        (account_id,estado)
#  idx_cov_leads_account_macro_sector  (account_id,macro_sector)
#  idx_cov_leads_account_phone         (account_id,phone_number)
#  idx_cov_leads_account_user          (account_id,user_id)
#
class CoverageLead < ApplicationRecord
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :user, optional: true

  validates :account_id, presence: true
  validates :datatable_id, uniqueness: { scope: :account_id }, allow_nil: true

  scope :by_departamento, ->(dpto) { where(departamento: dpto) if dpto.present? && dpto != 'ALL' }
  scope :by_ciudad, ->(ciudad) { where(ciudad_distrito: ciudad) if ciudad.present? && ciudad != 'ALL' }
  scope :by_macro_sector, ->(sec) { where(macro_sector: sec) if sec.present? && sec != 'ALL' }
  scope :by_estado, ->(est) { where(estado: est) if est.present? && est != 'ALL' }
  scope :by_agente, ->(ag) { where(agente_nombre: ag) if ag.present? && ag != 'ALL' }
  scope :by_date_range, lambda { |start_date, end_date|
    if start_date.present? && end_date.present?
      where(fecha_envio: start_date.beginning_of_day..end_date.end_of_day)
        .or(where(fecha_ingreso: start_date.beginning_of_day..end_date.end_of_day))
    elsif start_date.present?
      where('fecha_envio >= ? OR fecha_ingreso >= ?', start_date.beginning_of_day, start_date.beginning_of_day)
    elsif end_date.present?
      where('fecha_envio <= ? OR fecha_ingreso <= ?', end_date.end_of_day, end_date.end_of_day)
    end
  }

  def clean_status
    if estado.to_s.include?('Contactado') || estado.to_s.include?('Prueba enviada')
      'Contactado'
    elsif estado.to_s.include?('Por Contactar')
      'Por Contactar'
    elsif estado.to_s.include?('Enviando')
      'Enviando'
    else
      'Sin WhatsApp / Error'
    end
  end

  def status_color
    case clean_status
    when 'Contactado' then '#27ae60'
    when 'Por Contactar' then '#f39c12'
    when 'Enviando' then '#3498db'
    else '#e74c3c'
    end
  end
end
