# frozen_string_literal: true

class Campaigns::SendGowaMessageJob < ApplicationJob
  queue_as :low

  def perform(campaign_id:, contact_id:)
    campaign = Campaign.find_by(id: campaign_id)
    contact = Contact.find_by(id: contact_id)

    return if campaign.blank? || contact.blank? || contact.phone_number.blank?
    return if campaign.inbox.blank?

    content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
    return if content.blank?

    contact_inbox = find_or_create_contact_inbox(campaign.inbox, contact)
    return if contact_inbox.blank?

    conversation = find_or_create_conversation(campaign, contact, contact_inbox)
    return if conversation.blank?

    message_params = ActionController::Parameters.new({
      content: content,
      campaign_id: campaign.id,
      message_type: :outgoing,
      private: false
    })

    sender = campaign.sender || campaign.account.administrators.first
    message = Messages::MessageBuilder.new(sender, conversation, message_params).perform

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
    contact.contact_inboxes.find_by(inbox: inbox) ||
      ContactInboxBuilder.new(
        contact: contact,
        inbox: inbox,
        source_id: contact.phone_number.delete('+')
      ).perform
  end

  def find_or_create_conversation(campaign, contact, contact_inbox)
    # Prefer existing open conversation, or create a new one for this campaign
    conversation = contact_inbox.conversations.where(status: [:open, :pending]).last

    if conversation.blank?
      conversation = ::Conversation.create!(
        account: campaign.account,
        inbox: campaign.inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        campaign_id: campaign.id,
        status: :open
      )
    end

    conversation
  end
end
