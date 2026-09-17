# frozen_string_literal: true

class FixChannelApiWebhookUrls < ActiveRecord::Migration[7.0]
  def up
    evolution_base = ENV['EVOLUTION_API_URL'].presence || 'http://evolution-api:8080'

    Channel::Api.find_each do |channel|
      next if channel.webhook_url.blank?

      if channel.webhook_url.include?('sslip.io') && channel.webhook_url.include?('/chatwoot/webhook/')
        instance_part = channel.webhook_url.split('/chatwoot/webhook/').last
        new_url = "#{evolution_base.chomp('/')}/chatwoot/webhook/#{instance_part}"
        channel.update_columns(webhook_url: new_url)
      end
    end
  end

  def down
    # irreversible data migration
  end
end
