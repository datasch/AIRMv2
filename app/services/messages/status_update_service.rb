class Messages::StatusUpdateService
  attr_reader :message, :status, :external_error, :source_id

  def initialize(message, status, external_error = nil, source_id = nil)
    @message = message
    @status = status.to_s.downcase.presence
    @external_error = external_error
    @source_id = source_id
  end

  def perform
    return false unless valid_status_transition?

    update_message_status
  end

  private

  def update_message_status
    attrs = {
      status: status,
      external_error: (status == 'failed' ? external_error : nil)
    }
    attrs[:source_id] = source_id if source_id.present?
    message.update!(attrs)
  end

  def valid_status_transition?
    return false unless Message.statuses.key?(status)

    # Don't allow changing from 'read' to 'delivered'
    return false if message.read? && status == 'delivered'

    true
  end
end
