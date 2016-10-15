module Ossert
  class QuartersStore
    attr_reader :quarters, :stat_klass, :start_date, :end_date

    def initialize(stat_klass)
      @stat_klass = stat_klass
      @quarters = Hash.new
    end

    def fetch(date)
      quarters.fetch date_to_start(date)
    end

    def find_or_create(date)
      quarters[date_to_start(date)] ||= stat_klass.new
    end
    alias_method :[], :find_or_create

    def date_to_start(value)
      if value.is_a? String
        # DateTime.parse(value).beginning_of_quarter.to_i
        DateTime.new(*value.split('-'.freeze).map(&:to_i)).beginning_of_quarter.to_i
      else
        Time.at(value).to_date.to_time(:utc).beginning_of_quarter.to_i
      end
    end

    def preview
      quarters.sort.map { |date_i, value| [Time.at(date_i), value] }.to_h
    end

    def last_year_data
      quarters.sort.last(4).map { |_, quarter| quarter.metric_values }.transpose.map {|x| x.reduce(:+)}
    end

    def last_year_as_hash
      Hash[stat_klass.metrics.zip(last_year_data)]
    end

    def fullfill!
      if quarters.empty?
        @start_date = Time.now
        @end_date = Time.now
        return
      end

      sorted_quarters = quarters.keys.sort
      @start_date = Time.at sorted_quarters.first
      @end_date = Time.at sorted_quarters.last
      period = start_date + 93.days
      while period < end_date
        find_or_create(period)
        period = period + 93.days
      end
    end

    def reverse_each_sorted
      quarters.sort.reverse.map do |key,value|
        yield(key, value)
      end
    end

    def each_sorted
      quarters.sort.map do |key,value|
        yield(key, value)
      end
    end

    def to_json
      hash = quarters.each_with_object({}) do |(time, metrics), result|
        result[time] = metrics.to_hash
      end
      JSON.generate(hash)
    end
  end
end
