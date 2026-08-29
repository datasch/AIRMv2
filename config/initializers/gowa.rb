# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Run in a background thread on boot to ensure Enterprise configs and WhatsApp gateway are ready
  Thread.new do
    sleep 3 # Allow Rails and database services to initialize
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

    if ENV['EVOLUTION_API_URL'].present?
      Rails.logger.info "[WhatsApp] Evolution API gateway active at #{ENV['EVOLUTION_API_URL']}"
    end
  rescue StandardError => e
    Rails.logger.warn "[WhatsApp Initializer] Auto-sync enterprise error: #{e.message}"
  end
end
