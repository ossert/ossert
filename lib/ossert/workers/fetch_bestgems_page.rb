# frozen_string_literal: true
module Ossert
  module Workers
    class FetchBestgemsPage
      include Sidekiq::Worker
      include Process

      sidekiq_options retry: 3,
                      unique: :until_executed

      def perform(pages)
        pages = Array(pages)
        pages.each do |page|
          puts "Processing Bestgems page: '#{page}'"
          Ossert::Fetch::BestgemsTotalStat.process_page(page) do |_, _, gem_name|

            puts "Processing project: '#{gem_name}'"
            pid = fork do
              Ossert.init
              next(puts("Skipping project: '#{gem_name}'")) if Ossert::Project.exist?(gem_name)
              Ossert::Project.fetch_all(gem_name)
              sleep(10)
            end
            waitpid(pid)
          end
        end
      end
    end
  end
end
