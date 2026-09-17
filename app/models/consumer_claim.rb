# frozen_string_literal: true

# == Schema Information
#
# Table name: consumer_claims
#
#  id                  :bigint           not null, primary key
#  address             :string           not null
#  admin_notes         :text
#  admin_response      :text
#  amount_claimed      :decimal(10, 2)
#  claim_type          :string           default("reclamo"), not null
#  consumer_order      :text             not null
#  currency            :string           default("PEN")
#  department          :string
#  details             :text             not null
#  district            :string
#  document_number     :string           not null
#  document_type       :string           not null
#  email               :string           not null
#  first_name          :string           not null
#  good_type           :string           default("servicio"), not null
#  is_minor            :boolean          default(FALSE)
#  last_name           :string           not null
#  parent_name         :string
#  phone               :string           not null
#  product_description :text             not null
#  province            :string
#  resolved_at         :datetime
#  resolved_by         :string
#  status              :string           default("pending"), not null
#  ticket_code         :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_consumer_claims_on_ticket_code  (ticket_code) UNIQUE
#
class ConsumerClaim < ApplicationRecord
  enum claim_type: { reclamo: 'reclamo', queja: 'queja' }
  enum status: { pending: 'pending', in_review: 'in_review', resolved: 'resolved', rejected: 'rejected' }

  validates :ticket_code, presence: true, uniqueness: true
  validates :claim_type, :document_type, :document_number, :first_name, :last_name, :phone, :email, :address, :product_description, :details, :consumer_order, presence: true

  before_validation :generate_ticket_code, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def formatted_date
    (created_at || Time.current).strftime('%d/%m/%Y %H:%M')
  end

  private

  def generate_ticket_code
    return if ticket_code.present?

    year = Time.current.year
    count = ConsumerClaim.where('created_at >= ?', Time.current.beginning_of_year).count + 1
    self.ticket_code = format('LR-%<year>d-%<number>05d', year: year, number: count)
  end
end
