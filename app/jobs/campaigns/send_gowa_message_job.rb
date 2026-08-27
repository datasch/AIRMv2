# frozen_string_literal: true

class Campaigns::SendGowaMessageJob < ApplicationJob
  queue_as :low

  def perform(campaign_id:, contact_id:)
    campaign = Campaign.find_by(id: campaign_id)
    contact = Contact.find_by(id: contact_id)

    if campaign.blank? || contact.blank? || contact.phone_number.blank?
      Rails.logger.warn "[GOWA Campaign #{campaign_id}] Skipping send: campaign or contact missing / no phone number"
      return
    end

    if campaign.inbox.blank?
      Rails.logger.warn "[GOWA Campaign #{campaign_id}] Skipping send: inbox not found"
      return
    end

    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    if content.blank?
      Rails.logger.warn "[GOWA Campaign #{campaign_id}] Skipping contact #{contact.id}: message content is blank after Liquid rendering"
      return
    end

    contact_inbox = find_or_create_contact_inbox(campaign.inbox, contact)
    if contact_inbox.blank?
      Rails.logger.warn "[GOWA Campaign #{campaign_id}] Failed to find or create contact_inbox for contact #{contact.id}"
      return
    end

    conversation = find_or_create_conversation(campaign, contact, contact_inbox)
    if conversation.blank?
      Rails.logger.warn "[GOWA Campaign #{campaign_id}] Failed to find or create conversation for contact #{contact.id}"
      return
    end

    message_params = ActionController::Parameters.new({
      content: content,
      campaign_id: campaign.id,
      message_type: :outgoing,
      private: false
    })

    sender = campaign.sender || campaign.account.administrators.first
    message = Messages::MessageBuilder.new(sender, conversation, message_params).perform

    Rails.logger.info "[GOWA Campaign #{campaign_id}] Successfully dispatched message #{message&.id} to #{contact.phone_number} (Conversation #{conversation.id})"

    if defined?(CampaignRecipient)
      recipient = campaign.campaign_recipients.find_by(contact: contact)
      recipient&.mark_sent!(message&.id&.to_s || SecureRandom.uuid)
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA Campaign #{campaign_id}] Failed sending to contact #{contact_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

    if defined?(CampaignRecipient)
      recipient = campaign.campaign_recipients.find_by(contact: contact)
      recipient&.mark_failed!(message: e.message)
    end
  end

  private

  def find_or_create_contact_inbox(inbox, contact)
    clean_phone = contact.phone_number.to_s.gsub(/\D/, '')
    contact.contact_inboxes.find_by(inbox: inbox) ||
      ContactInboxBuilder.new(
        contact: contact,
        inbox: inbox,
        source_id: clean_phone.presence || contact.phone_number.delete('+')
      ).perform
  end

  def find_or_create_conversation(campaign, contact, contact_inbox)
    conversation = contact_inbox.conversations.where(status: [:open, :pending]).last
    target_team = campaign.target_team

    if conversation.blank?
      conversation = ::Conversation.create!(
        account: campaign.account,
        inbox: campaign.inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        campaign_id: campaign.id,
        team_id: target_team&.id,
        status: :open
      )
    elsif target_team.present? && conversation.team_id.blank?
      conversation.update!(team_id: target_team.id)
    end

    conversation
  end
end
