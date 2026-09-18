# frozen_string_literal: true

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
