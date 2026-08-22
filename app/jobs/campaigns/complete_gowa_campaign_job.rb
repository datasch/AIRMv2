# frozen_string_literal: true

class Campaigns::CompleteGowaCampaignJob < ApplicationJob
  queue_as :low

  def perform(campaign_id)
    campaign = Campaign.find_by(id: campaign_id)
    return if campaign.blank? || campaign.completed?

    campaign.update!(
      campaign_status: :completed,
      completed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error "[GOWA Campaign #{campaign_id}] Failed to complete campaign: #{e.message}"
  end
end
