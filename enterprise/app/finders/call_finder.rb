class CallFinder
  RESULTS_PER_PAGE = 25

  def initialize(current_user, current_account, params)
    @current_user = current_user
    @current_account = current_account
    @params = params
  end

  def perform
    sync_voip_call_logs_if_empty
    @calls = @current_account.calls
    filter_by_visibility
    filter_by_status
    filter_by_direction
    filter_by_inbox
    filter_by_agent
    filter_by_date_range

    { calls: paginated_calls, count: @calls.count }
  end

  private

  def sync_voip_call_logs_if_empty
    return if @current_account.calls.exists? || !@current_account.voip_call_logs.exists?

    default_inbox = @current_account.inboxes.first
    default_conv = @current_account.conversations.first
    default_contact = @current_account.contacts.first

    @current_account.voip_call_logs.find_each do |log|
      conv = if log.conversation_id.present?
               @current_account.conversations.find_by(id: log.conversation_id)
             elsif log.contact_id.present?
               @current_account.conversations.where(contact_id: log.contact_id).order(updated_at: :desc).first
             elsif log.phone_number.present?
               clean_num = log.phone_number.gsub(/[^\d+]/, '')
               matching_contact = @current_account.contacts.find_by(phone_number: clean_num)
               matching_contact&.conversations&.order(updated_at: :desc)&.first
             end

      conv ||= default_conv
      next if conv.blank?

      inbox = conv.inbox || default_inbox
      next if inbox.blank?

      contact = conv.contact || log.contact || default_contact
      next if contact.blank?

      agent_id = log.user_id.presence || @current_user&.id

      call_rec = @current_account.calls.find_or_initialize_by(provider: :voip, provider_call_id: log.call_id)
      call_rec.assign_attributes(
        inbox: inbox,
        conversation: conv,
        contact: contact,
        accepted_by_agent_id: agent_id,
        direction: :outgoing,
        status: log.status == 'completed' ? 'completed' : 'failed',
        duration_seconds: log.duration_seconds || 0,
        created_at: log.created_at || Time.current,
        started_at: log.created_at || Time.current,
        meta: {
          disposition: log.disposition,
          call_category: log.call_category,
          recording_url: log.recording_url
        }
      )
      call_rec.save
    end
  end

  # Admins and report managers see the whole account; everyone else only sees
  # calls they handled within conversations they can still access.
  def filter_by_visibility
    return if account_wide_access?

    @calls = @calls.where(accepted_by_agent_id: @current_user.id, conversation_id: accessible_conversations)
  end

  def accessible_conversations
    Conversations::PermissionFilterService.new(@current_account.conversations, @current_user, @current_account).perform.select(:id)
  end

  def account_wide_access?
    account_user = Current.account_user
    account_user&.administrator? || account_user&.custom_role&.permissions&.include?('report_manage')
  end

  def filter_by_status
    @calls = @calls.where(status: Call.status_from_display(@params[:status])) if @params[:status].present?
  end

  def filter_by_direction
    @calls = @calls.where(direction: Call.direction_from_label(@params[:direction])) if @params[:direction].present?
  end

  def filter_by_inbox
    @calls = @calls.where(inbox_id: @params[:inbox_id]) if @params[:inbox_id].present?
  end

  def filter_by_agent
    @calls = @calls.where(accepted_by_agent_id: @params[:agent_id]) if @params[:agent_id].present?
  end

  # since/until are unix timestamps, matching DateRangeHelper conventions.
  def filter_by_date_range
    return if @params[:since].blank? || @params[:until].blank?

    @calls = @calls.where(created_at: Time.zone.at(@params[:since].to_i)..Time.zone.at(@params[:until].to_i))
  end

  def paginated_calls
    @calls.includes(:contact, :conversation, :accepted_by_agent, inbox: :channel)
          .order(created_at: :desc)
          .page(@params[:page] || 1)
          .per(RESULTS_PER_PAGE)
  end
end
