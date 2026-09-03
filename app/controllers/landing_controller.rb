class LandingController < ActionController::Base
  include SwitchLocale
  layout 'landing'

  before_action :set_shared_variables

  def index; end

  def terms; end

  def privacy; end

  def status; end

  def devoluciones; end

  def libro_reclamaciones
    @claim = ConsumerClaim.new
  end

  def create_claim
    @claim = ConsumerClaim.new(claim_params)

    if @claim.save
      @success = true
      Rails.logger.info "[Libro de Reclamaciones] Nuevo #{@claim.claim_type} registrado con ticket #{@claim.ticket_code} por #{@claim.full_name} (#{@claim.email})"
      flash.now[:notice] = "Su #{@claim.claim_type} ha sido registrado exitosamente con el código #{@claim.ticket_code}."
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
