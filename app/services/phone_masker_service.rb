# frozen_string_literal: true

class PhoneMaskerService
  class << self
    def can_view_full_phone?(account_user = Current.account_user)
      return true if account_user.blank?
      return true if account_user.administrator?
      return true if account_user.respond_to?(:custom_role) && account_user.custom_role&.permissions&.include?('contact_manage')

      false
    end

    def mask(phone_number)
      return phone_number if phone_number.blank?

      str = phone_number.to_s.strip
      return str if str.length <= 4

      suffix = ''
      if str.include?('@')
        parts = str.split('@', 2)
        str = parts[0]
        suffix = "@#{parts[1]}"
      end

      has_plus = str.start_with?('+')
      digits = str.gsub(/\D/, '')

      return phone_number if digits.length <= 4

      # Format: keep country prefix / first 2-3 digits and last 2-3 digits, masking middle
      if digits.length >= 10
        prefix = digits[0..3]
        suffix_digits = digits[-3..]
      elsif digits.length >= 7
        prefix = digits[0..2]
        suffix_digits = digits[-2..]
      else
        prefix = digits[0..1]
        suffix_digits = digits[-1..]
      end

      formatted_prefix = has_plus ? "+#{prefix}" : prefix
      "#{formatted_prefix} ••• •#{suffix_digits}#{suffix}"
    end

    def phone_like?(str)
      return false if str.blank?

      cleaned = str.to_s.strip
      cleaned.match?(/\A\+?[\d\s\-().]{7,25}(@[a-zA-Z0-9._-]+)?\z/) && cleaned.gsub(/\D/, '').length >= 7
    end

    def mask_if_phone(name_or_str)
      return name_or_str if name_or_str.blank?

      phone_like?(name_or_str) ? mask(name_or_str) : name_or_str
    end
  end
end
