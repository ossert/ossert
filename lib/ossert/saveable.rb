module Ossert
  module Saveable
    def filename
      self.class.name
    end

    def read
      fail NotImplementedError
    end

    def assign(saved_data)
      fail NotImplementedError
    end

    # FIXME: Use normal backend, such as Postgres
    def load
      if File.exists?("data/#{filename}.json")
        assign Oj.load(File.read("data/#{filename}.json"))
      end
      self
    end

    def dump
      existance_backup("data/#{filename}.json")
      File.open("data/#{filename}.json","w") do |f|
        f.write(Oj.dump(read))
      end
    end

    def existance_backup(filename)
      return unless File.exists?(filename)
      FileUtils.cp(filename, "#{filename}.#{Time.now.strftime('%d%m%Y-%H%M%S.%L')}")
    end
  end
end
