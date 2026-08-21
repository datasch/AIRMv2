# loading installation configs
GlobalConfig.clear_cache
ConfigLoader.new.process

## Seeds productions
if Rails.env.production?
  # Setup Onboarding flow
  Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING, true)
end

## Seeds for Local Development
unless Rails.env.production?

  # Enables creating additional accounts from dashboard
  installation_config = InstallationConfig.find_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')
  installation_config.value = true
  installation_config.save!
  GlobalConfig.clear_cache

  account = Account.create!(
    name: 'Giantucchi Enterprise'
  )

  secondary_account = Account.create!(
    name: 'AIRM Innovation Lab'
  )

  user = User.new(name: 'Giantucchi Admin', email: 'admin@giantucchi.com', password: 'Password1!', type: 'SuperAdmin')
  user.skip_confirmation!
  user.save!

  AccountUser.create!(
    account_id: account.id,
    user_id: user.id,
    role: :administrator
  )

  AccountUser.create!(
    account_id: secondary_account.id,
    user_id: user.id,
    role: :administrator
  )

  # Seed AIRM CRM Custom Attributes
  [
    { attribute_display_name: 'Deal Stage', attribute_key: 'deal_stage', attribute_model: 'conversation_attribute', attribute_display_type: 'list', attribute_values: ['Lead In', 'Contacted', 'Qualified', 'Proposal', 'Negotiation', 'Won', 'Lost'], attribute_description: 'Sales Pipeline Stage' },
    { attribute_display_name: 'Deal Value', attribute_key: 'deal_value', attribute_model: 'conversation_attribute', attribute_display_type: 'currency', attribute_description: 'Estimated Deal Value' },
    { attribute_display_name: 'Lead Priority', attribute_key: 'lead_priority', attribute_model: 'contact_attribute', attribute_display_type: 'list', attribute_values: ['Urgent', 'High', 'Medium', 'Low'], attribute_description: 'Priority score of the lead' }
  ].each do |attr|
    CustomAttributeDefinition.find_or_create_by!(account_id: account.id, attribute_key: attr[:attribute_key]) do |cad|
      cad.attribute_display_name = attr[:attribute_display_name]
      cad.attribute_model = attr[:attribute_model]
      cad.attribute_display_type = attr[:attribute_display_type]
      cad.attribute_values = attr[:attribute_values] if attr[:attribute_values]
      cad.attribute_description = attr[:attribute_description]
    end
  end

  # Seed AIRM Default Labels
  ['Lead', 'Qualified', 'Proposal', 'Won', 'VIP', 'WhatsApp', 'Support'].each do |label_title|
    Label.find_or_create_by!(account_id: account.id, title: label_title)
  end

  web_widget = Channel::WebWidget.create!(account: account, website_url: 'https://giantucchi.com')

  inbox = Inbox.create!(channel: web_widget, account: account, name: 'AIRM Live Support')
  InboxMember.create!(user: user, inbox: inbox)

  contact_inbox = ContactInboxWithContactBuilder.new(
    source_id: user.id,
    inbox: inbox,
    hmac_verified: true,
    contact_attributes: { name: 'Demo Contact', email: 'contact@giantucchi.com', phone_number: '+51999999999' }
  ).perform

  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    status: :open,
    assignee: user,
    contact: contact_inbox.contact,
    contact_inbox: contact_inbox,
    additional_attributes: { 'deal_stage' => 'Qualified', 'deal_value' => '5000' }
  )

  # sample email collect
  Seeders::MessageSeeder.create_sample_email_collect_message conversation

  Message.create!(content: '¡Hola! Bienvenido a AIRM by Giantucchi.', account: account, inbox: inbox, conversation: conversation, sender: contact_inbox.contact,
                  message_type: :incoming)

  # sample location message
  location_message = Message.new(content: 'location', account: account, inbox: inbox, sender: contact_inbox.contact, conversation: conversation,
                                 message_type: :incoming)
  location_message.attachments.new(
    account_id: account.id,
    file_type: 'location',
    coordinates_lat: -12.046374,
    coordinates_long: -77.042793,
    fallback_title: 'Lima, Perú'
  )
  location_message.save!

  # sample card
  Seeders::MessageSeeder.create_sample_cards_message conversation
  # input select
  Seeders::MessageSeeder.create_sample_input_select_message conversation
  # form
  Seeders::MessageSeeder.create_sample_form_message conversation
  # articles
  Seeders::MessageSeeder.create_sample_articles_message conversation
  # csat
  Seeders::MessageSeeder.create_sample_csat_collect_message conversation

  CannedResponse.create!(account: account, short_code: 'start', content: 'Hola, bienvenido a AIRM by Giantucchi. ¿En qué podemos ayudarte hoy?')
end
