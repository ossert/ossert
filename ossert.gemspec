# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ossert/version'

Gem::Specification.new do |spec|
  spec.name          = 'ossert'
  spec.version       = Ossert::VERSION
  spec.authors       = ['Sergey Dolganov']
  spec.email         = ['sclinede@gmail.com']

  spec.summary       = 'Open-source gems maintenance & maturity tracking'
  spec.description   = 'Open-source gems maintenance & maturity tracking'
  spec.homepage      = 'https://github.com/ossert/ossert'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '2.6.9'

  spec.add_runtime_dependency 'octokit', '~> 4.0'

  spec.add_runtime_dependency 'dotenv'

  spec.add_runtime_dependency 'redis'
  spec.add_runtime_dependency 'redis-namespace'
  spec.add_runtime_dependency 'sidekiq'
  spec.add_runtime_dependency 'sidekiq-unique-jobs'

  spec.add_runtime_dependency 'activesupport' # TODO: remove dependency later
  spec.add_runtime_dependency 'gnuplot'
  spec.add_runtime_dependency 'graphr'
  spec.add_runtime_dependency 'multi_json'
  spec.add_runtime_dependency 'nokogiri', '>= 1.12.5'
  spec.add_runtime_dependency 'oj'
  spec.add_runtime_dependency 'pg'
  spec.add_runtime_dependency 'rake'
  spec.add_runtime_dependency 'sequel', '< 5'

  spec.add_runtime_dependency 'json-schema'
  spec.add_runtime_dependency 'twitter'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'dotenv'
  spec.add_development_dependency 'memory_profiler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-sidekiq'
  spec.add_development_dependency 'rubocop', '~> 0.53'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'yard'
end
