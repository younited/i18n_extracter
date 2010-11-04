require 'extracters/ruby_parser'

module Extracters
  
  class RubyExtracter
    
    def self.extract(files)
      translation_keys = {}
      files.each do |ruby|
        RubyParser.parse(ruby).each do |key, data|
          translation_keys[key] ||= {}
          translation_keys[key][:lines] ||= []
          translation_keys[key][:lines] << "#{ruby.gsub(Rails.root, '')}:#{data[:lines].join(', ')}"
          translation_keys[key][:variables] ||= []
          translation_keys[key][:variables] += data[:variables]
          translation_keys[key][:variables].uniq!
        end
      end
      return translation_keys
    end
    
  end
  
end