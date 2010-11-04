module Extracters

  class ActiveRecordExtracter

    def self.extract(files)
      translation_keys = {}
      models(files).each do |model|
        translation_keys["activerecord.models.#{model.english_name}"] = {}
        model.content_columns.each do |c|
          translation_keys["activerecord.attributes.#{model.english_name}.#{c.name}"] = {}
        end
        model.reflect_on_all_associations.each do |association|
          translation_keys["activerecord.attributes.#{model.english_name}.#{association.name}"] = {}
        end
      end
      return translation_keys
    end

  private

    def self.models(files)
      model_names(files).map do |model_name|
        model = begin
          m = model_name.camelize.constantize
          next unless m.respond_to?(:content_columns)
          m.class_eval %Q[def self.english_name; "#{model_name}"; end]
          m
        rescue
          next
        end
      end.compact
    end
    
    def self.model_names(files)
      model_names = []
      files.each do |file|
        file = file.to_s.gsub(File.join(::Rails.root, 'app', 'models'), '')
        model_names << file.match(/\/(.*)\.rb\Z/)[1] rescue nil
      end
      return model_names.compact
    end

  end

end