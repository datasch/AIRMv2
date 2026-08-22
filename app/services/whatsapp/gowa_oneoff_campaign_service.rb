# frozen_string_literal: true

class Whatsapp::GowaOneoffCampaignService
  pattr_initialize [:campaign!]

  # Safety delay in seconds between message dispatches to prevent WhatsApp anti-spam rate limits
  DEFAULT_DELAY_INTERVAL = 5

  def perform
    validate_campaign!

    contacts = audience_contacts
    contact_count = contacts.count
    labels = extract_audience_labels

    Rails.logger.info "[GOWA Campaign #{campaign.id}] Processing #{contact_count} audience contacts for labels: #{labels.inspect}"

    if contact_count.zero?
      Rails.logger.warn "[GOWA Campaign #{campaign.id}] No audience contacts with valid phone numbers found for labels: #{labels.inspect}. Marking completed."
      campaign.completed!
      return
    end

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
      Campaigns::CompleteGowaCampaignJob.set(wait: (delay_counter + 10).seconds).perform_later(campaign.id)
    else
      campaign.completed!
    end

    Rails.logger.info "[GOWA Campaign #{campaign.id}] All #{contact_count} messages enqueued successfully with anti-ban delays"
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
    return [] if campaign.audience.blank?

    audience_label_ids = campaign.audience.map do |aud|
      aud = aud.with_indifferent_access if aud.is_a?(Hash)
      aud[:id] if aud.is_a?(Hash) && (aud[:type].to_s == 'Label' || aud['type'].to_s == 'Label')
    end.compact

    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def audience_contacts
    labels = extract_audience_labels
    return campaign.account.contacts.none if labels.blank?

    # Find contacts directly tagged with the audience labels
    tagged_contact_ids = campaign.account.contacts.tagged_with(labels, any: true).pluck(:id)

    # Also find contacts whose conversations are tagged with the audience labels
    conversation_contact_ids = campaign.account.conversations.tagged_with(labels, any: true).pluck(:contact_id)

    all_contact_ids = (tagged_contact_ids + conversation_contact_ids).compact.uniq

    campaign.account.contacts
            .where(id: all_contact_ids)
            .where.not(phone_number: [nil, ''])
  end
end
