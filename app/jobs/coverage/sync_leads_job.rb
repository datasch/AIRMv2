# frozen_string_literal: true

class Coverage::SyncLeadsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.find_each do |account|
      ::Coverage::SyncService.new(account: account).sync_from_datatable!
    rescue StandardError => e
      Rails.logger.error "[Coverage::SyncLeadsJob] Error syncing account #{account.id}: #{e.message}"
    end
  end
end
