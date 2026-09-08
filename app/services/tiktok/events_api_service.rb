# frozen_string_literal: true

require 'digest'

class Tiktok::EventsApiService
  DEFAULT_PIXEL_ID = 'DAFLIVBC77U208ULDNIG'
  DEFAULT_ACCESS_TOKEN = '6b62d698036e2e18dadd63131ae0d074be873eb2'

  attr_reader :pixel_id, :access_token, :test_event_code

  def initialize(pixel_id: nil, access_token: nil, test_event_code: nil)
    @pixel_id = pixel_id.presence || ENV.fetch('TIKTOK_PIXEL_ID', DEFAULT_PIXEL_ID)
    @access_token = access_token.presence || ENV.fetch('TIKTOK_EVENTS_ACCESS_TOKEN', DEFAULT_ACCESS_TOKEN)
    @test_event_code = test_event_code.presence || ENV['TIKTOK_TEST_EVENT_CODE']
  end

  def track(event_name:, properties: {}, user_data: {}, event_id: nil)
    return false if pixel_id.blank? || access_token.blank?

    event_payload = build_event_payload(
      event_name: event_name,
      properties: properties,
      user_data: user_data,
      event_id: event_id
    )

    send_request([event_payload])
  end

  def track_view_content(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'ViewContent', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_search(query:, properties: {}, user_data: {}, event_id: nil)
    merged_properties = properties.merge(search_string: query)
    track(event_name: 'Search', properties: merged_properties, user_data: user_data, event_id: event_id)
  end

  def track_click_button(button_name:, properties: {}, user_data: {}, event_id: nil)
    merged_properties = properties.merge(content_name: button_name, status: 'clicked')
    track(event_name: 'ClickButton', properties: merged_properties, user_data: user_data, event_id: event_id)
  end

  def track_lead(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'Lead', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_add_to_cart(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'AddToCart', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_initiate_checkout(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'InitiateCheckout', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_complete_payment(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'CompletePayment', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_purchase(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'Purchase', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_complete_registration(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'CompleteRegistration', properties: properties, user_data: user_data, event_id: event_id)
  end

  def track_place_order(properties: {}, user_data: {}, event_id: nil)
    track(event_name: 'PlaceAnOrder', properties: properties, user_data: user_data, event_id: event_id)
  end

  private

  def api_endpoint
    api_version = GlobalConfigService.load('TIKTOK_API_VERSION', 'v1.3')
    "https://business-api.tiktok.com/open_api/#{api_version}/event/track/"
  end

  def build_event_payload(event_name:, properties:, user_data:, event_id:)
    now = Time.current
    timestamp = properties[:event_time].presence || now.to_i
    generated_id = event_id.presence || "tt_#{timestamp}_#{SecureRandom.hex(6)}"

    user = build_user_object(user_data)
    props = properties.except(:event_time).compact

    payload = {
      event: event_name,
      event_time: timestamp.to_i,
      event_id: generated_id,
      user: user,
      properties: props
    }

    payload[:page] = { url: props[:url] } if props[:url].present?
    payload
  end

  def build_user_object(user_data)
    user = {}
    user[:email] = sha256(user_data[:email]) if user_data[:email].present?
    user[:phone] = format_and_hash_phone(user_data[:phone]) if user_data[:phone].present?
    user[:external_id] = sha256(user_data[:external_id].to_s) if user_data[:external_id].present?
    user[:ip] = user_data[:ip] if user_data[:ip].present?
    user[:user_agent] = user_data[:user_agent] if user_data[:user_agent].present?
    user[:ttp] = user_data[:ttp] if user_data[:ttp].present?
    user[:ttclid] = user_data[:ttclid] if user_data[:ttclid].present?
    user
  end

  def send_request(events)
    payload = {
      event_source: 'web',
      event_source_id: pixel_id,
      data: events
    }
    payload[:test_event_code] = test_event_code if test_event_code.present?

    headers = {
      'Access-Token' => access_token,
      'Content-Type' => 'application/json'
    }

    response = HTTParty.post(
      api_endpoint,
      body: payload.to_json,
      headers: headers,
      timeout: 10
    )

    parse_response(response)
  rescue StandardError => e
    Rails.logger.error "[TikTok Events API] Error sending event: #{e.message}"
    { success: false, error: e.message }
  end

  def parse_response(response)
    if response.success?
      parsed = JSON.parse(response.body) rescue {}
      if parsed['code'].zero?
        { success: true, data: parsed['data'] }
      else
        Rails.logger.warn "[TikTok Events API] API Warning/Error code #{parsed['code']}: #{parsed['message']}"
        { success: false, code: parsed['code'], message: parsed['message'] }
      end
    else
      Rails.logger.error "[TikTok Events API] HTTP Error #{response.code}: #{response.body}"
      { success: false, http_status: response.code, body: response.body }
    end
  end

  def sha256(value)
    return nil if value.blank?

    str = value.to_s.strip.downcase
    # Avoid re-hashing if string is already 64 hexadecimal characters
    return str if str.match?(/\A[a-f0-9]{64}\z/)

    Digest::SHA256.hexdigest(str)
  end

  def format_and_hash_phone(raw_phone)
    return nil if raw_phone.blank?

    cleaned = raw_phone.to_s.strip
    # If already a SHA256 hex string, return as is
    return cleaned.downcase if cleaned.match?(/\A[a-f0-9]{64}\z/)

    # Remove formatting characters like spaces, dashes, parentheses
    digits_only = cleaned.gsub(/[^\d+]/, '')
    digits_only = "+#{digits_only}" unless digits_only.start_with?('+')

    Digest::SHA256.hexdigest(digits_only)
  end
end
