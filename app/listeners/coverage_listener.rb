# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
class CoverageListener < BaseListener
  include Singleton
  include Events::Types

  def message_created(event)
    message, account = extract_message_and_account(event)
    return if account.blank? || message.blank?

    conversation = message.conversation
    contact = conversation&.contact
    return if contact.blank?

    lead = find_lead(account, contact, conversation)
    return if lead.blank?

    update_lead_on_message!(lead, message, conversation)
    broadcast_lead_update(account, lead)
  rescue StandardError => e
    Rails.logger.warn "[CoverageListener#message_created] #{e.message}"
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)
    return if account.blank? || conversation.blank?

    contact = conversation.contact
    return if contact.blank?

    lead = find_lead(account, contact, conversation)
    return if lead.blank?

    updated = apply_conversation_updates!(lead, conversation)
    if updated
      lead.save!
      broadcast_lead_update(account, lead)
    end
  rescue StandardError => e
    Rails.logger.warn "[CoverageListener#conversation_updated] #{e.message}"
  end

  def broadcast_lead_update(account, lead)
    tokens = user_tokens(account)
    return if tokens.blank?

    payload = {
      lead: build_lead_payload(lead),
      account_id: account.id
    }

    ::ActionCableBroadcastJob.perform_later(tokens.uniq, COVERAGE_LEAD_UPDATED, payload)
  end

  private

  def apply_conversation_updates!(lead, conversation)
    updated = false
    if conversation.assignee.present? && lead.agente_nombre != conversation.assignee.name
      lead.user = conversation.assignee
      lead.agente_nombre = conversation.assignee.available_name || conversation.assignee.name
      updated = true
    end

    if conversation.status == 'resolved' && lead.estado.to_s.exclude?('Contactado')
      lead.estado = 'Contactado'
      updated = true
    end

    updated
  end

  def find_lead(account, contact, conversation)
    lead = account.coverage_leads.find_by(contact_id: contact.id)
    lead ||= account.coverage_leads.find_by(conversation_id: conversation.id) if conversation.present?

    if lead.blank? && contact.phone_number.present?
      clean = contact.phone_number.to_s.gsub(/\D/, '')
      last_9 = clean.length >= 9 ? clean[-9..] : clean
      lead = account.coverage_leads.where('phone_number LIKE ?', "%#{last_9}").first
      lead.update(contact_id: contact.id) if lead.present? && lead.contact_id.blank?
    end

    lead
  end

  def update_lead_on_message!(lead, message, conversation)
    lead.conversation = conversation if lead.conversation_id.blank?
    lead.contact_id = conversation.contact_id if lead.contact_id.blank?

    if message.outgoing?
      lead.estado = 'Contactado' if lead.estado.to_s.exclude?('Contactado')
      lead.fecha_envio ||= message.created_at
    elsif message.incoming?
      lead.fecha_respuesta ||= message.created_at
      if lead.fecha_envio.present? && lead.tiempo_operativo.blank?
        diff_mins = [((message.created_at - lead.fecha_envio) / 60).round, 0].max
        lead.tiempo_operativo = "#{diff_mins}m"
      end
    end

    if conversation.assignee.present?
      lead.user = conversation.assignee
      lead.agente_nombre = conversation.assignee.available_name || conversation.assignee.name
    end

    lead.save!
  end

  def build_lead_payload(lead)
    macro_info = Coverage::SyncService.clasificar_macro_sector(lead.macro_sector || lead.sector)

    {
      id: lead.id,
      datatable_id: lead.datatable_id,
      empresa: lead.empresa.presence || 'Empresa Sin Nombre',
      sector: lead.sector.presence || 'General',
      macro_sector: lead.macro_sector.presence || macro_info[:nombre],
      sector_color: macro_info[:color],
      contacto_sugerido: lead.contacto_sugerido.presence || 'No especificado',
      phone_number: lead.phone_number,
      ubicacion: lead.ubicacion.presence || '',
      departamento: lead.departamento.presence || 'Lima',
      ciudad_distrito: lead.ciudad_distrito.presence || 'Lima',
      lat: lead.lat&.to_f || -12.0520,
      lon: lead.lon&.to_f || -77.0380,
      sitio_web: lead.sitio_web.presence || '',
      oferta_solucion: lead.oferta_solucion.presence || '',
      estado: lead.estado.presence || 'Por Contactar',
      estado_clean: lead.clean_status,
      status_color: lead.status_color,
      fecha_ingreso: lead.fecha_ingreso&.strftime('%Y-%m-%d %H:%M'),
      fecha_envio: lead.fecha_envio&.strftime('%Y-%m-%d %H:%M'),
      fecha_dia: (lead.fecha_envio || lead.fecha_ingreso)&.strftime('%Y-%m-%d'),
      agente: lead.agente_nombre.presence || 'Sin Asignar',
      contact_id: lead.contact_id,
      conversation_id: lead.conversation_id,
      tiempo_operativo: lead.tiempo_operativo.presence || '',
      alerta_tiempo: lead.alerta_tiempo.presence || ''
    }
  end

  def user_tokens(account)
    agent_tokens = account.agents.pluck(:pubsub_token)
    admin_tokens = account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).compact_blank.uniq
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
