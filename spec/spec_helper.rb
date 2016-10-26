require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ossert'
require 'multi_json'
require 'rspec'
require 'webmock/rspec'
require 'base64'

DB_URL = ENV.fetch('TEST_DATABASE_URL')
Ossert.rom(DB_URL)

require 'vcr'
VCR.configure do |c|
  c.configure_rspec_metadata!

  c.filter_sensitive_data("<<ACCESS_TOKEN>>") do
    test_github_token
  end

  c.before_http_request(:real?) do |request|
    next if request.headers['X-Vcr-Test-Repo-Setup']
  end

  c.ignore_request do |request|
    !!request.headers['X-Vcr-Test-Repo-Setup']
  end

  c.default_cassette_options = {
    :serialize_with             => :json,
    # TODO: Track down UTF-8 issue and remove
    :preserve_exact_body_bytes  => true,
    :decode_compressed_response => true,
    :record                     => ENV['TRAVIS'] ? :none : :once
  }
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.before(:all) do
    db = Sequel.connect(DB_URL)
    db.run('TRUNCATE TABLE projects;')

    @A_project = 'multi_json'
    @B_project = 'rake'
    @C_project = 'scientist'
    @D_project = 'dry-web'
    @E_project = 'reifier'

    threads = []
    threads << Thread.new do
      VCR.use_cassette 'fetch_a_project' do
        Ossert::Project.fetch_all(@A_project, 'ClassA')
      end
    end
    threads << Thread.new do
      VCR.use_cassette 'fetch_b_project' do
        Ossert::Project.fetch_all(@B_project, 'ClassB')
      end
    end
    threads << Thread.new do
      VCR.use_cassette 'fetch_c_project' do
        Ossert::Project.fetch_all(@C_project, 'ClassC')
      end
    end
    threads << Thread.new do
      VCR.use_cassette 'fetch_d_project' do
        Ossert::Project.fetch_all(@D_project, 'ClassD')
      end
    end
    threads << Thread.new do
      VCR.use_cassette 'fetch_e_project' do
        Ossert::Project.fetch_all(@E_project, 'ClassE')
      end
    end
    threads.each(&:join) # not stable solution...
    # Ossert::Project.fetch_all(@A_project, 'ClassA')
    # Ossert::Project.fetch_all(@B_project, 'ClassB')
    # Ossert::Project.fetch_all(@C_project, 'ClassC')
    # Ossert::Project.fetch_all(@D_project, 'ClassD')
    # Ossert::Project.fetch_all(@E_project, 'ClassE')
  end
  config.after(:all) do
    db = Sequel.connect(DB_URL)
    db.run('TRUNCATE TABLE projects;')
  end
end

def test_github_token
  ENV.fetch 'GITHUB_TOKEN', 'x' * 40
end

def fixture_path
  File.expand_path("../fixtures", __FILE__)
end

def fixture(file)
  File.new(fixture_path + '/' + file)
end
