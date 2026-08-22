class GowaLogoutJob < ApplicationJob
  queue_as :default

  def perform(device_id)
    return if device_id.blank?

    service = Whatsapp::GowaService.new
    result = service.logout_device(device_id)

    if result[:success]
      Rails.logger.info "[GOWA] Successfully logged out device #{device_id}"
    else
      Rails.logger.warn "[GOWA] Failed to logout device #{device_id}: #{result[:error] || result[:message]}"
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA] Logout job crashed for device #{device_id}: #{e.message}"
  end
end
