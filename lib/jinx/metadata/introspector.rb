require 'jinx/helpers/module'
require 'jinx/import/java'
require 'jinx/metadata/propertied'
require 'jinx/metadata/java_property'
require 'jinx/helpers/math'

module Jinx
  # Meta-data mix-in to infer attribute meta-data from Java properties.
  module Introspector
    include Propertied
    
    # @return [Boolean] whether this class has been introspected
    def introspected?
      !!@introspected
    end
    
    # Adds an optional {attribute=>value} constructor parameter to this class.
    def add_attribute_value_initializer
      class << self
        def new(opts=nil)
          obj = super()
          obj.merge_attributes(opts) if opts
          obj
        end
      end
      logger.debug { "#{self} is extended with an optional {attribute=>value} constructor parameter." }
    end

    # Defines the Java attribute access methods, e.g. +study_protocol+ and +studyProtocol+.
    # A boolean attribute is provisioned with an additional reader alias, e.g. +available?+
    # for +is_available+.
    #
    # Each Java property attribute delegates to the Java attribute getter and setter.
    # Each standard attribute delegates to the Java property attribute.
    # Redefining these methods results in a call to the redefined method.
    # This contrasts with a Ruby alias, where the alias remains bound to the
    # original method body.
    def introspect
      # Set up the attribute data structures; delegates to Propertied.
      init_property_classifiers
      logger.debug { "Introspecting #{qp} metadata..." }
      # check for method conflicts
      conflicts = instance_methods(false) & Resource.instance_methods(false)
      unless conflicts.empty? then
        logger.warn("#{self} methods conflict with #{Resource} methods: #{conflicts.qp}")
      end
      # If this is a Java class rather than interface, then define the Java property
      # attributes.
      if Class === self then
        # the Java attributes defined by this class with both a read and a write method
        pds = property_descriptors(false)
        # Define the standard Java attribute methods.
        pds.each { |pd| define_java_property(pd) }
      end
      # Mark this class as introspected.
      @introspected = true
      logger.debug { "Introspection of #{qp} metadata complete." }
      self
    end
    
    private

    # Defines the Java property attribute and standard attribute methods, e.g.
    # +study_protocol+ and +studyProtocol+. A boolean attribute is provisioned
    # with an additional reader alias, e.g.  +available?+  for +is_available+.
    #
    # A standard attribute which differs from the property attribute delegates
    # to the property attribute, e.g. +study_protocol+ delegates to +studyProtocol+
    # rather than aliasing +setStudyProtocol+. Redefining these methods results
    # in a call to the redefined method.  This contrasts with a Ruby alias,
    # where each attribute alias is bound to the respective attribute reader or
    # writer.
    #
    # @param [Java::PropertyDescriptor] the introspected property descriptor
    def define_java_property(pd)
      if transient?(pd) then
        logger.debug { "Ignoring #{name.demodulize} transient attribute #{pd.name}." }
        return
      end
      # the standard underscore lower-case attributes
      prop = add_java_property(pd)
      # delegate the standard attribute accessors to the attribute accessors
      alias_property_accessors(prop)
      # add special wrappers
      wrap_java_property(prop)
      # create Ruby alias for boolean, e.g. alias :empty? for :empty
      if pd.property_type.name[/\w+$/].downcase == 'boolean' then
        # Strip the leading is_, if any, before appending a question mark.
        aliaz = prop.to_s[/^(is_)?(\w+)/, 2] << '?'
        delegate_to_property(aliaz, prop)
      end
    end

    # Adds a filter to the given property access methods if it is a String or Date.
    def wrap_java_property(property)
      pd = property.property_descriptor
      if pd.property_type == Java::JavaLang::String.java_class then
        wrap_java_string_property(property)
      elsif pd.property_type == Java::JavaUtil::Date.java_class then
        wrap_java_date_property(property)
      end
    end

    # Adds a number -> string filter to the given String property Ruby access methods.
    def wrap_java_string_property(property)
      ra, wa = property.accessors
      jra, jwa = property.java_accessors
      # filter the attribute writer
      define_method(wa) do |value|
        stdval = Math.numeric?(value) ? value.to_s : value
        send(jwa, stdval)
      end
      logger.debug { "Filtered #{qp} #{wa} method with non-String -> String converter." }
    end

    # Adds a Java-Ruby Date filter to the given Date property Ruby access methods.
    # The reader returns a Ruby date. The writer sets a Java date.
    def wrap_java_date_property(property)
      ra, wa = property.accessors
      jra, jwa = property.java_accessors
      
      # filter the attribute reader
      define_method(ra) do
        value = send(jra)
        Java::JavaUtil::Date === value ? value.to_ruby_date : value
      end
      
      # filter the attribute writer
      define_method(wa) do |value|
        value = Java::JavaUtil::Date.from_ruby_date(value) if ::Date === value
        send(jwa, value)
      end

      logger.debug { "Filtered #{qp} #{ra} and #{wa} methods with Java Date <-> Ruby Date converter." }
    end

    # Aliases the given Ruby property reader and writer to its underlying Java property reader and writer, resp.
    #
    # @param [Property] property the property to alias
    def alias_property_accessors(property)
      # the Java reader and writer accessor method symbols
      jra, jwa = property.java_accessors
      # strip the Java reader and writer is/get/set prefix and make a symbol
      alias_method(property.reader, jra)
      alias_method(property.writer, jwa)
    end

    # Makes a standard attribute for the given property descriptor.
    # Adds a camelized Java-like alias to the standard attribute.
    #
    # @param (see #define_java_property)
    # @return [Property] the new property
    def add_java_property(pd)
      # make the attribute metadata
      prop = create_java_property(pd)
      add_property(prop)
      # the property name is an alias for the standard attribute
      pa = prop.attribute
      # the Java property name as an attribute symbol
      ja = pd.name.to_sym
      delegate_to_property(ja, prop) unless prop.reader == ja
      prop
    end
    
    # @param (see #add_java_property)
    # @return (see #add_java_property)
    def create_java_property(pd)
      JavaProperty.new(pd, self)
    end

    # Defines methods _aliaz_ and _aliaz=_ which calls the standard _attribute_ and
    # _attribute=_ accessor methods, resp.
    # Calling rather than aliasing the attribute accessor allows the aliaz accessor to
    # reflect a change to the attribute accessor.
    def delegate_to_property(aliaz, property)
      ra, wa = property.accessors
      if aliaz == ra then raise MetadataError.new("Cannot delegate #{self} #{aliaz} to itself.") end
      define_method(aliaz) { send(ra) }
      define_method("#{aliaz}=".to_sym) { |value| send(wa, value) }
      register_property_alias(aliaz, property.attribute)
    end
  end
end
