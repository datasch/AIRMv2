# frozen_string_literal: true

class Whatsapp::EvolutionService
  attr_reader :base_url, :api_key

  def initialize(base_url: nil, api_key: nil)
    @base_url = (base_url || ENV['EVOLUTION_API_URL'] || 'http://evolution-api:8080').chomp('/')
    @api_key = (api_key || ENV['EVOLUTION_API_KEY'] || 'airm_evolution_secret_api_key_2026')
  end

  def status
    response = HTTParty.get("#{base_url}/instance/fetchInstances", headers: headers, timeout: 5)
    return { online: false, error: 'Cannot connect to Evolution API gateway' } unless response.success?

    data = parse_json(response.body)
    { online: true, instances: data }
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Status error: #{e.message}"
    { online: false, error: e.message }
  end

  def instance_status(instance_name)
    response = HTTParty.get("#{base_url}/instance/connectionState/#{CGI.escape(instance_name)}", headers: headers, timeout: 8)
    return { connected: false, state: 'disconnected' } unless response.success?

    data = parse_json(response.body)
    state = data.dig('instance', 'state') || data['state'] || 'disconnected'
    is_connected = %w[open connected].include?(state.to_s.downcase)

    {
      connected: is_connected,
      state: state,
      instance_name: instance_name
    }
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Instance status error for #{instance_name}: #{e.message}"
    { connected: false, state: 'error', error: e.message }
  end

  def create_instance(instance_name, qrcode: true)
    payload = {
      instanceName: instance_name,
      token: SecureRandom.hex(16),
      qrcode: qrcode,
      integration: 'WHATSAPP-BAILEYS'
    }

    response = HTTParty.post(
      "#{base_url}/instance/create",
      headers: headers,
      body: payload.to_json,
      timeout: 15
    )

    data = parse_json(response.body)

    if response.success?
      qr_base64 = data.dig('qrcode', 'base64') || data.dig('instance', 'qrcode', 'base64')
      qr_code = data.dig('qrcode', 'code') || data.dig('instance', 'qrcode', 'code')

      return {
        success: true,
        instance: data['instance'] || data,
        qr_link: qr_base64,
        qr_code: qr_code
      }
    end

    # If instance already exists, try to get existing QR / connect
    if response.code == 403 || response.code == 409 || data['message'].to_s.include?('already in use')
      return connect_qr(instance_name)
    end

    { success: false, error: data['message'] || data['error'] || 'Failed to create Evolution instance' }
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Create instance error: #{e.message}"
    { success: false, error: e.message }
  end

  def connect_qr(instance_name)
    response = HTTParty.get("#{base_url}/instance/connect/#{CGI.escape(instance_name)}", headers: headers, timeout: 15)
    data = parse_json(response.body)

    if response.success?
      qr_base64 = data['base64'] || data.dig('qrcode', 'base64')
      qr_code = data['code'] || data.dig('qrcode', 'code')

      {
        success: true,
        instance_name: instance_name,
        qr_link: qr_base64,
        qr_code: qr_code,
        qr_duration: 40
      }
    else
      { success: false, error: data['message'] || 'Failed to generate QR from Evolution API' }
    end
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Connect QR error: #{e.message}"
    { success: false, error: e.message }
  end

  def configure_chatwoot(instance_name:, account_id:, user_token:, inbox_id: nil, name_inbox: 'WhatsApp')
    payload = {
      enabled: true,
      accountId: account_id.to_s,
      token: user_token,
      url: ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000').chomp('/'),
      nameInbox: name_inbox || 'WhatsApp',
      signMsg: false,
      reopenConversation: true,
      conversationPending: false,
      importContacts: true,
      importMessages: false
    }

    # Fallback keys for backward compatibility
    payload[:account_id] = account_id.to_s
    payload[:name_inbox] = name_inbox if name_inbox.present?
    payload[:inbox_id] = inbox_id.to_s if inbox_id.present?

    response = HTTParty.post(
      "#{base_url}/chatwoot/set/#{CGI.escape(instance_name)}",
      headers: headers,
      body: payload.to_json,
      timeout: 15
    )

    data = parse_json(response.body)
    if response.success?
      Rails.logger.info "[Evolution API] Successfully linked instance #{instance_name} to Chatwoot Account #{account_id} (Inbox: #{inbox_id})"
      { success: true, results: data }
    else
      Rails.logger.warn "[Evolution API] Failed to link Chatwoot for #{instance_name}: #{data}"
      { success: false, error: data['message'] || 'Failed to configure Chatwoot' }
    end
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Configure Chatwoot error: #{e.message}"
    { success: false, error: e.message }
  end

  def logout_instance(instance_name)
    response = HTTParty.delete("#{base_url}/instance/logout/#{CGI.escape(instance_name)}", headers: headers, timeout: 10)
    data = parse_json(response.body)
    { success: response.success?, message: data['message'] }
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Logout instance error: #{e.message}"
    { success: false, error: e.message }
  end

  def delete_instance(instance_name)
    response = HTTParty.delete("#{base_url}/instance/delete/#{CGI.escape(instance_name)}", headers: headers, timeout: 10)
    data = parse_json(response.body)
    { success: response.success?, message: data['message'] }
  rescue StandardError => e
    Rails.logger.error "[Evolution API] Delete instance error: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'apikey' => api_key
    }
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end
end
