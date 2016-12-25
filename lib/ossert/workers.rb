# frozen_string_literal: true
require 'sidekiq'
require 'sidekiq-unique-jobs'
require 'ossert/workers/fork_processing'
require 'ossert/workers/fetch'
require 'ossert/workers/partial_fetch'
require 'ossert/workers/fetch_bestgems_page'
require 'ossert/workers/refresh_fetch'
require 'ossert/workers/partial_refresh_fetch'

module Ossert
  module Workers
  end
end
