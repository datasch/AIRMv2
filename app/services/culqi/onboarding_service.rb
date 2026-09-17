# frozen_string_literal: true

class Culqi::OnboardingService
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  # Full AIRM Suite Features
  AIRM_FEATURES = %w[
    inbound_emails
    channel_email
    channel_facebook
    channel_instagram
    channel_website
    channel_voice
    help_center
    agent_bots
    macros
    canned_responses
    agent_management
    team_management
    inbox_management
    reports
    report_rollup
    campaigns
    whatsapp_campaign
    advanced_search
    captain_integration
    captain_integration_v2
    captain_tasks
    audit_logs
    crm
    crm_integration
    custom_roles
    custom_attributes
    sla
    voice_recorder
  ].freeze

  def perform
    data = extract_data
    return { success: false, error: 'Correo electrónico de cliente no encontrado en la orden' } if data[:email].blank?

    ActiveRecord::Base.transaction do
      account = find_or_create_account(data)
      user, is_new_user = find_or_create_user(data, account)
      inbox = ensure_default_inbox(account)
      activation_url = nil
      if is_new_user
        activation_token = user.send_reset_password_instructions
        frontend_url = ENV.fetch('FRONTEND_URL', 'https://airm.giantucchi.com')
        activation_url = "#{frontend_url}/app/auth/password/edit?reset_password_token=#{activation_token}"
      end

      Rails.logger.info("[Culqi Onboarding] Cuenta #{account.id} provisionada para #{user.email} (Plan: #{data[:plan_name]})")

      {
        success: true,
        account: account,
        user: user,
        inbox: inbox,
        plan: data[:plan_name],
        is_new_user: is_new_user,
        activation_url: activation_url
      }
    end
  rescue StandardError => e
    error_msg = e.respond_to?(:record) && e.record&.errors.present? ? e.record.errors.full_messages.join(', ') : e.message
    Rails.logger.error("[Culqi Onboarding Error] #{error_msg}\n#{e.backtrace&.first(5)&.join("\n")}")
    { success: false, error: error_msg }
  end

  private

  def extract_data
    raw = payload.is_a?(String) ? JSON.parse(payload) : payload
    data = raw['data'] || raw
    client_details = data['client_details'] || {}
    metadata = data['metadata'] || client_details['metadata'] || {}

    email = client_details['email'].presence || data['email'].presence || metadata['email'].presence
    email = email.to_s.strip.downcase

    first_name = client_details['first_name'].presence || data['first_name'].presence
    last_name = client_details['last_name'].presence || data['last_name'].presence
    full_name = [first_name, last_name].compact.join(' ').presence || metadata['full_name'].presence || 'Administrador'

    company_name = metadata['company_name'].presence ||
                   metadata['empresa'].presence ||
                   client_details['business_name'].presence ||
                   (full_name.present? && full_name != 'Administrador' ? "AIRM - #{full_name}" : 'Empresa AIRM')

    amount_cents = (data['amount'] || 0).to_i
    amount = amount_cents.positive? ? (amount_cents / 100.0) : 0.0
    currency = data['currency_code'].presence || 'PEN'

    product_type = metadata['product_type'].presence ||
                   metadata['plan'].presence ||
                   infer_product_type(amount)

    plan_name = case product_type
                when 'pilot_3_days' then 'Piloto AIRM 3 Días'
                when 'setup_liquidation', 'full_setup' then 'Implementación Agente IA Omnicanal'
                when 'starter_subscription', 'starter' then 'Plan Starter AIRM'
                when 'team_growth' then 'Plan Team Growth AIRM'
                else 'Plan AIRM Comercial'
                end

    order_id = data['id'].presence || data['order_id'].presence || "CULQI-#{Time.current.to_i}"
    salesperson = metadata['salesperson_name'].presence || 'Ventas Directas'
    referral_code = metadata['referral_code'].presence || 'DIRECTO'

    {
      email: email,
      full_name: full_name,
      company_name: company_name,
      phone: client_details['phone_number'].presence || data['phone'].presence,
      order_id: order_id,
      amount: amount,
      currency: currency,
      product_type: product_type,
      plan_name: plan_name,
      salesperson: salesperson,
      referral_code: referral_code
    }
  end

  def infer_product_type(amount)
    if amount <= 30.0
      'pilot_3_days'
    elsif amount <= 500.0
      'starter_subscription'
    else
      'setup_liquidation'
    end
  end

  def find_or_create_account(data)
    existing_user = User.from_email(data[:email])
    account = existing_user&.accounts&.order(created_at: :desc)&.first

    account ||= Account.create!(
      name: data[:company_name],
      locale: 'es'
    )

    # Actualizar atributos y límites del plan adquirido
    custom_attrs = (account.custom_attributes || {}).dup
    custom_attrs.merge!(
      'plan_name' => data[:plan_name],
      'product_type' => data[:product_type],
      'culqi_order_id' => data[:order_id],
      'culqi_amount' => data[:amount],
      'culqi_currency' => data[:currency],
      'salesperson_name' => data[:salesperson],
      'referral_code' => data[:referral_code],
      'paid_at' => Time.current.iso8601,
      'onboarding_step' => 'completed'
    )
    account.custom_attributes = custom_attrs

    # Habilitar telefonía VoIP / PBX
    settings = (account.settings || {}).dup
    settings['voip'] = { 'enabled' => true }
    account.settings = settings

    # Habilitar suite completa de funcionalidades AIRM
    AIRM_FEATURES.each do |feature|
      account.enable_features(feature) if account.respond_to?("feature_#{feature}=")
    end

    account.save!
    account
  end

  def find_or_create_user(data, account)
    user = User.from_email(data[:email])
    is_new = false

    if user.blank?
      temp_pwd = "Airm2026!#{SecureRandom.alphanumeric(14)}#X"
      user = User.create!(
        email: data[:email],
        name: data[:full_name],
        password: temp_pwd,
        password_confirmation: temp_pwd
      )
      user.confirm if user.respond_to?(:confirm)
      is_new = true
    end

    account_user = account.account_users.find_or_initialize_by(user_id: user.id)
    account_user.role = AccountUser.roles['administrator']
    account_user.save!

    [user, is_new]
  end

  def ensure_default_inbox(account)
    return account.inboxes.first if account.inboxes.exists?

    channel = Channel::Api.create!(account: account)
    account.inboxes.create!(
      name: 'WhatsApp & Omnicanal AIRM',
      channel: channel
    )
  rescue StandardError => e
    Rails.logger.warn("[Culqi Onboarding] No se pudo crear inbox por defecto: #{e.message}")
    nil
  end
end
