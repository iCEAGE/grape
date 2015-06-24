require 'active_support/concern'

module Grape
  module DSL
    # Defines DSL methods, meant to be applied to a ParamsScope, which define
    # and describe the parameters accepted by an endpoint, or all endpoints
    # within a namespace.
    module Parameters
      extend ActiveSupport::Concern

      # Include reusable params rules among current.
      # You can define reusable params with helpers method.
      #
      # @example
      #
      #     class API < Grape::API
      #       helpers do
      #         params :pagination do
      #           optional :page, type: Integer
      #           optional :per_page, type: Integer
      #         end
      #       end
      #
      #       desc "Get collection"
      #       params do
      #         use :pagination
      #       end
      #       get do
      #         Collection.page(params[:page]).per(params[:per_page])
      #       end
      #     end
      def use(*names)
        named_params = Grape::DSL::Configuration.stacked_hash_to_hash(@api.namespace_stackable(:named_params)) || {}
        options = names.last.is_a?(Hash) ? names.pop : {}
        names.each do |name|
          params_block = named_params.fetch(name) do
            fail "Params :#{name} not found!"
          end
          instance_exec(options, &params_block)
        end
      end
      alias_method :use_scope, :use
      alias_method :includes, :use

      # Require one or more parameters for the current endpoint.
      #
      # @param attrs list of parameter names, or, if :using is
      #   passed as an option, which keys to include (:all or :none) from
      #   the :using hash. The last key can be a hash, which specifies
      #   options for the parameters
      # @option attrs :type [Class] the type to coerce this parameter to before
      #   passing it to the endpoint. See Grape::ParameterTypes for supported
      #   types, or use a class that defines `::parse` as a custom type
      # @option attrs :desc [String] description to document this parameter
      # @option attrs :default [Object] default value, if parameter is optional
      # @option attrs :values [Array] permissable values for this field. If any
      #   other value is given, it will be handled as a validation error
      # @option attrs :using [Hash[Symbol => Hash]] a hash defining keys and
      #   options, like that returned by Grape::Entity#documentation. The value
      #   of each key is an options hash accepting the same parameters
      # @option attrs :except [Array[Symbol]] a list of keys to exclude from
      #   the :using Hash. The meaning of this depends on if :all or :none was
      #   passed; :all + :except will make the :except fields optional, whereas
      #   :none + :except will make the :except fields required
      #
      # @example
      #
      #     params do
      #       # Basic usage: require a parameter of a certain type
      #       requires :user_id, type: Integer
      #
      #       # You don't need to specify type; String is default
      #       requires :foo
      #
      #       # Multiple params can be specified at once if they share
      #       # the same options.
      #       requires :x, :y, :z, type: Date
      #
      #       # Nested parameters can be handled as hashes. You must
      #       # pass in a block, within which you can use any of the
      #       # parameters DSL methods.
      #       requires :user, type: Hash do
      #         requires :name, type: String
      #       end
      #     end
      def requires(*attrs, &block)
        orig_attrs = attrs.clone

        opts = attrs.last.is_a?(Hash) ? attrs.pop.clone : {}
        opts[:presence] = true

        if opts[:using]
          require_required_and_optional_fields(attrs.first, opts)
        else
          validate_attributes(attrs, opts, &block)

          block_given? ? new_scope(orig_attrs, &block) :
              push_declared_params(attrs)
        end
      end

      # Allow, but don't require, one or more parameters for the current
      #   endpoint.
      # @param (see #requires)
      # @option (see #requires)
      def optional(*attrs, &block)
        orig_attrs = attrs.clone

        opts = attrs.last.is_a?(Hash) ? attrs.pop.clone : {}
        type = opts[:type]

        # check type for optional parameter group
        if attrs && block_given?
          fail Grape::Exceptions::MissingGroupTypeError.new if type.nil?
          fail Grape::Exceptions::UnsupportedGroupTypeError.new unless [Array, Hash].include?(type)
        end

        if opts[:using]
          require_optional_fields(attrs.first, opts)
        else
          validate_attributes(attrs, opts, &block)

          block_given? ? new_scope(orig_attrs, true, &block) :
              push_declared_params(attrs)
        end
      end

      # Disallow the given parameters to be present in the same request.
      # @param attrs [*Symbol] parameters to validate
      def mutually_exclusive(*attrs)
        validates(attrs, mutual_exclusion: true)
      end

      # Require exactly one of the given parameters to be present.
      # @param (see #mutually_exclusive)
      def exactly_one_of(*attrs)
        validates(attrs, exactly_one_of: true)
      end

      # Require at least one of the given parameters to be present.
      # @param (see #mutually_exclusive)
      def at_least_one_of(*attrs)
        validates(attrs, at_least_one_of: true)
      end

      # Require that either all given params are present, or none are.
      # @param (see #mutually_exclusive)
      def all_or_none_of(*attrs)
        validates(attrs, all_or_none_of: true)
      end

      alias_method :group, :requires

      # @param params [Hash] initial hash of parameters
      # @return hash of parameters relevant for the current scope
      # @api private
      def params(params)
        params = @parent.params(params) if @parent
        if @element
          if params.is_a?(Array)
            params = params.flat_map { |el| el[@element] || {} }
          elsif params.is_a?(Hash)
            params = params[@element] || {}
          else
            params = {}
          end
        end
        params
      end
    end
  end
end
