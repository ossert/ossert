# frozen_string_literal: true

module KeysSymbolizer
  def symbolize_keys!(object)
    if object.is_a?(Array)
      object.each_with_index do |val, index|
        object[index] = symbolize_keys!(val)
      end
    elsif object.is_a?(Hash)
      object.dup.each_key do |key|
        object[key.to_sym] = symbolize_keys!(object.delete(key))
      end
    end
    object
  end
end
