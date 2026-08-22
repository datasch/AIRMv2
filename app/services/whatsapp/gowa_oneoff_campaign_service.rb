# frozen_string_literal: true

class Whatsapp::GowaOneoffCampaignService
  pattr_initialize [:campaign!]

  # Safety delay in seconds between message dispatches to prevent WhatsApp anti-spam rate limits
  DEFAULT_DELAY_INTERVAL = 5

  def perform
    validate_campaign!

    audience_labels = extract_audience_labels
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true).where.not(phone_number: [nil, ''])

    Rails.logger.info "[GOWA Campaign #{campaign.id}] Processing #{contacts.count} audience contacts"

    delay_counter = 0

    contacts.find_each.with_index do |contact, index|
      # Progressive anti-ban jitter delay: base 5s + random 1..3s between messages
      jitter = rand(1..3)
      send_delay = (index * DEFAULT_DELAY_INTERVAL) + jitter

      if defined?(CampaignRecipient)
        campaign.campaign_recipients.find_or_create_by!(contact: contact) do |recipient|
          recipient.account = campaign.account
          recipient.inbox = campaign.inbox
          recipient.status = :queued
        end
      end

      Campaigns::SendGowaMessageJob.set(wait: send_delay.seconds).perform_later(
        campaign_id: campaign.id,
        contact_id: contact.id
      )

      delay_counter = send_delay
    end

    # Schedule campaign completion mark after all jobs have been scheduled
    if delay_counter > 0
      campaign.update!(campaign_status: :processing, started_at: Time.current)
      # Auto-complete after total wait time plus 10 seconds buffer
      campaign.class.delay_for((delay_counter + 10).seconds).where(id: campaign.id).update_all(
        campaign_status: Campaign.campaign_statuses[:completed],
        completed_at: Time.current
      )
    else
      campaign.completed!
    end

    Rails.logger.info "[GOWA Campaign #{campaign.id}] All messages enqueued successfully with anti-ban delays"
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign!
    raise "Invalid campaign #{campaign.id}" unless gowa_campaign? && campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?
  end

  def gowa_campaign?
    inbox.inbox_type == 'API' || inbox.channel_type == 'Channel::Api'
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end
end
