class LandingController < ActionController::Base
  include SwitchLocale
  layout 'landing'

  skip_before_action :verify_authenticity_token, only: [:track_tiktok_event]
  before_action :set_shared_variables

  def index; end

  def terms; end

  def privacy; end

  def status; end

  def devoluciones; end

  def track_tiktok_event
    event_name = params[:event_name].presence || 'ViewContent'
    event_id = params[:event_id].presence

    user_params = (params[:user] || {}).permit(:email, :phone, :external_id, :ttclid, :ttp).to_h
    props = (params[:properties] || {}).permit!.to_h

    # Enrich with server context
    user_params[:ip] = request.remote_ip
    user_params[:user_agent] = request.user_agent
    user_params[:ttp] ||= cookies['_ttp']
    user_params[:ttclid] ||= params[:ttclid] || cookies['ttclid']
    props[:url] ||= request.referer || request.original_url

    Tiktok::SendEventJob.perform_later(
      event_name: event_name,
      properties: props,
      user_data: user_params,
      event_id: event_id
    )

    render json: { success: true, event_id: event_id, status: 'enqueued' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "[TikTok Tracking Endpoint] Error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def libro_reclamaciones
    @claim = ConsumerClaim.new
  end

  def create_claim
    @claim = ConsumerClaim.new(claim_params)

    if @claim.save
      @success = true
      Rails.logger.info "[Libro de Reclamaciones] Nuevo #{@claim.claim_type} registrado con ticket #{@claim.ticket_code} por #{@claim.full_name} (#{@claim.email})"
      flash.now[:notice] = "Su #{@claim.claim_type} ha sido registrado exitosamente con el código #{@claim.ticket_code}."

      Tiktok::SendEventJob.perform_later(
        event_name: 'Lead',
        properties: { content_name: "Libro de Reclamaciones: #{@claim.claim_type}", ticket_code: @claim.ticket_code },
        user_data: { email: @claim.email, phone: @claim.phone, ip: request.remote_ip, user_agent: request.user_agent }
      )
    else
      @success = false
      flash.now[:alert] = "Por favor complete todos los campos obligatorios: #{@claim.errors.full_messages.join(', ')}"
    end

    respond_to do |format|
      format.html { render :libro_reclamaciones }
      format.json do
        if @claim.persisted?
          render json: { success: true, ticket_code: @claim.ticket_code, message: 'Reclamación registrada exitosamente' }
        else
          render json: { success: false, errors: @claim.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "[Libro de Reclamaciones] Error: #{e.message}"
    @success = false
    flash.now[:alert] = "Ocurrió un error al registrar la reclamación: #{e.message}"
    render :libro_reclamaciones, status: :unprocessable_entity
  end

  private

  def claim_params
    params.require(:consumer_claim).permit(
      :claim_type, :document_type, :document_number,
      :first_name, :last_name, :phone, :email, :address,
      :department, :province, :district, :is_minor, :parent_name,
      :good_type, :amount_claimed, :currency, :product_description,
      :details, :consumer_order
    )
  end

  def set_shared_variables
    @brand_name = GlobalConfig.get_value('BRAND_NAME') || 'AIRM'
    @installation_name = GlobalConfig.get_value('INSTALLATION_NAME') || 'AIRM by Giantucchi'
    @login_url = '/app/login'
    @signup_url = '/app/auth/signup'
    @dashboard_url = '/app'
    @help_url = 'https://airm.giantucchi.com/hc/inicio/es_PE'
    @company_name = 'Giantucchi Inc EIRL'
    @company_ruc = '20612896501'
    @company_address = 'Av. Larco 1052, Miraflores, Lima, Perú'
    @company_phone = '+51 913 086 096'
    @company_email = 'hola@giantucchi.com'
    @company_support_email = 'soporte@giantucchi.com'
    @company_hours = 'Lunes a Viernes de 9:00 AM a 6:00 PM (GMT-5)'
    @delivery_time = 'Activación y aprovisionamiento digital en 24 a 72 horas hábiles tras la confirmación del pago'
    @culqi_public_key = ENV.fetch('CULQI_PUBLIC_KEY', 'pk_live_airm_default')
  end
end
