require 'jinx/helpers/collections'

require 'jinx/import/java'
require 'jinx/metadata/java_property'
require 'jinx/metadata/introspector'
require 'jinx/metadata/inverse'
require 'jinx/metadata/dependency'

module Jinx
  # Exception raised if a meta-data setting is missing or invalid.
  class MetadataError < RuntimeError; end

  # The metadata introspection mix-in for a Java application domain class or interface.
  module Metadata
    include Introspector, Inverse, Dependency
    
    # @return [Module] the application domain {Resource} module which introspected this class
    attr_accessor :domain_module
    
    # @param [Symbol] attribute the property attribute
    # @param [{Symbol => Object}] opts the property options
    # @option opts [true, Symbol, <Symbol>] :dependent whether this property is a dependent reference
    #   qualified by the given {Property} flags
    def property(attribute, *opts)
      return super(attribute) if opts.empty?
      Options.to_hash(*opts).each do |k, v|
        case k
          when :alias then alias_attribute(v, attribute)
          when :default then add_attribute_default(attribute, v)
          when :dependent then add_dependent_attribute(attribute, v)
          when :inverse then set_attribute_inverse(attribute, v)
          when :mandatory then add_mandatory_attribute(attribute) if v
          when :primary_key then add_primary_key_attribute(attribute) if v
          when :secondary_key then add_secondary_key_attribute(attribute) if v
          when :alternate_key then add_alternate_key_attribute(attribute) if v
          when :type then set_attribute_type(attribute, v)
          else qualify_attribute(attribute, k) if v
        end
      end
    end

    # @return [Class, nil] the domain type for attribute, or nil if attribute is not a domain attribute
    def domain_type(attribute)
      prop = property(attribute)
      prop.type if prop.domain?
    end

    # Returns an empty value for the given attribute.
    # * If this class is not abstract, then the empty value is the initialized value.
    # * Otherwise, if the attribute is a Java primitive number then zero.
    # * Otherwise, if the attribute is a Java primitive boolean then +false+.
    # * Otherwise, the empty value is nil.
    #
    # @param [Symbol] attribute the target attribute
    # @return [Numeric, Boolean, Enumerable, nil] the empty attribute value
    def empty_value(attribute)
      if abstract? then
        prop = property(attribute)
        # the Java attribute type
        jtype = prop.property_descriptor.attribute_type if JavaProperty === prop
        # A primitive is either a boolean or a number (String is not primitive).
        if jtype and jtype.primitive? then
          type.name == 'boolean' ? false : 0
        end
      else
        # Since this class is not abstract, create a prototype instance on demand and make
        # a copy of the initialized collection value from that instance.
        @prototype ||= new
        value = @prototype.send(attribute) || return
        value.class.new
      end
    end
  
   # Prints this classifier's content to the log.
    def pretty_print(q)
      # the Java property descriptors
      property_descriptors = java_attributes.wrap { |pa| property(pa).property_descriptor }
      # build a map of relevant display label => attributes
      prop_printer = property_descriptors.wrap { |pd| PROP_DESC_PRINTER.wrap(pd) }
      prop_syms = property_descriptors.map { |pd| pd.name.to_sym }.to_set
      aliases = @alias_std_prop_map.keys - attributes.to_a - prop_syms
      alias_prop_hash = aliases.to_compact_hash { |aliaz| @alias_std_prop_map[aliaz] }
      dependents_printer = dependent_attributes.wrap { |pa| DEPENDENT_ATTR_PRINTER.wrap(property(pa)) }
      owner_printer = owners.wrap { |type| TYPE_PRINTER.wrap(type) }
      inverses = @attributes.to_compact_hash do |pa|
         prop = property(pa)
         "#{prop.type.qp}.#{prop.inverse}" if prop.inverse
      end
      domain_prop_printer = domain_attributes.to_compact_hash { |pa| domain_type(pa).qp }
      map = {
        "Java attributes" => prop_printer,
        "standard attributes" => attributes,
        "aliases to standard attributes" => alias_prop_hash,
        "secondary key" => secondary_key_attributes,
        "mandatory attributes" => mandatory_attributes,
        "domain attributes" => domain_prop_printer,
        "creatable domain attributes" => creatable_domain_attributes,
        "updatable domain attributes" => updatable_domain_attributes,
        "fetched domain attributes" => fetched_domain_attributes,
        "cascaded domain attributes" => cascaded_attributes,
        "owners" => owner_printer,
        "owner attributes" => owner_attributes,
        "inverse attributes" => inverses,
        "dependent attributes" => dependents_printer,
        "default values" => defaults
      }.delete_if { |key, value| value.nil_or_empty? }
    
      # one indented line per entry, all but the last line ending in a comma
      content = map.map { |label, value| "  #{label}=>#{format_print_value(value)}" }.join(",\n")
      # print the content to the log
      q.text("#{qp} structure:\n#{content}")
    end

    private
  
    # A proc to print the unqualified class name.
    # @private
    TYPE_PRINTER = PrintWrapper.new { |type| type.qp }

    # @private
    DEPENDENT_ATTR_PRINTER = PrintWrapper.new do |prop|
      flags = []
      flags << :logical if prop.logical?
      flags << :autogenerated if prop.autogenerated?
      flags << :disjoint if prop.disjoint?
      flags.empty? ? "#{prop}" : "#{prop}(#{flags.join(',')})"
    end

    # A proc to print the property descriptor name.
    # @private
    PROP_DESC_PRINTER = PrintWrapper.new { |pd| pd.name }

    def format_print_value(value)
      case value
        when String then value
        when Class then value.qp
        else value.pp_s(:single_line)
      end
    end
  end
end