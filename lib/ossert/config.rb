# frozen_string_literal: true
require 'yaml'

module Ossert
  class Config
    # Public: Path to directory where config files are stored.
    CONFIG_ROOT = File.join(File.dirname(__FILE__), '..', '..', 'config')

    # Public: Name of constant which is used to access config.
    CONST_NAME = 'Settings'

    # Public: Load configuration files into memory.
    # Currently works with plain old YAML files.
    # TODO: use ERB, needed for Time syntetics
    #
    # configs - an Array of config names relative to configs root.
    #
    # Returns nothing.
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
            "Error: #{e.message}"
    end

    # Prepare path relative to the config root.
    #
    # @param relative_path [String] path to file/directory relative to current
    #   config directory.
    # @return [String] absolute path for given relative one.
    def self.path(relative_path)
      File.join(Ossert::Config::CONFIG_ROOT, relative_path)
    end
  end
end
