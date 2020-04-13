# frozen_string_literal: true

require 'forwardable'

module Apartment
  #   The main entry point to Apartment functions
  #
  module Tenant
    extend self
    extend Forwardable

    def_delegators :adapter, :create, :drop, :switch, :switch!, :current, :each,
                   :reset, :set_callback, :seed, :current_tenant,
                   :default_tenant, :environmentify

    attr_writer :config

    #   Initialize Apartment config options such as excluded_models
    #
    def init
      adapter.process_excluded_models
    end

    #   Fetch the proper multi-tenant adapter based on Rails config
    #
    #   @return {subclass of Apartment::AbstractAdapter}
    #
    def adapter
      RequestStore.store[:apartment_adapter] ||= begin
        adapter_method = "#{config[:adapter]}_adapter"

        if defined?(JRUBY_VERSION)
          if config[:adapter] =~ /mysql/
            adapter_method = 'jdbc_mysql_adapter'
          elsif config[:adapter] =~ /postgresql/
            adapter_method = 'jdbc_postgresql_adapter'
          end
        end

        begin
          require "apartment/adapters/#{adapter_method}"
        rescue LoadError
          raise "The adapter `#{adapter_method}` is not yet supported"
        end

        raise AdapterNotFound, "database configuration specifies nonexistent #{config[:adapter]} adapter" unless respond_to?(adapter_method)

        send(adapter_method, config)
      end
    end

    #   Reset config and adapter so they are regenerated
    #
    def reload!(config = nil)
      RequestStore.store[:apartment_adapter] = nil
      @config = config
    end

    private

    #   Fetch the rails database configuration
    #
    def config
      @config ||= Apartment.connection_config
    end
  end
end
