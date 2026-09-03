# frozen_string_literal: true

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
