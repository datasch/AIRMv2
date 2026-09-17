class ConversationBuilder
  pattr_initialize [:params!, :contact_inbox!]

  def perform
    look_up_exising_conversation || create_new_conversation
  end

  private

  def look_up_exising_conversation
    if @contact_inbox.inbox.lock_to_single_conversation?
      existing = @contact_inbox.conversations.last
      return existing if existing.present?

      return @contact_inbox.contact.conversations.where(inbox_id: @contact_inbox.inbox_id).order(created_at: :desc).first
    end

    # For WhatsApp, API, and SMS inboxes, prevent duplicate concurrent conversations with the same contact
    if @contact_inbox.inbox.channel_type.in?(%w[Channel::Whatsapp Channel::Api Channel::TwilioSms Channel::Sms Channel::Telegram])
      existing = @contact_inbox.conversations.where(status: [:open, :snoozed]).order(created_at: :desc).first
      return existing if existing.present?

      return @contact_inbox.contact.conversations.where(inbox_id: @contact_inbox.inbox_id, status: [:open, :snoozed]).order(created_at: :desc).first
    end

    nil
  end

  def create_new_conversation
    ::Conversation.create!(conversation_params)
  rescue ActiveRecord::RecordNotUnique => e
    if e.message.include?('index_conversations_on_account_id_and_display_id')
      account_id = @contact_inbox.inbox.account_id
      max_id = ::Conversation.where(account_id: account_id).maximum(:display_id).to_i
      ActiveRecord::Base.connection.execute("SELECT setval('conv_dpid_seq_#{account_id}', #{[max_id, 1].max}, true)")
      ::Conversation.create!(conversation_params)
    else
      raise e
    end
  end

  def conversation_params
    additional_attributes = params[:additional_attributes]&.permit! || {}
    custom_attributes = params[:custom_attributes]&.permit! || {}
    status = params[:status].present? ? { status: params[:status] } : {}

    # TODO: temporary fallback for the old bot status in conversation, we will remove after couple of releases
    # commenting this out to see if there are any errors, if not we can remove this in subsequent releases
    # status = { status: 'pending' } if status[:status] == 'bot'
    {
      account_id: @contact_inbox.inbox.account_id,
      inbox_id: @contact_inbox.inbox_id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      snoozed_until: params[:snoozed_until],
      assignee_id: params[:assignee_id],
      team_id: params[:team_id]
    }.merge(status)
  end
end
