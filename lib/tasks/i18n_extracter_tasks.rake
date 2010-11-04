namespace :i18n_extracter do

  task :extract_all => :environment do
    setup
    @extracter.extract_active_record()
    @extracter.extract_models()
    @extracter.extract_controllers()
    @extracter.extract_helpers()
    @extracter.extract_views()
    process(@extracter)
  end

  task :extract_active_record => :environment do
    setup
    @extracter.extract_active_record()
    process(@extracter)
  end

  task :extract_models => :environment do
    setup
    @extracter.extract_models()
    process(@extracter)
  end
  
  task :extract_controllers => :environment do
    setup
    @extracter.extract_controllers()
    process(@extracter)
  end
  
  task :extract_helpers => :environment do
    setup
    @extracter.extract_helpers()
    process(@extracter)
  end
  
  task :extract_views => :environment do
    setup
    @extracter.extract_views()
    process(@extracter)
  end
  
  def setup
    require 'i18n_extracter'
    @extracter = I18nExtracter.new(:locale => ENV['locale'], :file => ENV['file'])
  end
  
  def process(extracter)
    yaml = extracter.generate()
    if extracter.file.blank?
      puts yaml
    end
  end
  
end
