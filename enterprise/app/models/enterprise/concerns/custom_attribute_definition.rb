module Enterprise::Concerns::CustomAttributeDefinition
  extend ActiveSupport::Concern

  included do
    after_destroy :cleanup_conversation_required_attributes
  end

  private

  def cleanup_conversation_required_attributes
    return if account.blank?
    return unless conversation_attribute? && account.conversation_required_attributes&.include?(attribute_key)

    account.conversation_required_attributes = account.conversation_required_attributes - [attribute_key]
    account.save!
  end
end
