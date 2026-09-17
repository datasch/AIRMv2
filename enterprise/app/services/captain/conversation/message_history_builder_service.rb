class Captain::Conversation::MessageHistoryBuilderService
  RESOLUTION_MARKER = '<conversation_boundary status="resolved" />'.freeze

  DEFAULT_HISTORY_LIMIT = ENV.fetch('CAPTAIN_CONVERSATION_HISTORY_LIMIT', 25).to_i

  pattr_initialize [:conversation!, [:limit]]

  def perform
    conversation_messages_for_context.filter_map do |message|
      message_hash = message_hash_for_context(message)
      next if message_hash.blank?

      message_hash[:agent_name] = message.additional_attributes['agent_name'] if message.additional_attributes&.dig('agent_name').present?
      message_hash
    end
  end

  private

  def effective_limit
    @limit.presence || DEFAULT_HISTORY_LIMIT
  end

  def conversation_messages_for_context
    conversation.messages
                .includes(attachments: { file_attachment: :blob })
                .where(private: false, message_type: [:incoming, :outgoing, :activity])
                .reorder(created_at: :desc, id: :desc)
                .limit(effective_limit)
                .reverse
  end

  def message_hash_for_context(message)
    return activity_message_hash(message) if message.message_type == 'activity'

    content = prepare_multimodal_message_content(message)
    return if content.blank?

    {
      content: content,
      role: determine_role(message)
    }
  end

  def activity_message_hash(message)
    activity = message.content_attributes.to_h['activity'].to_h
    return unless activity['type'] == 'conversation_status_changed' && activity['status'] == 'resolved'

    {
      content: RESOLUTION_MARKER,
      role: 'assistant'
    }
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'user' : 'assistant'
  end

  def prepare_multimodal_message_content(message)
    if message.outgoing? && message.sender_type == 'Captain::Assistant' && !message.deleted
      message_attributes = message.additional_attributes.to_h
      response_parts_attribute = Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY
      if message_attributes.key?(response_parts_attribute)
        return Captain::Assistant::ResponseParts.new(message_attributes[response_parts_attribute]).plain_text.presence
      end
    end

    Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  end
end
