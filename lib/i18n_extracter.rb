require 'translator'
require 'extracters/ruby_parser'

class I18nExtracter

  attr_reader :locale, :file, :translator, :generator, :extracted_keys

  def initialize(options = {})
    @locale = options[:locale] || I18n.default_locale
    @file = if options[:file].blank? then nil else options[:file] end
    @translator = options[:translator] || Translators::GoogleTranslator.new(@locale)
    @generator = options[:generator] || Generaters::YamlGenerater.new(@locale, @translator, @file)
    @extracted_keys = {}
  end

  def extract_models(folders = [File.join(Rails.root, 'app/models')])
    puts "extracting keys from models in #{folders.join(', ')}"
    @extracted_keys = Extracters::RubyExtracter.extract(files(folders)).merge @extracted_keys
  end

  def extract_active_record(folders = [File.join(Rails.root, 'app/models')])
    puts "extracting active_record info in #{folders.join(', ')}"
    @extracted_keys = Extracters::ActiveRecordExtracter.extract(files(folders)).merge @extracted_keys
  end

  def extract_controllers(folders = [File.join(Rails.root, 'app/controllers')])
    puts "extracting keys from controllers in #{folders.join(', ')}"
    @extracted_keys = Extracters::RubyExtracter.extract(files(folders)).merge @extracted_keys
  end
  
  def extract_helpers(folders = [File.join(Rails.root, 'app/helpers')])
    puts "extracting keys from helpers in #{folders.join(', ')}"
    @extracted_keys = Extracters::RubyExtracter.extract(files(folders)).merge @extracted_keys
  end

  def extract_views(folders = [File.join(Rails.root, 'app/views')])
    puts "extracting keys from views in #{folders.join(', ')}"
    # first ERB
    @extracted_keys = Extracters::ErbExtracter.extract(files(folders, ['erb'])).merge @extracted_keys
    # haml if haml is used
    if defined? Haml
      @extracted_keys = Extracters::HamlExtracter.extract(files(folders, ['haml'])).merge @extracted_keys
    end
  end

  def extract_ruby_files(files)
    puts "extracting keys from files"
    @extracted_keys = Extracters::RubyExtracter.extract(files).merge @extracted_keys
  end

  # def translate
  #   puts "translating #{@extracted_keys.length} extracted keys"
  #   @extracted_keys.keys.each do |key|
  #     @extracted_keys[key][:translation] = @translator.translate(key.split('.').last)
  #   end
  # end

  def generate
    puts "converting #{@extracted_keys.size} extracted keys to file"
    result = @generator.generate(@extracted_keys)
    puts "translated #{@translator.translation_count} keys" unless @translator.translation_count.zero?
    return result
  end

  def files(folders, extensions = ['rb'], deep = true)
    ruby_filenames = []
    folders.each do |dir|
      ruby_filenames += Dir[File.join(dir, if deep then "**/*.{#{extensions.join(',')}}" else "*.{#{extensions.join(',')}}" end)]
    end
    ruby_filenames
  end

end
