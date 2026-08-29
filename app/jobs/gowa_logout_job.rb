class GowaLogoutJob < ApplicationJob
  queue_as :default

  def perform(device_id)
    return if device_id.blank?

    if ENV['EVOLUTION_API_URL'].present?
      service = Whatsapp::EvolutionService.new
      service.logout_instance(device_id)
      service.delete_instance(device_id)
      Rails.logger.info "[WhatsApp] Logged out Evolution API instance #{device_id}"
      return
    end

    service = Whatsapp::GowaService.new
    result = service.logout_device(device_id)

    if result[:success]
      Rails.logger.info "[GOWA] Successfully logged out device #{device_id}"
    else
      Rails.logger.warn "[GOWA] Failed to logout device #{device_id}: #{result[:error] || result[:message]}"
    end
  rescue StandardError => e
    Rails.logger.error "[WhatsApp] Logout job crashed for device #{device_id}: #{e.message}"
  end
end
