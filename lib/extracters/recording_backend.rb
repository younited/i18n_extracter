module Extraters
  class RecordingBackend
    attr_reader :keys

    def initialize
      @keys = []
    end

    def translate(locale, key, options = {})
      @keys << (Array(options[:scope]) + [key]).map.flatten.join('.')
    end
    alias :t :translate
  end
end

