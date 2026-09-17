# frozen_string_literal: true

# == Schema Information
#
# Table name: voip_call_logs
#
#  id               :bigint           not null, primary key
#  call_category    :string           default("ineffective")
#  disposition      :string
#  duration_seconds :integer          default(0), not null
#  metadata         :jsonb
#  phone_number     :string
#  recording_url    :string
#  status           :string           default("completed")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  call_id          :string           not null
#  contact_id       :bigint
#  conversation_id  :bigint
#  user_id          :bigint
#
# Indexes
#
#  idx_voip_call_logs_account_category     (account_id,call_category)
#  idx_voip_call_logs_account_created      (account_id,created_at)
#  idx_voip_call_logs_account_disposition  (account_id,disposition)
#  idx_voip_call_logs_account_user         (account_id,user_id)
#  idx_voip_call_logs_call_id              (call_id) UNIQUE
#
class VoipCallLog < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true

  validates :call_id, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :effective, -> { where(call_category: 'effective') }
  scope :test_calls, -> { where(call_category: 'test') }
  scope :ineffective, -> { where(call_category: 'ineffective') }

  DISPOSITIONS = [
    'Venta',
    'Interesado',
    'Agendado',
    'Volver a llamar',
    'Persona mayor',
    'Saturación',
    'No interesado',
    'Buzón de voz',
    'No contesta',
    'Número equivocado'
  ].freeze

  def effective?
    duration_seconds >= 6
  end

  def test_call?
    duration_seconds.between?(2, 5)
  end

  def formatted_duration
    mins = duration_seconds / 60
    secs = duration_seconds % 60
    format('%02d:%02d', mins, secs)
  end
end
