module Enterprise::Internal::CheckNewVersionsJob
  def perform
    update_plan_info
  end

  private

  def update_plan_info
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: 999_999)
    update_installation_config(key: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: nil)
    update_installation_config(key: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: nil)
    update_installation_config(key: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: nil)
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end
end
