# frozen_string_literal: true

module Ossert
  module Reddit
    # Query with params
    class Query
      extend Forwardable

      def_delegators :@params, :[], :[]=
      attr_reader :params, :path

      def initialize(path, params)
        @path = path
        @params = params
      end

      def limit
        @params[:limit]
      end

      def to_param_list
        [@path, @params]
      end

      def range=(range)
        @params[:after] = range.begin.to_i
        @params[:before] = range.end.to_i
      end
    end
  end
end
