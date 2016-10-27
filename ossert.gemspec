# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ossert/version'

Gem::Specification.new do |spec|
  spec.name          = 'ossert'
  spec.version       = Ossert::VERSION
  spec.authors       = ['Sergey Dolganov']
  spec.email         = ['sclinede@gmail.com']

  spec.summary       = 'Write a short summary, because Rubygems requires one.'
  spec.description   = 'Write a longer description or delete this line.'
  spec.homepage      = 'https://github.com/sclinede/ossert'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'octokit', '~> 4.0'
  spec.add_runtime_dependency 'gems', '~> 0.8.3'

  spec.add_runtime_dependency 'redis'
  spec.add_runtime_dependency 'redis-namespace'
  spec.add_runtime_dependency 'sidekiq'
  spec.add_runtime_dependency 'sidekiq-unique-jobs'

  spec.add_runtime_dependency 'activesupport' # TODO: remove dependency later
  spec.add_runtime_dependency 'oj'
  spec.add_runtime_dependency 'sequel'
  spec.add_runtime_dependency 'rom-repository'
  spec.add_runtime_dependency 'rom-sql'
  spec.add_runtime_dependency 'pg'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_runtime_dependency 'graphr'

  spec.add_development_dependency 'memory_profiler'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'multi_json'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'vcr'
end
