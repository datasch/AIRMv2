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

    # Ignore WhatsApp group messages and status broadcasts to prevent automated bots/AI from messaging group members
    is_group = ActiveModel::Type::Boolean.new.cast(payload[:is_group]) ||
               payload[:from].to_s.include?('@g.us') ||
               payload[:chat_id].to_s.include?('@g.us') ||
               payload[:sender].to_s.include?('@g.us')
    return if is_group

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

    source_id = payload[:id].present? ? "WAID:#{payload[:id]}" : nil

    # Prevent duplicate message ingestion by source_id in this conversation
    if source_id.present? && conversation.messages.exists?(source_id: source_id)
      Rails.logger.info "[GOWA Webhook] Skipping duplicate message #{source_id} in Inbox #{inbox.id}"
      return
    end

    raw_body = payload[:body].presence || payload[:text].presence || payload[:caption].presence || ''
    contact_cards = extract_contact_cards(payload)

    if contact_cards.present?
      # Build structured, easily copyable text representation for sales agents & AI
      summaries = contact_cards.map do |card|
        phone_val = card[:phones].first.to_s.strip
        digits = phone_val.gsub(/\D/, '')
        wa_link = digits.present? ? "https://wa.me/#{digits}" : nil

        lines = ["👤 Contacto: #{card[:name]}"]
        lines << "📱 Teléfono: #{phone_val}" if phone_val.present?
        lines << "💬 WhatsApp: #{wa_link}" if wa_link.present?
        lines << "🏢 Empresa: #{card[:organization]}" if card[:organization].present?
        lines << "✉️ Correo: #{card[:email]}" if card[:email].present?
        lines.join("\n")
      end
      message_content = summaries.join("\n\n")
    else
      message_content = raw_body
    end

    message_params = ActionController::Parameters.new({
      content: message_content,
      message_type: :incoming,
      source_id: source_id
    })

    message = Messages::MessageBuilder.new(contact, conversation, message_params).perform

    if message.present?
      if contact_cards.present?
        attach_contacts_to_message(message, contact_cards)
      else
        attach_media_to_message(message, payload)
      end
    end

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
    media_url = payload[:media_url] || payload[:url] || payload[:file_url] ||
                payload[:image_url] || payload[:audio_url] || payload[:video_url] ||
                payload[:document_url] || payload[:file_path] || payload[:path] ||
                payload.dig(:media, :url) || payload.dig(:media, :path)
    return if media_url.blank?

    base_gowa_url = (ENV['GOWA_URL'] || 'http://gowa:3000').chomp('/')
    full_media_url = media_url.start_with?('http') ? media_url : "#{base_gowa_url}/#{media_url.delete_prefix('/')}"

    response = HTTParty.get(full_media_url, timeout: 20)
    unless response.success?
      Rails.logger.warn "[GOWA Webhook] Failed to fetch media from #{full_media_url} (HTTP #{response.code})"
      return
    end

    raw_ext = File.extname(media_url.to_s.split('?').first).downcase
    filename = payload[:filename].presence || File.basename(media_url.to_s.split('?').first).presence || "whatsapp_media_#{Time.current.to_i}#{raw_ext}"
    content_type = payload[:mime_type] || response.headers['content-type'] || 'application/octet-stream'

    # Normalize clean content_type (e.g. "audio/ogg; codecs=opus" -> "audio/ogg")
    clean_mime = content_type.to_s.split(';').first.strip.downcase

    # If filename is missing an extension, deduce it from clean_mime
    if File.extname(filename).blank?
      deduced_ext = case clean_mime
                    when 'application/pdf' then '.pdf'
                    when 'image/jpeg', 'image/jfif' then '.jpg'
                    when 'image/png' then '.png'
                    when 'image/webp' then '.webp'
                    when 'audio/ogg', 'audio/opus' then '.ogg'
                    when 'audio/mpeg', 'audio/mp3' then '.mp3'
                    when 'audio/mp4', 'audio/m4a' then '.m4a'
                    when 'video/mp4' then '.mp4'
                    else ''
                    end
      filename = "#{filename}#{deduced_ext}"
    end

    file_type = determine_file_type(clean_mime, filename)

    attachment = message.attachments.build(
      account_id: message.account_id,
      file_type: file_type
    )

    attachment.file.attach(
      io: StringIO.new(response.body),
      filename: filename,
      content_type: clean_mime.presence || 'application/octet-stream'
    )

    attachment.save!
    Rails.logger.info "[GOWA Webhook] Attached #{file_type} (#{filename}) to Message #{message.id}"
  rescue StandardError => e
    Rails.logger.warn "[GOWA Webhook] Failed to attach media: #{e.message}"
  end

  def determine_file_type(content_type, filename = nil)
    ext = File.extname(filename.to_s).downcase

    if content_type.to_s.start_with?('image/') || %w[.jpg .jpeg .png .gif .webp .jfif .bmp .svg].include?(ext)
      :image
    elsif content_type.to_s.start_with?('audio/') || %w[.ogg .mp3 .wav .m4a .aac .opus .oga].include?(ext)
      :audio
    elsif content_type.to_s.start_with?('video/') || %w[.mp4 .mov .avi .mkv .webm .3gp].include?(ext)
      :video
    else
      :file
    end
  end

  def extract_contact_cards(payload)
    cards = []

    # 1. Check direct vcard in payload (string or array)
    raw_vcards = Array(payload[:vcards] || payload[:vcard] || payload.dig(:message, :vcard) || payload.dig(:message, :vcards)).compact
    raw_vcards.each do |vcard_str|
      parsed = parse_vcard(vcard_str.to_s)
      cards << parsed if parsed.present?
    end

    # 2. Check contacts array / contact hash in payload
    contact_entries = Array(payload[:contacts] || payload[:contact] || payload.dig(:message, :contacts) || payload.dig(:message, :contact)).compact
    contact_entries.each do |entry|
      if entry.is_a?(Hash)
        vcard_text = entry[:vcard] || entry['vcard']
        if vcard_text.present?
          parsed = parse_vcard(vcard_text.to_s)
          if parsed.present?
            parsed[:name] = (entry[:displayName] || entry[:display_name] || entry[:name] || parsed[:name]).to_s.strip
            parsed[:phones] << entry[:phone] if entry[:phone].present?
            parsed[:phones].uniq!
            cards << parsed
          end
        else
          name = (entry[:displayName] || entry[:display_name] || entry[:name] || entry['displayName'] || entry['display_name'] || entry['name']).to_s.strip
          phones = Array(entry[:phones] || entry[:phone] || entry['phones'] || entry['phone']).map do |p|
            p.is_a?(Hash) ? (p[:phone] || p['phone']) : p.to_s
          end.compact
          if name.present? || phones.present?
            cards << {
              name: name.presence || 'Contacto',
              first_name: name.split(' ').first,
              last_name: name.split(' ')[1..]&.join(' '),
              phones: phones,
              email: entry[:email] || entry['email'],
              organization: entry[:organization] || entry[:org] || entry['organization'] || entry['org']
            }
          end
        end
      elsif entry.is_a?(String) && entry.include?('BEGIN:VCARD')
        parsed = parse_vcard(entry)
        cards << parsed if parsed.present?
      end
    end

    # 3. Check if body / text contains BEGIN:VCARD
    body_text = (payload[:body] || payload[:text] || '').to_s
    if body_text.include?('BEGIN:VCARD')
      body_text.scan(/BEGIN:VCARD.*?END:VCARD/m).each do |vcard_block|
        parsed = parse_vcard(vcard_block)
        cards << parsed if parsed.present?
      end
    end

    # 4. If body starts with "Contact: Name" and contains a phone or contact type
    if cards.blank? && (payload[:type].to_s.downcase.include?('contact') || body_text.start_with?('Contact:'))
      extracted_name = body_text.sub(/\AContact:\s*/i, '').lines.first.to_s.strip
      extracted_phone = body_text.scan(/(?:\+?\d{1,4}[\s-]?)?\(?\d{2,4}\)?[\s-]?\d{3,4}[\s-]?\d{3,4}/).first
      if extracted_name.present? || extracted_phone.present?
        cards << {
          name: extracted_name.presence || 'Contacto',
          first_name: extracted_name.split(' ').first,
          last_name: extracted_name.split(' ')[1..]&.join(' '),
          phones: [extracted_phone].compact,
          email: nil,
          organization: nil
        }
      end
    end

    cards.uniq { |c| [c[:name], c[:phones]&.first] }
  end

  def parse_vcard(vcard_str)
    return nil if vcard_str.blank?

    name = ''
    first_name = ''
    last_name = ''
    phones = []
    email = ''
    org = ''

    vcard_str.each_line do |line|
      clean_line = line.strip
      case clean_line
      when /\AFN:(.*)\z/i
        name = Regexp.last_match(1).to_s.strip
      when /\AN:([^;]*);?([^;]*)/i
        last_name = Regexp.last_match(1).to_s.strip
        first_name = Regexp.last_match(2).to_s.strip
      when /\ATEL[^:]*:(.*)\z/i
        raw_num = Regexp.last_match(1).to_s.strip
        waid = clean_line[/waid=(\d+)/i, 1]
        phones << (waid.present? ? "+#{waid}" : raw_num)
      when /\AEMAIL[^:]*:(.*)\z/i
        email = Regexp.last_match(1).to_s.strip
      when /\AORG:(.*)\z/i
        org = Regexp.last_match(1).to_s.strip.delete(';')
      end
    end

    name = "#{first_name} #{last_name}".strip if name.blank? && (first_name.present? || last_name.present?)
    first_name = name.split(' ').first if first_name.blank? && name.present?
    last_name = name.split(' ')[1..]&.join(' ') if last_name.blank? && name.present?

    return nil if name.blank? && phones.blank?

    {
      name: name.presence || phones.first || 'Contacto',
      first_name: first_name,
      last_name: last_name,
      phones: phones.uniq,
      email: email.presence,
      organization: org.presence
    }
  end

  def attach_contacts_to_message(message, contact_cards)
    contact_cards.each do |card|
      primary_phone = card[:phones].first || ''
      clean_digits = primary_phone.gsub(/\D/, '')
      formatted_phone = clean_digits.present? ? "+#{clean_digits}" : ''

      message.attachments.create!(
        account_id: message.account_id,
        file_type: :contact,
        fallback_title: formatted_phone.presence || primary_phone.presence || card[:name],
        meta: {
          firstName: card[:first_name],
          lastName: card[:last_name],
          name: card[:name],
          displayName: card[:name],
          phone: primary_phone,
          formattedPhone: formatted_phone,
          email: card[:email],
          organization: card[:organization]
        }.compact
      )
    end
    Rails.logger.info "[GOWA Webhook] Attached #{contact_cards.size} contact card(s) to Message #{message.id}"
  rescue StandardError => e
    Rails.logger.warn "[GOWA Webhook] Failed to attach contact card: #{e.message}"
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
