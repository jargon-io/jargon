# frozen_string_literal: true

module NormalizesMarkup
  extend ActiveSupport::Concern

  class_methods do
    def normalizes_markup(*attributes)
      before_validation do
        attributes.each do |attr|
          value = send(attr)
          next if value.blank?

          send("#{attr}=", value.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>'))
        end
      end
    end
  end
end
