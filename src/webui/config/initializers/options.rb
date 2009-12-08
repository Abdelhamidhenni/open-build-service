path = "#{RAILS_ROOT}/config/options.yml"

begin
  CONFIG = YAML.load_file(path)
rescue Exception => e
  puts "Error while parsing config file #{path}"
  raise e
end

#puts "Loaded openSUSE buildservice webclient config from #{path}"
