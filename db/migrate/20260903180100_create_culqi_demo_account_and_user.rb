# frozen_string_literal: true

class CreateCulqiDemoAccountAndUser < ActiveRecord::Migration[7.0]
  def up
    # 1. Dedicated Isolated Account for Culqi auditors
    account = Account.find_or_create_by!(name: 'AIRM Demo - Culqi Review') do |acc|
      acc.locale = 'es'
    end

    # 2. Dedicated User for Culqi audit team
    user = User.find_or_initialize_by(email: 'demo.culqi@giantucchi.com')
    user.name = 'Auditor Culqi (Demo QA)'
    user.password = 'Culqi2026*Demo'
    user.password_confirmation = 'Culqi2026*Demo'
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!

    # 3. Associate user as administrator of the demo account
    AccountUser.find_or_create_by!(account_id: account.id, user_id: user.id) do |au|
      au.role = :administrator
    end

    # 4. Pre-seed a clean demonstration inbox
    inbox = account.inboxes.find_or_create_by!(name: 'WhatsApp Soporte Demo') do |ib|
      channel = Channel::Api.create!(account: account)
      ib.channel = channel
    end

    # 5. Pre-seed demonstration contact and conversation
    contact = account.contacts.find_or_create_by!(phone_number: '+51999888777') do |c|
      c.name = 'Cliente Demostración Culqi'
      c.email = 'cliente.demo@empresa.com'
    end

    contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) do |ci|
      ci.source_id = 'demo-culqi-source'
    end

    conv = Conversation.find_or_create_by!(account: account, inbox: inbox, contact: contact) do |c|
      c.contact_inbox = contact_inbox
      c.status = :open
    end

    if conv.messages.empty?
      conv.messages.create!(
        account: account,
        inbox: inbox,
        message_type: :incoming,
        content: '¡Hola! Me gustaría conocer sus planes de software, pasarela de pago y precios de AIRM.',
        sender: contact
      )
      conv.messages.create!(
        account: account,
        inbox: inbox,
        message_type: :outgoing,
        content: '¡Hola! Bienvenido a AIRM. Ofrecemos agentes de IA omnicanal para WhatsApp, Instagram y CRM con telefonía VoIP. Los pagos se procesan de forma segura mediante Culqi. ¿En qué podemos orientarte hoy?',
        sender: user
      )
    end
  rescue StandardError => e
    Rails.logger.warn "[Culqi Demo Seed] Warning during setup: #{e.message}"
  end

  def down
    user = User.find_by(email: 'demo.culqi@giantucchi.com')
    user&.destroy
    account = Account.find_by(name: 'AIRM Demo - Culqi Review')
    account&.destroy
  end
end
