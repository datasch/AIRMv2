# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Run in a background thread on boot to ensure GOWA webhooks and Enterprise configs are synced
  Thread.new do
    sleep 5 # Allow Rails and GOWA network services to initialize
    if defined?(InstallationConfig) && ActiveRecord::Base.connection.table_exists?('installation_configs')
      # Permanently unlock enterprise plan and unlimited agent licenses
      [
        { name: 'INSTALLATION_PRICING_PLAN', value: 'enterprise' },
        { name: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: 999_999 },
        { name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: nil },
        { name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: nil },
        { name: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: nil }
      ].each do |item|
        config = InstallationConfig.find_or_initialize_by(name: item[:name])
        config.value = item[:value]
        config.locked = true
        config.save!
      end
    end

    if defined?(Channel::Api) && ActiveRecord::Base.connection.table_exists?('channel_api')
      service = Whatsapp::GowaService.new
      Channel::Api.find_each do |channel|
        next unless channel.webhook_url.to_s.include?('device_id=')

        uri = URI.parse(channel.webhook_url)
        query_params = CGI.parse(uri.query || '')
        dev_id = query_params['device_id']&.first
        next if dev_id.blank?

        inbox = channel.inbox
        account_id = channel.account_id
        inbox_id = inbox&.id

        gowa_webhook_target = "#{ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000')}/public/api/v1/gowa/webhook?account_id=#{account_id}&inbox_id=#{inbox_id}&device_id=#{CGI.escape(dev_id)}"
        service.configure_device_webhook(device_id: dev_id, webhook_url: gowa_webhook_target)

        user = channel.account&.administrators&.first || channel.account&.users&.first
        token = user&.access_token&.token
        service.configure_chatwoot(
          device_id: dev_id,
          account_id: account_id,
          inbox_id: inbox_id,
          api_token: token
        ) if token.present?
      end
    end
  rescue StandardError => e
    Rails.logger.warn "[GOWA Initializer] Auto-sync webhooks/enterprise error: #{e.message}"
  end
end
