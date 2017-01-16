module Ossert
  module Fetch
    module Utils
      module KeysStorage
        class Base
          def self.call
            new(self.name.upcase).call
          end

          def initialize(name)
            @storage_name = "#{name}_TOKEN_ARRAY"
          end

          def keys
            @keys ||= ENV.fetch(@storage_name) { "" }.split(':')
          end

          def call
            keys.sample
          end
        end

        class GitHub < Base; end
        class SO < Base; end
      end
    end
  end
end
