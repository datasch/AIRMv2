# frozen_string_literal: true

class Api::V1::Accounts::VoipController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization, only: [:update_config, :update_agent]

  def show_config
    account = Current.account
    user = Current.user

    voip_settings = account&.settings&.dig('voip') || {}
    user_sip = user&.custom_attributes&.dig('sip') || {}

    is_admin = Current.account_user&.administrator?

    response_data = {
      enabled: voip_settings['enabled'].nil? ? (ENV['ASTERISK_ENABLED'].to_s == 'true' || ENV['ASTERISK_WS_URL'].present?) : voip_settings['enabled'],
      ws_url: voip_settings['ws_url'].presence || ENV['ASTERISK_WS_URL'] || 'wss://voip.giantucchi.com:8089/ws',
      sip_domain: voip_settings['sip_domain'].presence || ENV['ASTERISK_SIP_DOMAIN'] || 'giantucchi.com',
      caller_id: voip_settings['caller_id'].presence || ENV['ASTERISK_CALLER_ID'],
      concurrency_limit: voip_settings['concurrency_limit'] || 1,
      gateway_ip: ENV['VOIP_GATEWAY_IP'].presence || request.host,
      agent: {
        extension: user_sip['extension'].presence || user&.custom_attributes&.dig('sip_extension'),
        password: user_sip['password'].presence || user&.custom_attributes&.dig('sip_password'),
        display_name: user&.available_name || user&.name
      },
      active_calls: current_active_calls
    }

    if is_admin
      response_data.merge!(
        trunk_provider: voip_settings['trunk_provider'].presence || 'voiprabbit',
        trunk_host: voip_settings['trunk_host'].presence || '149.20.185.4',
        trunk_port: voip_settings['trunk_port'] || 5060,
        trunk_user: voip_settings['trunk_user'].presence || 'JoseMaster',
        trunk_password: voip_settings['trunk_password'].presence || '',
        trunk_auth_mode: voip_settings['trunk_auth_mode'].presence || 'credentials'
      )
    end

    render json: response_data
  rescue StandardError => e
    Rails.logger.error "[VoipController#show_config] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: {
      enabled: false,
      ws_url: '',
      sip_domain: '',
      caller_id: nil,
      concurrency_limit: 1,
      gateway_ip: request.host,
      agent: { extension: nil, password: nil, display_name: Current.user&.name },
      active_calls: []
    }
  end

  def update_config
    account = Current.account
    voip_params = params.require(:voip).permit(
      :enabled, :ws_url, :sip_domain, :caller_id, :concurrency_limit,
      :trunk_provider, :trunk_host, :trunk_port, :trunk_user, :trunk_password, :trunk_auth_mode
    )

    current_settings = (account.settings || {}).dup
    current_settings['voip'] = (current_settings['voip'] || {}).merge(voip_params.to_h)
    account.settings = current_settings
    account.save!

    render json: { success: true, voip: account.settings['voip'] }
  rescue StandardError => e
    Rails.logger.error "[VoipController#update_config] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def agents
    account = Current.account
    agents_list = account.users.order_by_full_name.includes(:account_users).map do |agent|
      sip_data = (agent.custom_attributes || {})['sip'] || {}
      account_user = agent.account_users.find { |au| au.account_id == account.id }
      user_role = account_user&.role || agent.role || 'agent'
      {
        id: agent.id,
        name: agent.available_name || agent.name,
        email: agent.email,
        role: user_role,
        extension: sip_data['extension'].presence || agent.custom_attributes&.dig('sip_extension'),
        has_password: (sip_data['password'].presence || agent.custom_attributes&.dig('sip_password')).present?
      }
    end

    render json: { agents: agents_list }
  rescue StandardError => e
    Rails.logger.error "[VoipController#agents] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { agents: [] }
  end

  def update_agent
    user_id = params[:user_id]
    user = Current.account.users.find(user_id)

    custom_attrs = (user.custom_attributes || {}).dup
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
    Rails.logger.error "[VoipController#update_agent] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
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
    user_sip = user&.custom_attributes&.dig('sip') || {}
    extension = user_sip['extension'].presence || user&.custom_attributes&.dig('sip_extension')

    account = Current.account
    voip_settings = account&.settings&.dig('voip') || {}
    enabled = voip_settings['enabled'].nil? ? (ENV['ASTERISK_ENABLED'].to_s == 'true' || ENV['ASTERISK_WS_URL'].present?) : voip_settings['enabled']

    unless enabled
      render json: { success: false, error: 'El servicio de telefonía VoIP / PBX no está activo en esta cuenta' }, status: :unprocessable_entity and return
    end

    masked_phone = contact.display_phone_number
    agent_name = user&.available_name || user&.name

    Redis::Alfred.with do |redis|
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
    end

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
      destination: real_phone
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def call_status
    event = params[:event] # 'started', 'connected', 'ended', 'failed'
    raw_phone = params[:phone_number].to_s
    phone_number = PhoneMaskerService.can_view_full_phone? ? raw_phone : PhoneMaskerService.mask(raw_phone)
    agent_name = Current.user&.available_name || Current.user&.name
    agent_id = Current.user.id
    account_id = Current.account.id

    Redis::Alfred.with do |redis|
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
    status = params[:status] || 'completed' # 'completed', 'cancelled', 'missed', 'busy', 'rejected'
    call_id = params[:call_id].presence || "call_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
    disposition = params[:disposition].presence
    update_conv = params[:update_conversation_tipificacion].to_s == 'true'

    is_effective = duration_seconds >= 6
    is_test = duration_seconds.between?(2, 5)
    call_category = if is_effective
                      'effective'
                    elsif is_test
                      'test'
                    else
                      'ineffective'
                    end

    conversation = Current.account.conversations.find_by(id: conversation_id)
    contact = conversation&.contact || Current.account.contacts.find_by(phone_number: phone_number)

    # Persistir en voip_call_logs
    call_log = Current.account.voip_call_logs.find_or_initialize_by(call_id: call_id)
    call_log.assign_attributes(
      user_id: Current.user&.id,
      conversation_id: conversation&.id,
      contact_id: contact&.id,
      phone_number: phone_number,
      duration_seconds: duration_seconds,
      status: status,
      call_category: call_category,
      disposition: disposition,
      recording_url: "/api/v1/accounts/#{Current.account.id}/voip/recordings/#{call_id}",
      metadata: {
        agent_name: Current.user&.name,
        initiated_at: Time.current - duration_seconds.seconds
      }
    )
    call_log.save! rescue nil

    # Si se solicitó actualizar la tipificación de la conversación, guardar en custom_attributes['tipificacion']
    if conversation.present? && update_conv && disposition.present?
      custom_attrs = (conversation.custom_attributes || {}).dup
      custom_attrs['tipificacion'] = disposition
      conversation.custom_attributes = custom_attrs
      conversation.save(validate: false)
    end

    if conversation.present?
      mins = duration_seconds / 60
      secs = duration_seconds % 60
      formatted_duration = format('%02d:%02d', mins, secs)

      label, icon = case status
                    when 'completed' then ['Llamada finalizada', '✅']
                    when 'cancelled' then ['Llamada cancelada', '⏹️']
                    when 'missed' then ['Llamada perdida', '⚠️']
                    when 'busy' then ['Línea ocupada', '📵']
                    when 'rejected' then ['Llamada rechazada', '🚫']
                    else ['Registro de llamada', '📞']
                    end

      category_badge = case call_category
                       when 'effective' then '🟢 Efectiva (>= 6s)'
                       when 'test' then '🟡 Prueba (2 a 5s)'
                       else '🔴 No efectiva'
                       end

      logged_phone = PhoneMaskerService.can_view_full_phone? ? (phone_number.presence || contact&.phone_number) : (PhoneMaskerService.mask(phone_number.presence || contact&.phone_number))
      disposition_part = disposition.present? ? "\n• Tipificación de llamada: **#{disposition}**" : ''
      audio_url = "/api/v1/accounts/#{Current.account.id}/voip/recordings/#{call_id}"
      audio_part = if is_effective || is_test
                     "\n\n🎧 **Grabación de llamada:**\n<audio controls class=\"w-full mt-2 rounded border border-slate-700 bg-slate-900/50\" preload=\"none\"><source src=\"#{audio_url}\" type=\"audio/wav\">Tu navegador no soporta el reproductor de audio.</audio>"
                   else
                     ''
                   end

      message_content = "#{icon} **#{label}** • #{category_badge}\n• Agente: #{Current.user.name}\n• Número: #{logged_phone}\n• Duración: #{formatted_duration}#{disposition_part}#{audio_part}"

      conversation.messages.create!(
        account: Current.account,
        inbox: conversation.inbox,
        message_type: :activity,
        content: message_content,
        sender: Current.user
      )
    end

    render json: { success: true, call_id: call_id, call_category: call_category }
  rescue StandardError => e
    Rails.logger.error "[VoipController#log_call] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def recording
    call_id = params[:id].to_s.gsub(/[^a-zA-Z0-9_\-]/, '')
    filename = "#{call_id}.wav"
    search_paths = [
      "/var/spool/asterisk/monitor/#{filename}",
      Rails.root.join('storage', 'recordings', filename).to_s,
      Rails.root.join('tmp', 'recordings', filename).to_s
    ]

    file_path = search_paths.find { |p| File.exist?(p) }
    if file_path.present?
      send_file file_path, type: 'audio/wav', disposition: 'inline'
    else
      render plain: 'Audio recording not found', status: :not_found
    end
  end

  def click_to_call_reports
    account = Current.account
    since_date = params[:since].present? ? Time.zone.parse(params[:since]) : 30.days.ago.beginning_of_day
    until_date = params[:until].present? ? Time.zone.parse(params[:until]) : Time.zone.now.end_of_day

    calls_scope = account.voip_call_logs.where(created_at: since_date..until_date)

    total_calls = calls_scope.count
    effective_calls = calls_scope.effective.count
    test_calls = calls_scope.test_calls.count
    ineffective_calls = calls_scope.ineffective.count

    effective_percentage = total_calls.positive? ? ((effective_calls.to_f / total_calls) * 100).round(1) : 0
    tmo_seconds = total_calls.positive? ? calls_scope.average(:duration_seconds).to_i : 0
    tmo_formatted = format('%02d:%02d', tmo_seconds / 60, tmo_seconds % 60)

    # Agrupación por día
    daily_stats = calls_scope.group('DATE(created_at)').count
    effective_daily = calls_scope.effective.group('DATE(created_at)').count
    calls_by_day = daily_stats.map do |date, total|
      eff = effective_daily[date] || 0
      {
        date: date.strftime('%Y-%m-%d'),
        total: total,
        effective: eff,
        effective_pct: total.positive? ? ((eff.to_f / total) * 100).round(1) : 0
      }
    end.sort_by { |d| d[:date] }

    # Agrupación por hora (00..23)
    hourly_stats = calls_scope.group("EXTRACT(HOUR FROM created_at)::int").count
    calls_by_hour = (0..23).map do |hour|
      {
        hour: format('%02d:00', hour),
        count: hourly_stats[hour] || 0
      }
    end

    # Desglose de tipificaciones de llamada
    disposition_counts = calls_scope.where.not(disposition: [nil, '']).group(:disposition).count
    dispositions_summary = disposition_counts.map do |disp, count|
      {
        disposition: disp,
        count: count,
        percentage: total_calls.positive? ? ((count.to_f / total_calls) * 100).round(1) : 0
      }
    end.sort_by { |d| -d[:count] }

    # Métricas de Workforce por Asesor
    agents = account.users.map do |agent|
      agent_calls = calls_scope.where(user_id: agent.id)
      agent_total = agent_calls.count
      next nil if agent_total.zero? && params[:all_agents].blank?

      agent_eff = agent_calls.effective.count
      agent_tmo = agent_total.positive? ? agent_calls.average(:duration_seconds).to_i : 0
      {
        id: agent.id,
        name: agent.available_name || agent.name,
        email: agent.email,
        total_calls: agent_total,
        effective_calls: agent_eff,
        ineffective_calls: agent_calls.ineffective.count,
        test_calls: agent_calls.test_calls.count,
        effective_percentage: agent_total.positive? ? ((agent_eff.to_f / agent_total) * 100).round(1) : 0,
        tmo_seconds: agent_tmo,
        tmo_formatted: format('%02d:%02d', agent_tmo / 60, agent_tmo % 60),
        dispositions: agent_calls.where.not(disposition: [nil, '']).group(:disposition).count
      }
    end.compact.sort_by { |a| -a[:total_calls] }

    render json: {
      metrics: {
        total_calls: total_calls,
        effective_calls: effective_calls,
        test_calls: test_calls,
        ineffective_calls: ineffective_calls,
        effective_percentage: effective_percentage,
        tmo_seconds: tmo_seconds,
        tmo_formatted: tmo_formatted
      },
      calls_by_day: calls_by_day,
      calls_by_hour: calls_by_hour,
      dispositions_summary: dispositions_summary,
      agent_workforce: agents,
      recent_calls: calls_scope.recent.limit(30).map do |c|
        {
          id: c.id,
          call_id: c.call_id,
          phone_number: PhoneMaskerService.can_view_full_phone? ? c.phone_number : PhoneMaskerService.mask(c.phone_number),
          agent_name: c.user&.name || 'Asesor',
          duration_seconds: c.duration_seconds,
          duration_formatted: c.formatted_duration,
          status: c.status,
          call_category: c.call_category,
          disposition: c.disposition || 'Sin tipificar',
          recording_url: c.recording_url,
          created_at: c.created_at.strftime('%d/%m/%Y %H:%M')
        }
      end
    }
  rescue StandardError => e
    Rails.logger.error "[VoipController#click_to_call_reports] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { error: e.message }, status: :internal_server_error
  end

  def database_reports
    account = Current.account
    range_type = params[:range] || 'month' # 'hour', 'day', 'week', 'month', 'year'

    since_date = case range_type
                 when 'hour' then 24.hours.ago
                 when 'day' then 7.days.ago.beginning_of_day
                 when 'week' then 4.weeks.ago.beginning_of_week
                 when 'year' then 1.year.ago.beginning_of_year
                 else 30.days.ago.beginning_of_day
                 end

    since_date = Time.zone.parse(params[:since]) if params[:since].present?
    until_date = params[:until].present? ? Time.zone.parse(params[:until]) : Time.zone.now.end_of_day

    # Mensajes de prospección salientes
    outbound_messages = account.messages.where(message_type: :outgoing).where(created_at: since_date..until_date)
    total_outbound = outbound_messages.count

    # Mensajes entrantes de respuesta
    incoming_messages = account.messages.where(message_type: :incoming).where(created_at: since_date..until_date)
    total_incoming = incoming_messages.count

    # Conversaciones prospectadas vs respondidas
    contacted_conversation_ids = outbound_messages.select(:conversation_id).distinct.pluck(:conversation_id)
    replied_conversation_ids = incoming_messages.where(conversation_id: contacted_conversation_ids).select(:conversation_id).distinct.pluck(:conversation_id)

    total_prospects_contacted = contacted_conversation_ids.size
    total_prospects_replied = replied_conversation_ids.size
    response_rate = total_prospects_contacted.positive? ? ((total_prospects_replied.to_f / total_prospects_contacted) * 100).round(1) : 0

    # Vueltas que ha dado la base de datos (ciclos de resolución y reapertura)
    resolutions_scope = account.reporting_events.where(name: 'conversation_resolved', created_at: since_date..until_date)
    total_resolutions = resolutions_scope.count

    cycles_by_conversation = resolutions_scope.group(:conversation_id).count
    multi_turn_conversations = cycles_by_conversation.count { |_id, count| count >= 2 }
    max_turns = cycles_by_conversation.values.max || 1
    avg_turns = cycles_by_conversation.any? ? (cycles_by_conversation.values.sum.to_f / cycles_by_conversation.size).round(2) : 1.0

    turns_distribution = {
      '1_vuelta' => cycles_by_conversation.count { |_id, count| count == 1 },
      '2_vueltas' => cycles_by_conversation.count { |_id, count| count == 2 },
      '3_vueltas' => cycles_by_conversation.count { |_id, count| count == 3 },
      '4_mas_vueltas' => cycles_by_conversation.count { |_id, count| count >= 4 }
    }

    # Desglose temporal según el rango solicitado
    date_trunc = case range_type
                 when 'hour' then 'hour'
                 when 'week' then 'week'
                 when 'year', 'month' then 'month'
                 else 'day'
                 end

    outbound_series = outbound_messages.group("DATE_TRUNC('#{date_trunc}', created_at)").count
    incoming_series = incoming_messages.group("DATE_TRUNC('#{date_trunc}', created_at)").count
    resolutions_series = resolutions_scope.group("DATE_TRUNC('#{date_trunc}', created_at)").count

    all_keys = (outbound_series.keys + incoming_series.keys + resolutions_series.keys).uniq.sort

    time_series = all_keys.map do |k|
      format_str = range_type == 'hour' ? '%Y-%m-%d %H:00' : (date_trunc == 'month' ? '%Y-%m' : '%Y-%m-%d')
      {
        timestamp: k.strftime(format_str),
        outbound: outbound_series[k] || 0,
        incoming: incoming_series[k] || 0,
        resolutions: resolutions_series[k] || 0
      }
    end

    render json: {
      summary: {
        total_outbound: total_outbound,
        total_incoming: total_incoming,
        total_prospects_contacted: total_prospects_contacted,
        total_prospects_replied: total_prospects_replied,
        response_rate: response_rate,
        total_resolutions: total_resolutions,
        multi_turn_conversations: multi_turn_conversations,
        avg_turns: avg_turns,
        max_turns: max_turns,
        range_type: range_type
      },
      turns_distribution: turns_distribution,
      time_series: time_series
    }
  rescue StandardError => e
    Rails.logger.error "[VoipController#database_reports] Error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def current_active_calls
    Redis::Alfred.with do |conn|
      redis_key = "voip:account_#{Current.account&.id}:active_calls"
      raw_calls = conn.hgetall(redis_key) || {}
      raw_calls.values.map { |v| JSON.parse(v) rescue nil }.compact
    end
  rescue StandardError => e
    Rails.logger.warn "[VoipController] current_active_calls error: #{e.message}"
    []
  end

  def check_admin_authorization
    head :forbidden unless Current.account_user&.administrator?
  end
end
