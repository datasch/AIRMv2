# frozen_string_literal: true

class Api::V1::Accounts::VoipController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization, only: [:update_config, :update_agent]

  def config
    account = Current.account
    user = Current.user

    voip_settings = account.settings['voip'] || {}
    user_sip = (user.custom_attributes || {})['sip'] || {}

    render json: {
      enabled: voip_settings['enabled'].nil? ? (ENV['ASTERISK_ENABLED'].to_s == 'true' || ENV['ASTERISK_WS_URL'].present?) : voip_settings['enabled'],
      ws_url: voip_settings['ws_url'].presence || ENV['ASTERISK_WS_URL'] || 'wss://voip.giantucchi.com:8089/ws',
      sip_domain: voip_settings['sip_domain'].presence || ENV['ASTERISK_SIP_DOMAIN'] || 'giantucchi.com',
      caller_id: voip_settings['caller_id'].presence || ENV['ASTERISK_CALLER_ID'],
      concurrency_limit: voip_settings['concurrency_limit'] || 1,
      agent: {
        extension: user_sip['extension'].presence || user.custom_attributes&.dig('sip_extension'),
        password: user_sip['password'].presence || user.custom_attributes&.dig('sip_password'),
        display_name: user.available_name || user.name
      },
      active_calls: current_active_calls
    }
  end

  def update_config
    account = Current.account
    voip_params = params.require(:voip).permit(:enabled, :ws_url, :sip_domain, :caller_id, :concurrency_limit)

    current_settings = account.settings || {}
    current_settings['voip'] = (current_settings['voip'] || {}).merge(voip_params.to_h)
    account.settings = current_settings
    account.save!

    render json: { success: true, voip: account.settings['voip'] }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def agents
    account = Current.account
    agents_list = account.users.map do |agent|
      sip_data = (agent.custom_attributes || {})['sip'] || {}
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        role: agent.role_in_account(account),
        extension: sip_data['extension'].presence || agent.custom_attributes&.dig('sip_extension'),
        has_password: (sip_data['password'].presence || agent.custom_attributes&.dig('sip_password')).present?
      }
    end

    render json: { agents: agents_list }
  end

  def update_agent
    user_id = params[:user_id]
    user = Current.account.users.find(user_id)

    custom_attrs = user.custom_attributes || {}
    custom_attrs['sip'] = (custom_attrs['sip'] || {}).merge({
      'extension' => params[:extension].to_s.strip,
      'password' => params[:password].to_s.strip
    }.compact_blank)

    user.custom_attributes = custom_attrs
    user.save!

    render json: {
      success: true,
      agent: {
        id: user.id,
        extension: custom_attrs.dig('sip', 'extension')
      }
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def call_contact
    contact_id = params[:contact_id]
    conversation_id = params[:conversation_id]

    contact = Current.account.contacts.find_by(id: contact_id)
    render json: { success: false, error: 'Contacto no encontrado' }, status: :not_found and return if contact.blank?

    real_phone = contact.phone_number.presence
    if real_phone.blank?
      render json: { success: false, error: 'El contacto no tiene un número telefónico registrado' }, status: :unprocessable_entity and return
    end

    user = Current.user
    user_sip = (user.custom_attributes || {})['sip'] || {}
    extension = user_sip['extension'].presence || user.custom_attributes&.dig('sip_extension')

    account = Current.account
    voip_settings = account.settings['voip'] || {}
    enabled = voip_settings['enabled'].nil? ? (ENV['ASTERISK_ENABLED'].to_s == 'true' || ENV['ASTERISK_WS_URL'].present?) : voip_settings['enabled']

    unless enabled
      render json: { success: false, error: 'El servicio de telefonía VoIP / PBX no está activo en esta cuenta' }, status: :unprocessable_entity and return
    end

    masked_phone = contact.display_phone_number
    agent_name = user.available_name || user.name

    redis = Redis::Alfred.redis
    redis_key = "voip:account_#{account.id}:active_calls"
    call_data = {
      agent_id: user.id,
      agent_name: agent_name,
      contact_id: contact.id,
      contact_name: contact.display_name,
      phone_number: masked_phone,
      status: 'calling',
      started_at: Time.current.to_i
    }
    redis.hset(redis_key, user.id.to_s, call_data.to_json)
    redis.expire(redis_key, 3600)

    active_calls = current_active_calls
    ActionCableBroadcastJob.perform_later(
      ["account_#{account.id}"],
      'voip.call_status_changed',
      {
        active_calls: active_calls,
        event: 'started',
        agent_id: user.id,
        agent_name: agent_name,
        contact_id: contact.id,
        contact_name: contact.display_name,
        phone_number: masked_phone
      }
    )

    if conversation_id.present?
      conversation = account.conversations.find_by(id: conversation_id)
      if conversation.present?
        message_content = "📞 **Llamada saliente iniciada**\n• Agente: #{agent_name}\n• Contacto: #{contact.display_name}\n• Número: #{masked_phone}"
        conversation.messages.create!(
          account: account,
          inbox: conversation.inbox,
          message_type: :activity,
          content: message_content,
          sender: user
        )
      end
    end

    render json: {
      success: true,
      contact: {
        id: contact.id,
        name: contact.display_name,
        phone_number: masked_phone
      },
      agent_extension: extension,
      sip_domain: voip_settings['sip_domain'].presence || ENV['ASTERISK_SIP_DOMAIN'] || 'giantucchi.com',
      destination: PhoneMaskerService.can_view_full_phone? ? real_phone : "contact_#{contact.id}"
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def call_status
    event = params[:event] # 'started', 'connected', 'ended', 'failed'
    raw_phone = params[:phone_number].to_s
    phone_number = PhoneMaskerService.can_view_full_phone? ? raw_phone : PhoneMaskerService.mask(raw_phone)
    agent_name = Current.user.available_name || Current.user.name
    agent_id = Current.user.id
    account_id = Current.account.id

    redis = Redis::Alfred.redis
    redis_key = "voip:account_#{account_id}:active_calls"

    case event
    when 'started', 'ringing', 'connected'
      call_data = {
        agent_id: agent_id,
        agent_name: agent_name,
        phone_number: phone_number,
        status: event,
        started_at: Time.current.to_i
      }
      redis.hset(redis_key, agent_id.to_s, call_data.to_json)
      redis.expire(redis_key, 3600) # 1 hour max safety TTL
    when 'ended', 'failed'
      redis.hdel(redis_key, agent_id.to_s)
    end

    active_calls = current_active_calls
    ActionCableBroadcastJob.perform_later(
      ["account_#{account_id}"],
      'voip.call_status_changed',
      {
        active_calls: active_calls,
        event: event,
        agent_id: agent_id,
        agent_name: agent_name,
        phone_number: phone_number
      }
    )

    render json: { success: true, active_calls: active_calls }
  end

  def log_call
    conversation_id = params[:conversation_id]
    phone_number = params[:phone_number]
    duration_seconds = params[:duration_seconds].to_i
    status = params[:status] || 'completed' # 'completed', 'missed', 'busy', 'rejected'

    conversation = Current.account.conversations.find_by(id: conversation_id)
    if conversation.present?
      mins = duration_seconds / 60
      secs = duration_seconds % 60
      formatted_duration = format('%02d:%02d', mins, secs)

      icon = status == 'completed' ? '📞' : '📵'
      label = case status
              when 'completed' then 'Llamada saliente completada'
              when 'missed', 'no_answer' then 'Llamada no contestada'
              when 'busy' then 'Línea ocupada'
              when 'rejected' then 'Llamada rechazada'
              else 'Llamada finalizada'
              end

      contact = conversation.contact
      logged_phone = PhoneMaskerService.can_view_full_phone? ? (phone_number.presence || contact&.phone_number) : (PhoneMaskerService.mask(phone_number.presence || contact&.phone_number))

      message_content = "#{icon} **#{label}**\n• Agente: #{Current.user.name}\n• Número: #{logged_phone}\n• Duración: #{formatted_duration}"

      conversation.messages.create!(
        account: Current.account,
        inbox: conversation.inbox,
        message_type: :activity,
        content: message_content,
        sender: Current.user
      )
    end

    render json: { success: true }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def current_active_calls
    redis = Redis::Alfred.redis
    redis_key = "voip:account_#{Current.account.id}:active_calls"
    raw_calls = redis.hgetall(redis_key) || {}
    raw_calls.values.map { |v| JSON.parse(v) rescue nil }.compact
  rescue StandardError
    []
  end

  def check_admin_authorization
    authorize :account, :show?
    head :forbidden unless Current.account_user&.administrator?
  end
end
