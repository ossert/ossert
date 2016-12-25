# frozen_string_literal: true
module Ossert
  module Workers
    class FetchBestgemsPage
      include Sidekiq::Worker
      include ForkProcessing

      sidekiq_options retry: 3,
                      unique: :until_executed

      def perform(pages, type = :total)
        pages = Array(pages)
        bestgems_page_processor = Kernel.const_get(
          "Ossert::Fetch::Bestgems#{type.to_s.capitalize}Stat"
        )
        pages.each do |page|
          puts "Processing Bestgems page: '#{page}'"
          bestgems_page_processor.process_page(page) do |_, _, gem_name|
            puts "Processing project: '#{gem_name}'"
            process_in_fork do
              Ossert.init
              next(puts("Skipping project: '#{gem_name}'")) if Ossert::Project.exist?(gem_name)
              Ossert::Project.fetch_all(gem_name)
            end
          end
        end
      end
    end
  end
end
