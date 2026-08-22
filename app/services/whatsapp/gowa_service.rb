class Whatsapp::GowaService
  attr_reader :base_url, :public_url

  def initialize(base_url: nil, public_url: nil)
    @base_url = (base_url || ENV['GOWA_URL'] || 'http://gowa:3000').chomp('/')
    @public_url = (public_url || ENV['GOWA_PUBLIC_URL'] || 'http://localhost:3030').chomp('/')
  end

  def status
    response = HTTParty.get("#{base_url}/devices", timeout: 5)
    return { online: false, error: 'Cannot connect to GOWA gateway' } unless response.success?

    data = parse_json(response.body)
    { online: true, devices: data['results'] || [] }
  rescue StandardError => e
    Rails.logger.error "[GOWA] Status error: #{e.message}"
    { online: false, error: e.message }
  end

  def create_device(device_id)
    payload = { device_id: device_id }
    response = HTTParty.post(
      "#{base_url}/devices",
      headers: { 'Content-Type' => 'application/json' },
      body: payload.to_json,
      timeout: 10
    )

    data = parse_json(response.body)
    return { success: true, device: data['results'] } if response.success?

    # If device already exists, treat as success
    if data['code'] == 'DEVICE_ALREADY_EXISTS' || response.code == 409
      return { success: true, device: { id: device_id } }
    end

    { success: false, error: data['message'] || 'Failed to create device' }
  rescue StandardError => e
    Rails.logger.error "[GOWA] Create device error: #{e.message}"
    { success: false, error: e.message }
  end

  def login_qr(device_id)
    # Ensure device exists first
    create_device(device_id)

    response = HTTParty.get("#{base_url}/app/login?device_id=#{CGI.escape(device_id)}", timeout: 15)
    data = parse_json(response.body)

    if response.success? && data['results'].present?
      raw_link = data['results']['qr_link'] || ''
      # Fetch the image internally from GOWA gateway and encode as base64 data URI to avoid browser cross-origin cookie / 431 header issues
      qr_data_uri = nil
      if raw_link.present?
        path = raw_link.start_with?('http') ? URI.parse(raw_link).path : "/#{raw_link.delete_prefix('/')}"
        begin
          img_response = HTTParty.get("#{base_url}#{path}", timeout: 5)
          if img_response.success?
            qr_data_uri = "data:image/png;base64,#{Base64.strict_encode64(img_response.body)}"
          end
        rescue StandardError => e
          Rails.logger.warn "[GOWA] Failed to fetch QR image bytes: #{e.message}"
        end
      end

      qr_link = qr_data_uri || if raw_link.start_with?('http')
                  uri = URI.parse(raw_link)
                  "#{public_url}#{uri.path}"
                else
                  "#{public_url}/#{raw_link.delete_prefix('/')}"
                end

      {
        success: true,
        device_id: device_id,
        qr_duration: data['results']['qr_duration'] || 30,
        qr_link: qr_link
      }
    else
      { success: false, error: data['message'] || 'Failed to generate QR code' }
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA] Login QR error: #{e.message}"
    { success: false, error: e.message }
  end

  def device_status(device_id)
    response = HTTParty.get("#{base_url}/devices/#{CGI.escape(device_id)}/status", timeout: 5)
    data = parse_json(response.body)

    if response.success? && data['results'].present?
      {
        success: true,
        device_id: device_id,
        is_connected: data['results']['is_connected'] == true,
        is_logged_in: data['results']['is_logged_in'] == true
      }
    else
      { success: false, error: data['message'] || 'Device not found' }
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA] Device status error: #{e.message}"
    { success: false, error: e.message }
  end

  def logout_device(device_id)
    response = HTTParty.post("#{base_url}/devices/#{CGI.escape(device_id)}/logout", timeout: 10)
    data = parse_json(response.body)

    { success: response.success?, message: data['message'] }
  rescue StandardError => e
    Rails.logger.error "[GOWA] Logout device error: #{e.message}"
    { success: false, error: e.message }
  end

  def configure_device_webhook(device_id:, webhook_url:, events: ['message', 'message.ack', 'message.reaction', 'message.edited', 'message.revoked'])
    payload = {
      webhook_url: webhook_url,
      webhook_events: events
    }

    response = HTTParty.patch(
      "#{base_url}/devices/#{CGI.escape(device_id)}/webhook",
      headers: { 'Content-Type' => 'application/json' },
      body: payload.to_json,
      timeout: 10
    )

    if response.success?
      Rails.logger.info "[GOWA] Successfully configured per-device webhook for #{device_id} -> #{webhook_url}"
      return { success: true }
    end

    # Fallback to POST /devices/:id/webhook if PATCH is not supported
    alt_response = HTTParty.post(
      "#{base_url}/devices/#{CGI.escape(device_id)}/webhook",
      headers: { 'Content-Type' => 'application/json' },
      body: payload.to_json,
      timeout: 10
    )

    { success: alt_response.success? }
  rescue StandardError => e
    Rails.logger.warn "[GOWA] Failed to configure webhook for device #{device_id}: #{e.message}"
    { success: false, error: e.message }
  end

  def configure_chatwoot(device_id:, account_id:, inbox_id:, api_token:)
    payload = {
      chatwoot_url: 'http://rails:3000',
      account_id: account_id.to_i,
      inbox_id: inbox_id.to_i,
      api_token: api_token
    }

    # Attempt PUT to per-device chatwoot config endpoint
    response = HTTParty.put(
      "#{base_url}/devices/#{CGI.escape(device_id)}/chatwoot/config",
      headers: { 'Content-Type' => 'application/json' },
      body: payload.to_json,
      timeout: 10
    )

    return { success: true } if response.success?

    # Fallback to POST /chatwoot/configs if available
    alt_payload = payload.merge(device_id: device_id)
    alt_response = HTTParty.post(
      "#{base_url}/chatwoot/configs",
      headers: { 'Content-Type' => 'application/json' },
      body: alt_payload.to_json,
      timeout: 10
    )

    { success: alt_response.success? }
  rescue StandardError => e
    Rails.logger.warn "[GOWA] Failed to configure chatwoot for device #{device_id}: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end
end
