# TODO: lets use HTTParty instead of RestClient
class ChatwootHub
  DEFAULT_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  def self.base_url
    DEFAULT_BASE_URL
  end

  def self.ping_url
    "#{base_url}/ping"
  end

  def self.registration_url
    "#{base_url}/instances"
  end

  def self.push_notification_url
    "#{base_url}/send_push"
  end

  def self.events_url
    "#{base_url}/events"
  end

  def self.billing_base_url
    "#{base_url}/billing"
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    'https://giantucchi.com'
  end

  def self.pricing_plan
    'enterprise'
  end

  def self.pricing_plan_quantity
    999_999
  end

  def self.support_config
    {
      support_website_token: nil,
      support_script_url: nil,
      support_identifier_hash: nil
    }
  end

  def self.instance_config
    {
      installation_identifier: installation_identifier,
      installation_version: Chatwoot.config[:version],
      installation_host: URI.parse(ENV.fetch('FRONTEND_URL', '')).host,
      installation_env: ENV.fetch('INSTALLATION_ENV', ''),
      edition: 'enterprise'
    }
  end

  def self.instance_metrics
    {}
  end

  def self.fetch_count(model)
    0
  end

  def self.sync_with_hub
    {
      'plan' => 'enterprise',
      'plan_quantity' => 999_999,
      'version' => Chatwoot.config[:version],
      'chatwoot_support_website_token' => nil,
      'chatwoot_support_identifier_hash' => nil,
      'chatwoot_support_script_url' => nil
    }
  end

  def self.register_instance(company_name, owner_name, owner_email)
    true
  end

  def self.send_push(fcm_options)
    send_push_with_response(fcm_options)
  rescue *ExceptionList::REST_CLIENT_EXCEPTIONS => e
    Rails.logger.error "Exception: #{e.message}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  def self.send_push_with_response(fcm_options)
    info = { fcm_options: fcm_options }
    RestClient.post(push_notification_url, info.merge(instance_config).to_json, { content_type: :json, accept: :json })
  end

  def self.emit_event(event_name, event_data)
    true
  end
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')
