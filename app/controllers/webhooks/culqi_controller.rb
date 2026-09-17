# frozen_string_literal: true

class Webhooks::CulqiController < ActionController::API
  before_action :verify_webhook_authenticity!

  PAID_EVENTS = %w[order.status.paid charge.create charge.succeeded subscription.charged].freeze

  def process_payload
    payload_hash = parse_payload

    render json: { success: true, message: 'Evento ignorado' }, status: :ok and return if unprocessable_event?(payload_hash)

    result = Culqi::OnboardingService.new(payload_hash).perform
    render_result(result)
  end

  private

  def parse_payload
    JSON.parse(request.body.read)
  rescue JSON::ParserError
    params.to_unsafe_hash
  end

  def unprocessable_event?(payload_hash)
    event_type = payload_hash['type'] || payload_hash['object']
    event_type.present? && PAID_EVENTS.exclude?(event_type)
  end

  def render_result(result)
    if result[:success]
      render json: {
        success: true,
        account_id: result[:account].id,
        user_id: result[:user].id,
        email: result[:user].email,
        plan: result[:plan],
        activation_url: result[:activation_url]
      }, status: :ok
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  def verify_webhook_authenticity!
    expected_secret = ENV['CULQI_WEBHOOK_SECRET'].presence || ENV['CULQI_SECRET_KEY'].presence
    return if expected_secret.blank? || local_request?

    provided_token = extract_provided_token
    return if provided_token.present? && [expected_secret, ENV.fetch('CULQI_WEBHOOK_SECRET', nil)].include?(provided_token)

    Rails.logger.warn("[Culqi Webhook] Intento no autorizado desde IP: #{request.remote_ip}")
    render json: { error: 'No autorizado' }, status: :unauthorized
  end

  def extract_provided_token
    auth_header = request.headers['Authorization'] || request.headers['X-Culqi-Secret'] || request.headers['X-Webhook-Token']
    token_param = params[:token] || params[:webhook_secret]
    auth_header.to_s.sub(/^Bearer\s+/i, '').strip.presence || token_param.to_s.strip.presence
  end

  def local_request?
    Rails.env.development? || Rails.env.test? || request.remote_ip.in?(['127.0.0.1', '::1'])
  end
end
