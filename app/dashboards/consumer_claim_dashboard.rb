# frozen_string_literal: true

require 'administrate/base_dashboard'

class ConsumerClaimDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    ticket_code: Field::String.with_options(searchable: true),
    claim_type: Field::Select.with_options(collection: [%w[Reclamo reclamo], %w[Queja queja]]),
    status: Field::Select.with_options(collection: [%w[Pendiente pending], %w[En\ Revisión in_review], %w[Atendido resolved], %w[Rechazado rejected]]),
    document_type: Field::String,
    document_number: Field::String.with_options(searchable: true),
    first_name: Field::String.with_options(searchable: true),
    last_name: Field::String.with_options(searchable: true),
    email: Field::String.with_options(searchable: true),
    phone: Field::String.with_options(searchable: true),
    address: Field::String,
    department: Field::String,
    province: Field::String,
    district: Field::String,
    is_minor: Field::Boolean,
    parent_name: Field::String,
    good_type: Field::String,
    amount_claimed: Field::Number.with_options(decimals: 2),
    currency: Field::String,
    product_description: Field::Text,
    details: Field::Text,
    consumer_order: Field::Text,
    admin_notes: Field::Text,
    admin_response: Field::Text,
    resolved_at: Field::DateTime,
    resolved_by: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    ticket_code
    claim_type
    first_name
    last_name
    document_number
    email
    phone
    status
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    ticket_code
    status
    claim_type
    created_at
    document_type
    document_number
    first_name
    last_name
    email
    phone
    address
    department
    province
    district
    is_minor
    parent_name
    good_type
    amount_claimed
    currency
    product_description
    details
    consumer_order
    admin_notes
    admin_response
    resolved_at
    resolved_by
  ].freeze

  FORM_ATTRIBUTES = %i[
    status
    admin_notes
    admin_response
    resolved_by
  ].freeze

  def display_resource(claim)
    "Hoja #{claim.ticket_code} (#{claim.full_name})"
  end
end
