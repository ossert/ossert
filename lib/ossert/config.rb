require 'yaml'

module Ossert
  class Config
    CONFIG_ROOT = File.join(File.dirname(__FILE__), '..', '..', 'config')
    CONST_NAME = 'Settings'

    def self.load(*configs)
      config_data = configs.each_with_object({}) do |config, result|
        if (path = File.join(CONFIG_ROOT, "#{config}.yml")) && File.exist?(path.to_s)
          result.merge! YAML.load(IO.read(path.to_s))
        end
      end

      Kernel.send(:remove_const, CONST_NAME) if Kernel.const_defined?(CONST_NAME)
      Kernel.const_set(CONST_NAME, config_data)
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
    end
  end
end
