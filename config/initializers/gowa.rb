# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Run in a background thread on boot to ensure GOWA webhooks are synced without blocking startup
  Thread.new do
    sleep 5 # Allow Rails and GOWA network services to initialize
    if defined?(Channel::Api) && ActiveRecord::Base.connection.table_exists?('channel_api')
      service = Whatsapp::GowaService.new
      Channel::Api.find_each do |channel|
        next unless channel.webhook_url.to_s.include?('device_id=')

        uri = URI.parse(channel.webhook_url)
        query_params = CGI.parse(uri.query || '')
        dev_id = query_params['device_id']&.first
        next if dev_id.blank?

        gowa_webhook_target = "#{ENV.fetch('CHATWOOT_INTERNAL_URL', 'http://rails:3000')}/public/api/v1/gowa/webhook?device_id=#{CGI.escape(dev_id)}"
        service.configure_device_webhook(device_id: dev_id, webhook_url: gowa_webhook_target)
      end
    end
  rescue StandardError => e
    Rails.logger.warn "[GOWA Initializer] Auto-sync webhooks error: #{e.message}"
  end
end
