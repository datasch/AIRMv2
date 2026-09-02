class LandingController < ActionController::Base
  include SwitchLocale
  layout 'landing'

  before_action :set_shared_variables

  def index; end

  def terms; end

  def privacy; end

  def status; end

  private

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
  end
end
