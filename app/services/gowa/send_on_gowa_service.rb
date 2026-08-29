# frozen_string_literal: true

class Gowa::SendOnGowaService
  pattr_initialize [:message!]

  def perform
    return unless outgoing_message?

    phone = contact_phone_number
    if phone.blank?
      return mark_failed('Contact has no phone number')
    end

    dev_id = device_id
    if dev_id.blank?
      return mark_failed('No device_id found in inbox webhook_url')
    end

    if message.attachments.any?
      send_attachments(phone, dev_id)
    elsif message.content.present?
      send_text(phone, dev_id, message.content)
    end
  end

  private

  def outgoing_message?
    message.outgoing? || message.template?
  end

  def conversation
    @conversation ||= message.conversation
  end

  def inbox
    @inbox ||= conversation.inbox
  end

  def channel
    @channel ||= inbox.channel
  end

  def contact
    @contact ||= conversation.contact
  end

  def gowa_base_url
    ENV.fetch('GOWA_URL', 'http://gowa:3000').chomp('/')
  end

  def device_id
    return @device_id if defined?(@device_id)

    webhook_url = channel.webhook_url.to_s
    if webhook_url.include?('device_id=')
      uri = URI.parse(webhook_url)
      params = CGI.parse(uri.query || '')
      @device_id = params['device_id']&.first
    end
    @device_id
  end

  def contact_phone_number
    phone = contact.phone_number.to_s.gsub(/[^\d]/, '')
    phone.presence
  end

  def send_text(phone, dev_id, text)
    payload = { receiver: phone, message: { text: text } }

    response = post_to_gowa('/send/message', payload, dev_id)

    if response&.success?
      update_source_id(response)
      Rails.logger.info "[GOWA Send] Text sent to #{phone} via device #{dev_id} (Message #{message.id})"
    else
      error = "#{response&.code} #{response&.body&.to_s&.truncate(200)}"
      mark_failed("GOWA API error: #{error}")
    end
  rescue StandardError => e
    mark_failed("GOWA send failed: #{e.message}")
  end

  def send_attachments(phone, dev_id)
    message.attachments.each_with_index do |attachment, index|
      # Include text caption with the first attachment only
      caption = index.zero? ? message.content.to_s : ''
      send_single_attachment(phone, dev_id, attachment, caption)
    end
  end

  def send_single_attachment(phone, dev_id, attachment, caption)
    file_url = attachment_url(attachment)
    endpoint, payload = build_attachment_payload(attachment, phone, file_url, caption)

    response = post_to_gowa(endpoint, payload, dev_id)

    if response&.success?
      update_source_id(response) if message.source_id.blank?
      Rails.logger.info "[GOWA Send] Attachment sent to #{phone} via device #{dev_id} (#{attachment.file_type})"
    else
      Rails.logger.warn "[GOWA Send] Attachment failed: #{response&.code} #{response&.body&.to_s&.truncate(200)}"
    end
  rescue StandardError => e
    Rails.logger.warn "[GOWA Send] Attachment error: #{e.message}"
  end

  def build_attachment_payload(attachment, phone, file_url, caption)
    case attachment.file_type
    when 'image'
      ['/send/image', { receiver: phone, image_url: file_url, caption: caption }]
    when 'video'
      ['/send/video', { receiver: phone, video_url: file_url, caption: caption }]
    when 'audio'
      ['/send/audio', { receiver: phone, audio_url: file_url }]
    else
      ['/send/file', { receiver: phone, document_url: file_url, caption: caption }]
    end
  end

  def attachment_url(attachment)
    if attachment.external_url.present?
      attachment.external_url
    else
      internal_url = ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000').chomp('/')
      "#{internal_url}#{Rails.application.routes.url_helpers.rails_blob_path(attachment.file, only_path: true)}"
    end
  end

  def post_to_gowa(endpoint, payload, dev_id)
    headers = {
      'Content-Type' => 'application/json',
      'X-Device-Id' => dev_id
    }

    HTTParty.post(
      "#{gowa_base_url}#{endpoint}",
      headers: headers,
      body: payload.to_json,
      timeout: 30
    )
  end

  def update_source_id(response)
    parsed = JSON.parse(response.body) rescue {}
    source_id = parsed.dig('results', 'message_id') ||
                parsed.dig('results', 'id') ||
                parsed['message_id'] ||
                parsed['id']
    message.update!(source_id: "GOWA:#{source_id}") if source_id.present?
  rescue StandardError => e
    Rails.logger.warn "[GOWA Send] Failed to update source_id: #{e.message}"
  end

  def mark_failed(error_message)
    Rails.logger.error "[GOWA Send] #{error_message} (Message #{message.id})"
    Messages::StatusUpdateService.new(message, 'failed', error_message).perform
  end
end
