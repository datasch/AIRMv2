require 'active_model'
class TestModel
  include ActiveModel::Validations
  attr_accessor :external_url
  validates :external_url, length: { maximum: 255 }
end

t = TestModel.new
t.external_url = nil
t.valid?
puts "Valid? #{t.valid?}"
puts "Errors: #{t.errors.full_messages}"
