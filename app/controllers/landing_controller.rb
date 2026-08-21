class LandingController < ActionController::Base
  include SwitchLocale
  layout 'landing'

  def index
    @brand_name = GlobalConfig.get_value('BRAND_NAME') || 'AIRM'
    @installation_name = GlobalConfig.get_value('INSTALLATION_NAME') || 'AIRM by Giantucchi'
    @login_url = '/app/login'
    @signup_url = '/app/auth/signup'
    @dashboard_url = '/app'
  end
end
