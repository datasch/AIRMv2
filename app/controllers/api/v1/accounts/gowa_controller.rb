# frozen_string_literal: true

class Api::V1::Accounts::GowaController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_user!, :authenticate_access_token!, :validate_bot_access_token!, only: [:webhook]
  skip_before_action :current_account, :validate_token_api_access, only: [:webhook], raise: false
  skip_around_action :switch_locale_using_account_locale, only: [:webhook], raise: false
  skip_before_action :check_subscription, only: [:webhook], raise: false
  before_action :check_administrator_authorization, only: [:pair, :create_inbox, :disconnect]

  def status
    service = Whatsapp::GowaService.new
    device_id = params[:device_id]

    sync_all_device_webhooks

    if device_id.present?
      result = service.device_status(device_id)
      render json: result
    else
      result = service.status
      render json: result
    end
  end

  def pair
    account_id = Current.account.id
    device_id = params[:device_id].presence || "acc_#{account_id}_#{SecureRandom.hex(4)}"
    service = Whatsapp::GowaService.new
    result = service.login_qr(device_id)

    if result[:success]
      # Proactively configure the webhook for this device on GOWA gateway with account_id
      gowa_webhook_target = "#{ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000')}/public/api/v1/gowa/webhook?account_id=#{account_id}&device_id=#{CGI.escape(device_id)}"
      service.configure_device_webhook(
        device_id: device_id,
        webhook_url: gowa_webhook_target
      )
      render json: result.merge(device_id: device_id)
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def create_inbox
    account_id = Current.account.id
    name = params[:name].presence || 'WhatsApp Web (GOWA)'
    device_id = params[:device_id].presence || "acc_#{account_id}_#{SecureRandom.hex(4)}"
    webhook_url = "#{ENV.fetch('GOWA_URL', 'http://gowa:3000')}/chatwoot/webhook?device_id=#{CGI.escape(device_id)}"

    ActiveRecord::Base.transaction do
      channel = Channel::Api.create!(
        account: Current.account,
        webhook_url: webhook_url
      )

      inbox = Current.account.inboxes.create!(
        name: name,
        channel: channel
      )

      # Automatically assign the creating user if they are an agent/admin
      if Current.user.present? && Current.account_user.present?
        inbox.inbox_members.create!(user: Current.user)
      end

      # Automatically configure GOWA per-device webhook for deterministic multi-account & multi-inbox routing
      service = Whatsapp::GowaService.new
      gowa_webhook_target = "#{ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000')}/public/api/v1/gowa/webhook?account_id=#{account_id}&inbox_id=#{inbox.id}&device_id=#{CGI.escape(device_id)}"
      service.configure_device_webhook(
        device_id: device_id,
        webhook_url: gowa_webhook_target
      )

      render json: {
        success: true,
        inbox_id: inbox.id,
        name: inbox.name,
        channel_type: 'Channel::Api',
        device_id: device_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA] Create inbox error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def disconnect
    device_id = params[:device_id]
    return render json: { success: false, error: 'device_id is required' }, status: :bad_request if device_id.blank?

    service = Whatsapp::GowaService.new
    result = service.logout_device(device_id)
    render json: result
  end

  def webhook
    event = params[:event] || params[:type]
    device_id = params[:device_id] || params.dig(:payload, :device_id)

    # Healthcheck / ping response
    return render json: { success: true, message: 'GOWA webhook active' } if event == 'ping' || request.get?

    case event
    when 'message'
      handle_incoming_message(device_id)
    when 'message.ack'
      handle_message_ack(device_id)
    end

    render json: { success: true }
  rescue StandardError => e
    Rails.logger.error "[GOWA Webhook] Processing error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render json: { success: false, error: e.message }, status: :ok
  end

  private

  def handle_incoming_message(device_id)
    payload = params[:payload] || params
    is_from_me = ActiveModel::Type::Boolean.new.cast(payload[:is_from_me])

    # Avoid processing our own outgoing messages sent via WhatsApp
    return if is_from_me

    inbox = find_inbox_by_device(device_id)
    if inbox.blank?
      Rails.logger.warn "[GOWA Webhook] No matching inbox found for device #{device_id}"
      return
    end

    account = inbox.account
    return if account.blank?

    sender_jid = (payload[:from] || payload[:chat_id] || payload[:sender]).to_s
    return if sender_jid.blank? || sender_jid.include?('status@broadcast')

    clean_phone = sender_jid.split('@').first.gsub(/\D/, '')
    return if clean_phone.blank?

    sender_name = payload[:from_name].presence || payload[:push_name].presence || "+#{clean_phone}"

    # Find or create Contact in the account that owns this inbox
    contact = account.contacts.find_by(phone_number: "+#{clean_phone}") ||
              account.contacts.find_by(phone_number: clean_phone)

    if contact.blank?
      contact = account.contacts.create!(
        name: sender_name,
        phone_number: "+#{clean_phone}"
      )
    elsif contact.name.blank? || contact.name == "+#{clean_phone}"
      contact.update(name: sender_name) if sender_name.present? && sender_name != "+#{clean_phone}"
    end

    # Find or create ContactInbox for this specific inbox
    contact_inbox = contact.contact_inboxes.find_by(inbox: inbox) ||
                    ContactInboxBuilder.new(
                      contact: contact,
                      inbox: inbox,
                      source_id: clean_phone
                    ).perform

    # Find or create active Conversation in this specific inbox
    conversation = contact_inbox.conversations.where(status: [:open, :pending]).last
    if conversation.blank?
      conversation = ::Conversation.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        status: :pending
      )
    end

    message_content = payload[:body].presence || payload[:text].presence || payload[:caption].presence || ''
    source_id = payload[:id].present? ? "WAID:#{payload[:id]}" : nil

    # Prevent duplicate message ingestion by source_id in this conversation
    if source_id.present? && conversation.messages.exists?(source_id: source_id)
      Rails.logger.info "[GOWA Webhook] Skipping duplicate message #{source_id} in Inbox #{inbox.id}"
      return
    end

    message_params = ActionController::Parameters.new({
      content: message_content,
      message_type: :incoming,
      source_id: source_id
    })

    message = Messages::MessageBuilder.new(contact, conversation, message_params).perform
    attach_media_to_message(message, payload) if message.present?

    Rails.logger.info "[GOWA Webhook] Synced incoming message #{message&.id} in Account #{account.id} -> Inbox #{inbox.id} (#{inbox.name}) from #{contact.phone_number}"
  end

  def handle_message_ack(device_id)
    # Optional status acknowledgment handling
  end

  def find_inbox_by_device(device_id)
    # 1. Direct match by inbox_id if present in webhook query params
    if params[:inbox_id].present?
      inbox = Inbox.find_by(id: params[:inbox_id])
      return inbox if inbox.present?
    end

    # 2. Match by device_id in Channel::Api webhook_url
    if device_id.present?
      channel = Channel::Api.where('webhook_url LIKE ?', "%device_id=#{device_id}%").first ||
                Channel::Api.where('webhook_url LIKE ?', "%#{device_id}%").first
      return channel.inbox if channel&.inbox.present?

      # 3. Match by acc_{account_id}_ prefix in device_id
      if device_id =~ /\Aacc_(\d+)_/
        account = Account.find_by(id: ::Regexp.last_match(1))
        inbox = account&.inboxes&.where(channel_type: 'Channel::Api')&.first
        return inbox if inbox.present?
      end
    end

    # 4. Match by account_id in webhook query params
    if params[:account_id].present?
      account = Account.find_by(id: params[:account_id])
      inbox = account&.inboxes&.where(channel_type: 'Channel::Api')&.first
      return inbox if inbox.present?
    end

    # 5. Strict multi-tenant isolation: Never fallback across accounts!
    nil
  end

  def attach_media_to_message(message, payload)
    media_url = payload[:media_url] || payload[:url]
    return if media_url.blank?

    base_gowa_url = (ENV['GOWA_URL'] || 'http://gowa:3000').chomp('/')
    full_media_url = media_url.start_with?('http') ? media_url : "#{base_gowa_url}/#{media_url.delete_prefix('/')}"

    response = HTTParty.get(full_media_url, timeout: 15)
    return unless response.success?

    filename = payload[:filename].presence || "whatsapp_media_#{Time.current.to_i}"
    content_type = payload[:mime_type] || response.headers['content-type'] || 'application/octet-stream'

    attachment = message.attachments.build(
      account_id: message.account_id,
      file_type: determine_file_type(content_type)
    )

    attachment.file.attach(
      io: StringIO.new(response.body),
      filename: filename,
      content_type: content_type
    )

    attachment.save!
  rescue StandardError => e
    Rails.logger.warn "[GOWA Webhook] Failed to attach media: #{e.message}"
  end

  def determine_file_type(content_type)
    case content_type
    when %r{^image/} then :image
    when %r{^audio/} then :audio
    when %r{^video/} then :video
    else :file
    end
  end

  def sync_all_device_webhooks
    service = Whatsapp::GowaService.new
    Channel::Api.find_each do |channel|
      next unless channel.webhook_url.to_s.include?('device_id=')

      inbox = channel.inbox
      next if inbox.blank?

      uri = URI.parse(channel.webhook_url)
      query_params = CGI.parse(uri.query || '')
      dev_id = query_params['device_id']&.first
      next if dev_id.blank?

      account_id = channel.account_id
      inbox_id = inbox.id

      gowa_webhook_target = "#{ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000')}/public/api/v1/gowa/webhook?account_id=#{account_id}&inbox_id=#{inbox_id}&device_id=#{CGI.escape(dev_id)}"
      service.configure_device_webhook(device_id: dev_id, webhook_url: gowa_webhook_target)
    end
  rescue StandardError => e
    Rails.logger.warn "[GOWA] sync_all_device_webhooks error: #{e.message}"
  end

  def check_administrator_authorization
    authorize :inbox, :create?
  end
end
