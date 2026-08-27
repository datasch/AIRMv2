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

    Rails.logger.info "[GOWA Campaign #{campaign.id}] Processing #{contact_count} audience contacts"

    if contact_count.zero?
      Rails.logger.warn "[GOWA Campaign #{campaign.id}] No audience contacts with valid phone numbers found. Marking completed."
      campaign.completed!
      return
    end

    delay_counter = 0
    base_interval = campaign.trigger_rules&.dig('delay_interval').to_i
    base_interval = DEFAULT_DELAY_INTERVAL if base_interval <= 0

    contacts.find_each.with_index do |contact, index|
      # Progressive anti-ban jitter delay: base interval + random 1..4s between messages
      jitter = rand(1..4)
      send_delay = (index * base_interval) + jitter

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
    # 1. Check if direct file/CSV audience was provided
    direct_contacts = extract_direct_audience_contacts
    return direct_contacts if direct_contacts.present?

    # 2. Fallback to existing label-based audience
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

  def extract_direct_audience_contacts
    direct_entries = []

    if campaign.audience.is_a?(Array)
      campaign.audience.each do |aud|
        entry = aud.is_a?(Hash) ? aud.with_indifferent_access : {}
        if entry[:phone_number].present? || %w[Contact Direct File].include?(entry[:type].to_s)
          direct_entries << entry if entry[:phone_number].present?
        end
      end
    end

    if direct_entries.blank? && campaign.trigger_rules.is_a?(Hash) && campaign.trigger_rules['file_contacts'].is_a?(Array)
      direct_entries = campaign.trigger_rules['file_contacts'].map { |c| c.is_a?(Hash) ? c.with_indifferent_access : nil }.compact
    end

    return [] if direct_entries.blank?

    contact_ids = []

    direct_entries.each do |entry|
      raw_phone = entry[:phone_number].to_s.strip
      next if raw_phone.blank?

      clean_digits = raw_phone.gsub(/\D/, '')
      next if clean_digits.length < 7

      clean_phone = raw_phone.start_with?('+') ? "+#{clean_digits}" : "+#{clean_digits}"

      contact = campaign.account.contacts.find_by(phone_number: clean_phone) ||
                campaign.account.contacts.find_by(phone_number: clean_digits)

      name = entry[:name].presence || "Lead #{clean_digits.last(4)}"
      email = entry[:email].presence
      company = entry[:company_name].presence

      custom_attributes = (entry[:custom_attributes] || {}).with_indifferent_access
      custom_attributes['custom_attribute_1'] = entry[:custom_attribute_1] if entry[:custom_attribute_1].present?
      custom_attributes['custom_attribute_2'] = entry[:custom_attribute_2] if entry[:custom_attribute_2].present?

      if contact.blank?
        contact = campaign.account.contacts.create!(
          name: name,
          phone_number: clean_phone,
          email: email,
          company_name: company,
          custom_attributes: custom_attributes.presence || {}
        )
      else
        updates = {}
        updates[:name] = name if (contact.name.blank? || contact.name.start_with?('Lead ')) && name.present?
        updates[:email] = email if contact.email.blank? && email.present?
        updates[:company_name] = company if contact.company_name.blank? && company.present?
        updates[:custom_attributes] = contact.custom_attributes.merge(custom_attributes) if custom_attributes.present?
        contact.update!(updates) if updates.present?
      end

      contact_ids << contact.id if contact.present?
    rescue StandardError => e
      Rails.logger.error "[GOWA Campaign #{campaign.id}] Error registering contact for phone #{entry[:phone_number]}: #{e.message}"
    end

    campaign.account.contacts.where(id: contact_ids.uniq)
  end
end
