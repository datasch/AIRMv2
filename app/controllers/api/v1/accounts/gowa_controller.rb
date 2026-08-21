class Api::V1::Accounts::GowaController < Api::V1::Accounts::BaseController
  before_action :check_administrator_authorization, only: [:pair, :create_inbox, :disconnect]

  def status
    service = Whatsapp::GowaService.new
    device_id = params[:device_id]

    if device_id.present?
      result = service.device_status(device_id)
      render json: result
    else
      result = service.status
      render json: result
    end
  end

  def pair
    device_id = params[:device_id].presence || "acc_#{Current.account.id}_#{SecureRandom.hex(4)}"
    service = Whatsapp::GowaService.new
    result = service.login_qr(device_id)

    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def create_inbox
    name = params[:name].presence || 'WhatsApp Web (GOWA)'
    device_id = params[:device_id].presence || "acc_#{Current.account.id}_default"
    webhook_url = "#{ENV.fetch('GOWA_URL', 'http://gowa:3000')}/chatwoot/webhook"

    ActiveRecord::Base.transaction do
      channel = Channel::Api.create!(
        account: Current.account,
        webhook_url: webhook_url
      )

      inbox = Current.account.inboxes.create!(
        name: name,
        channel: channel
      )

      # Automatically assign the creating user if they are an agent/admin
      if Current.user.present? && Current.account_user.present?
        inbox.inbox_members.create!(user: Current.user)
      end

      render json: {
        success: true,
        inbox_id: inbox.id,
        name: inbox.name,
        channel_type: 'Channel::Api',
        device_id: device_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "[GOWA] Create inbox error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def disconnect
    device_id = params[:device_id]
    return render json: { success: false, error: 'device_id is required' }, status: :bad_request if device_id.blank?

    service = Whatsapp::GowaService.new
    result = service.logout_device(device_id)
    render json: result
  end

  private

  def check_administrator_authorization
    authorize :inbox, :create?
  end
end
