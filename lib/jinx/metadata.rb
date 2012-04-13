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
          when :dependent then add_dependent_attribute(attribute) if v
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
      map = pretty_print_attribute_hash.delete_if { |k, v| v.nil_or_empty? }
      # one indented line per entry, all but the last line ending in a comma
      content = map.map { |label, value| "  #{label}=>#{format_print_value(value)}" }.join(",\n")
      # print the content to the log
      q.text("#{qp} structure:\n#{content}")
    end

    private
  
    # A proc to print the unqualified class name.
    # @private
    TYPE_PRINTER = PrintWrapper.new { |type| type.qp }

    # A proc to print the property descriptor name.
    # @private
    PROP_DESC_PRINTER = PrintWrapper.new { |pd| pd.name }
             
    # @param [Property] the property to print
    # @return [<Symbol>] the flags to modify the property
    def pretty_print_attribute_flags(prop)
      flags = []
      flags << :disjoint if prop.disjoint?
      flags
    end
    
    # @return [{String => <Symbol>}] the attributes to print
    def pretty_print_attribute_hash
      # the Java property descriptors
      pds = java_attributes.wrap { |pa| property(pa).property_descriptor }
      # the display label => properties printer
      prop_prn = pds.wrap { |pd| PROP_DESC_PRINTER.wrap(pd) }
      # the Java attributes
      prop_syms = pds.map { |pd| pd.name.to_sym }.to_set
      # the attribute aliases
      aliases = @alias_std_prop_map.keys - attributes.to_a - prop_syms
      alias_hash = aliases.to_compact_hash { |aliaz| @alias_std_prop_map[aliaz] }
      # the dependent attributes printer
      dep_prn_wrapper = dependent_attributes_print_wrapper
      dep_prn = dependent_attributes.wrap { |pa| dep_prn_wrapper.wrap(property(pa)) }
      # the owner classes printer
      own_prn = owners.wrap { |type| TYPE_PRINTER.wrap(type) }
      # the inverse attributes printer
      inv_prn = @attributes.to_compact_hash do |pa|
         prop = property(pa)
         "#{prop.type.qp}.#{prop.inverse}" if prop.inverse
      end
      # the domain attribute printer
      dom_prn = domain_attributes.to_compact_hash { |pa| domain_type(pa).qp }
      # the description => printable hash
      {
        'Java attributes' => prop_prn,
        'standard attributes' => attributes,
        'aliases to standard attributes' => alias_hash,
        'secondary key' => secondary_key_attributes,
        'mandatory attributes' => mandatory_attributes,
        'domain attributes' => dom_prn,
        'owners' => own_prn,
        'owner attributes' => owner_attributes,
        'inverse attributes' => inv_prn,
        'dependent attributes' => dep_prn,
        'default values' => defaults
      }
    end

    # @return [PrintWrapper] a proc to print the dependent attributes
    def dependent_attributes_print_wrapper
      PrintWrapper.new do |prop|
        flags = pretty_print_attribute_flags(prop)
        flags.empty? ? "#{prop}" : "#{prop}(#{flags.join(',')})"
      end
    end

    def format_print_value(value)
      case value
        when String then value
        when Class then value.qp
        else value.pp_s(:single_line)
      end
    end
  end
end