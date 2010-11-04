module Extracters

  class HamlExtracter

    def self.extract(files)
      translation_keys = {}
      files.each do |ruby|
        begin
          haml = Haml::Engine.new(IO.readlines(ruby).join)
          lines = haml.precompiled.split(/$/).collect do |line|
            line.split('#{', 2)[1]
          end.compact
          RubyParser.parse_lines(ruby, lines).each do |key, data|
            translation_keys[key] ||= {}
            translation_keys[key][:lines] ||= []
            translation_keys[key][:lines] << "#{ruby.gsub(Rails.root, '')}:#{data[:lines].join(', ')}"
            translation_keys[key][:variables] ||= []
            translation_keys[key][:variables] += data[:variables]
            translation_keys[key][:variables].uniq!
          end
        rescue Haml::SyntaxError => e
          puts "Syntax error in #{ruby}:\n  #{e.message}"
        end
      end
      return translation_keys
    end

  end

end