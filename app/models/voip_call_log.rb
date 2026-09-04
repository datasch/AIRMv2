# frozen_string_literal: true

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
