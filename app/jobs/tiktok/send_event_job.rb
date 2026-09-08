# frozen_string_literal: true

class Tiktok::SendEventJob < ApplicationJob
  queue_as :default

  def perform(event_name:, properties: {}, user_data: {}, event_id: nil)
    Tiktok::EventsApiService.new.track(
      event_name: event_name,
      properties: properties.deep_symbolize_keys,
      user_data: user_data.deep_symbolize_keys,
      event_id: event_id
    )
  rescue StandardError => e
    Rails.logger.error "[Tiktok::SendEventJob] Failed to execute job: #{e.message}"
  end
end
