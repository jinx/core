require 'forwardable'
require 'jinx/helpers/inflector'
require 'jinx/helpers/pretty_print'
require 'jinx/helpers/validation'
require 'jinx/helpers/collections'
require 'jinx/helpers/collector'
require 'jinx/importer'
require 'jinx/resource/matcher'
require 'jinx/resource/mergeable'
require 'jinx/resource/reference_enumerator'
require 'jinx/resource/reference_visitor'
require 'jinx/resource/reference_path_visitor'
require 'jinx/resource/inversible'

module Jinx
  # This Resource module enhances application domain classes with the following features:
  # * meta-data introspection
  # * dependency
  # * inverse integrity
  # * defaults
  # * validation
  # * copy/merge
  #
  # A application domain module becomes jinxed by including {Resource} and specifying
  # the Java package and optional JRuby class mix-in definitions.
  #
  # @example
  #   # The application domain module
  #   module Domain
  #     include Jinx::Resource  
  #     # The caTissue Java package name.
  #     packages 'app.domain'
  #     # The JRuby mix-ins directory.
  #     definitions File.expand_path('domain', dirname(__FILE__))
  #   end
  module Resource
    include Mergeable, Inversible
    
    # @quirk JRuby Bug #5090 - JRuby 1.5 object_id is no longer a reserved method, and results
    #   in a String value rather than an Integer (cf. http://jira.codehaus.org/browse/JRUBY-5090).
    #   Work-around is to make a proxy object id.
    #
    # @return [Integer] the object id
    def proxy_object_id
      # make a hash code on demand
      @_hc ||= (Object.new.object_id * 31) + 17
    end
    
    # Prints this object's class demodulized name and object id.
    def print_class_and_id
      "#{self.class.qp}@#{proxy_object_id}"
    end

    alias :qp :print_class_and_id

    # Sets the default attribute values for this domain object and its dependents. If this Resource
    # does not have an identifier, then missing attributes are set to the values defined by
    # {Propertied#add_attribute_defaults}.
    #
    # Subclasses should override the private {#add_defaults_local} method rather than this method.
    #
    # @return [Resource] self
    def add_defaults
      # If there is an owner, then delegate to the owner.
      # Otherwise, add defaults to this object.
      par = owner
      if par and par.identifier.nil? then
        logger.debug { "Adding defaults to #{qp} owner #{par.qp}..." }
        par.add_defaults
      else
        logger.debug { "Adding defaults to #{qp} and its dependents..." }
        # apply the local and dependent defaults
        add_defaults_recursive
      end
      self
    end

    # Validates this domain object and its #{#dependents} for consistency and completeness.
    # An object is valid if it contains a non-nil value for each mandatory attribute.
    # Objects which have already been validated are skipped.
    #
    # A Resource class should not override this method, but override the private {#validate_local}
    # method instead.
    #
    # @return [Resource] this domain object
    # @raise (see #validate_local)
    def validate
      if not @validated then
        validate_local
        @validated = true
      end
      dependents.each { |dep| dep.validate }
      self
    end   

    # Returns a new domain object with the given attributes copied from this domain object.
    # The attributes argument consists of either attribute Symbols or a single Enumerable
    # consisting of Symbols.
    # The default attributes are the {Propertied#nondomain_attributes}.
    #
    # @param [<Symbol>, (<Symbol>)] attributes the attributes to copy
    # @return [Resource] a copy of this domain object
    def copy(*attributes)
      if attributes.empty? then
        attributes = self.class.nondomain_attributes
      elsif Enumerable === attributes.first then
        Jinx.fail(ArgumentError, "#{qp} copy attributes argument is not a Symbol: #{attributes.first}") unless attributes.size == 1
        attributes = attributes.first
      end
      self.class.new.merge_attributes(self, attributes)
    end

    # Clears the given attribute value. If the current value responds to the +clear+ method,
    # then the current value is cleared. Otherwise, the value is set to {Metadata#empty_value}.
    #
    # @param [Symbol] attribute the attribute to clear
    def clear_attribute(attribute)
      # the current value to clear
      current = send(attribute)
      return if current.nil?
      # call the current value clear if possible.
      # otherwise, set the attribute to the empty value.
      if current.respond_to?(:clear) then
        current.clear
      else
        writer = self.class.property(attribute).writer
        value = self.class.empty_value(attribute)
        send(writer, value)
      end
    end

    # Sets this domain object's attribute to the value. This method clears the current attribute value,
    # if any, and merges the new value. Merge rather than assignment ensures that a collection type
    # is preserved, e.g. an Array value is assigned to a set domain type by first clearing the set
    # and then merging the array content into the set.
    #
    # @see Mergeable#merge_attribute
    def set_property_value(attribute, value)
      # bail out if the value argument is the current value
      return value if value.equal?(send(attribute))
      clear_attribute(attribute)
      merge_attribute(attribute, value)
    end
    
    # Returns the first non-nil {#key_value} for the primary, secondary
    # and alternate key attributes.
    #
    # @return (see #key_value)
    def key(attributes=nil)
      primary_key or secondary_key or alternate_key
    end
    
    # Returns the key for the given key attributes as follows:
    # * If there are no key attributes, then nil.
    # * Otherwise, if any key attribute value is missing, then nil.
    # * Otherwise, if the key attributes is a singleton Array, then the key is the
    #   value of the sole key attribute.
    # * Otherwise, the key is an Array of the key attribute values.
    #
    # @param [<Symbol>] attributes the key attributes, or nil for the primary key
    # @return [Array, Object, nil] the key value or values
    def key_value(attributes)
      attributes ||= self.class.primary_key_attributes
      case attributes.size
      when 0 then nil
      when 1 then send(attributes.first)
      else
        key = attributes.map { |pa| send(pa) || return }
        key unless key.empty?
      end
    end
    
    # @return (see #key_value)
    def primary_key
      key_value(self.class.primary_key_attributes)
    end

    # @return (see #key_value)
    # @see #key
    def secondary_key
      key_value(self.class.secondary_key_attributes)
    end

    # @return (see #key_value)
    # @see #key
    def alternate_key
      key_value(self.class.alternate_key_attributes)
    end

    # @return [Resource, nil] the domain object that owns this object, or nil if this object
    #   is not dependent on an owner
    def owner
      self.class.owner_attributes.detect_value { |pa| send(pa) }
    end

    # @return [(Property, Resource), nil] the (property, value) pair for which there is an
    # owner reference, or nil if this domain object does not reference an owner
    def effective_owner_property_value
      self.class.owner_properties.detect_value do |op|
        ref = send(op.attribute)
        [op, ref] if ref
      end
    end
    
    # Sets this dependent's owner attribute to the given domain object.
    #
    # @param [Resource] owner the owner domain object
    # @raise [NoMethodError] if this Resource's class does not have exactly one owner attribute
    def owner=(owner)
      pa = self.class.owner_attribute
      if pa.nil? then Jinx.fail(NoMethodError, "#{self.class.qp} does not have a unique owner attribute") end
      set_property_value(pa, owner)
    end

    # @param [Resource] other the domain object to check
    # @return [Boolean] whether the other domain object is this object's {#owner} or an
    #  {#owner_ancestor?} of this object's {#owner}
    def owner_ancestor?(other)
      ownr = self.owner
      ownr and (ownr == other or ownr.owner_ancestor?(other))
    end
    
    # @param [Resource] other the domain object to check
    # @return [Boolean] whether the other domain object is a dependent of this object
    #  and has an update-only non-domain attribute.
    def dependent_update_only?(other)
      other.owner == self and
      other.class.nondomain_attributes.detect_with_property { |prop| prop.updatable? and not prop.creatable? }
    end

    # Returns an attribute => value hash for the specified attributes with a non-nil, non-empty value.
    # The default attributes are this domain object's class {Propertied#attributes}.
    # Only non-nil attributes defined by this Resource are included in the result hash.
    #
    # @param [<Symbol>, nil] attributes the attributes to merge
    # @return [{Symbol => Object}] the attribute => value hash
    def value_hash(attributes=nil)
      attributes ||= self.class.attributes
      attributes.to_compact_hash { |pa| send(pa) if self.class.method_defined?(pa) }
    end

    # Returns the domain object references for the given attributes.
    #
    # @param [<Symbol>, nil] the domain attributes to include, or nil to include all domain attributes
    # @return [<Resource>] the referenced attribute domain object values
    def references(attributes=nil)
      attributes ||= self.class.domain_attributes
      attributes.map { |pa| send(pa) }.flatten.compact
    end

    # @return [Boolean] whether this domain object is dependent on another entity
    def dependent?
      self.class.dependent?
    end

    # @return [Boolean] whether this domain object is not dependent on another entity
    def independent?
      not dependent?
    end
    
    # Returns this domain object's dependents. Dependents which have an alternate preferred
    # owner, as described in {#effective_owner_property_value}, are not included in the
    # result.
    # 
    # @param [<Property>, Property, nil] property the dependent property or properties
    #   (default is all dependent properties)
    # @return [Enumerable] this domain object's direct dependents
    def dependents(properties=nil)
      properties ||= self.class.dependent_attributes.properties
      # Make a reference enumerator that selects only those dependents which do not have
      # an alternate preferred owner.
      ReferenceEnumerator.new(self, properties).filter do |dep|
        # dep is a candidate dependent. dep could have a preferred owner which differs
        # from self. If there is a different preferred owner, then don't call the
        # iteration block.
        oref = dep.owner
        oref.nil? or oref == self
      end
    end
    
    # Returns the attributes which are required for save. This base implementation returns the
    # class {Propertied#mandatory_attributes}. Subclasses can override this method
    # for domain object state-specific refinements.
    #
    # @return [<Symbol>] the required attributes for a save operation
    def mandatory_attributes
      self.class.mandatory_attributes
    end

    # Returns the attribute references which directly depend on this owner.
    # The default is the attribute value.
    #
    # Returns an Enumerable. If the value is not already an Enumerable, then this method
    # returns an empty array if value is nil, or a singelton array with value otherwise.
    #
    # If there is more than one owner of a dependent, then subclasses should override this
    # method to select dependents whose dependency path is shorter than an alternative
    # dependency path, e.g. if a Node is owned by both a Graph and a parent
    # Node. In that case, the Graph direct dependents consist of the top-level nodes
    # owned by the Graph but not referenced by another Node.
    #
    # @param [Symbol] attribute the dependent attribute
    # @return [<Resource>] the attribute value, wrapped in an array if necessary
    def direct_dependents(attribute)
      deps = send(attribute)
      case deps
        when Enumerable then deps
        when nil then Array::EMPTY_ARRAY
        else [deps]
      end
    end

    # @param [Resource] the domain object to match
    # @return [Boolean] whether this object matches the fetched other object on class
    #   and a primary, secondary or alternate key
    def matches?(other)
      # trivial case
      return true if equal?(other)
      # check the type
      return false unless self.class == other.class
      # match on primary, secondary or alternate key
      matches_key_attributes?(other, self.class.primary_key_attributes) or
      matches_key_attributes?(other, self.class.secondary_key_attributes) or
      matches_key_attributes?(other, self.class.alternate_key_attributes)
    end

    # Matches this dependent domain object with the others on type and key attributes
    # in the scope of a parent object.
    # Returns the object in others which matches this domain object, or nil if none.
    #
    # The match attributes are, in order:
    # * the primary key
    # * the secondary key
    # * the alternate key
    #
    # This domain object is matched against the others on the above attributes in succession
    # until a unique match is found. The key attribute matches are strict, i.e. each
    # key attribute value must be non-nil and match the other value.
    #
    # @param [<Resource>] the candidate domain object matches
    # @return [Resource, nil] the matching domain object, or nil if no match
    def match_in(others)
      # trivial case: self is in others
      return self if others.include?(self)
      # filter for the same type
      unless others.all? { |other| self.class === other } then
        others = others.filter { |other| self.class === other }
      end
      # match on primary, secondary or alternate key
      match_unique_object_with_attributes(others, self.class.primary_key_attributes) or
      match_unique_object_with_attributes(others, self.class.secondary_key_attributes) or
      match_unique_object_with_attributes(others, self.class.alternate_key_attributes)
    end

    # Returns the match of this domain object in the scope of a matching owner as follows:
    # * If {#match_in} returns a match, then that match is the result is used.
    # * Otherwise, if this is a dependent attribute then the match is attempted on a
    #   secondary key without owner attributes. Defaults are added to this object in order
    #   to pick up potential secondary key values.
    #
    # @param (see #match_in)
    # @return (see #match_in)
    def match_in_owner_scope(others)
      match_in(others) or others.detect { |other| matches_without_owner_attribute?(other) }
    end

    # @return [{Resouce => Resource}] a source => target hash of the given sources which match
    #   the targets using the {#match_in} method
    def self.match_all(sources, targets)
      DEF_MATCHER.match(sources, targets)
    end

    # Returns the difference between this Persistable and the other Persistable for the
    # given attributes. The default attributes are the {Propertied#nondomain_attributes}.
    #
    # @param [Resource] other the domain object to compare
    # @param [<Symbol>, nil] attributes the attributes to compare
    # @return (see Hashable#diff)
    def diff(other, attributes=nil)
      attributes ||= self.class.nondomain_attributes
      vh = value_hash(attributes)
      ovh = other.value_hash(attributes)
      vh.diff(ovh) { |key, v1, v2| Resource.value_equal?(v1, v2) }
    end

    # Returns the domain object in others which matches this dependent domain object
    # within the scope of a parent on a minimally acceptable constraint. This method
    # is used when this object might be partially complete--say, lacking a secondary key
    # value--but is expected to match one of the others, e.g. when matching a referenced
    # object to its fetched counterpart.
    #
    # This base implementation returns whether the following conditions hold:
    # 1. other is the same class as this domain object
    # 2. if both identifiers are non-nil, then they are equal
    #
    # Subclasses can override this method to impose additional minimal consistency constraints.
    #
    # @param [Resource] other the domain object to match against
    # @return [Boolean] whether this Resource equals other
    def minimal_match?(other)
      self.class === other and
        (identifier.nil? or other.identifier.nil? or identifier == other.identifier)
    end

    # Returns an enumerator on the transitive closure of the reference attributes.
    # If a block is given to this method, then the block called on each reference determines
    # which attributes to visit. Otherwise, all saved references are visited.
    #
    # @yield [ref] reference visit attribute selector
    # @yieldparam [Resource] ref the domain object to visit
    # @return [Enumerable] the reference transitive closure
    def reference_hierarchy
      ReferenceVisitor.new { |ref| yield ref }.to_enum(self)
    end

    # Returns the value for the given attribute path Array or String expression, e.g.:
    #   study.path_value("site.address.state")
    # follows the +study+ -> +site+ -> +address+ -> +state+ accessors and returns the +state+
    # value, or nil if any intermediate reference is nil.
    # The array form for the above example is:
    #  study.path_value([:site, :address, :state])
    #
    # @param [<Symbol>] path the attributes to navigate
    # @return the attribute navigation result
    def path_value(path)
      path = path.split('.').map { |pa| pa.to_sym } if String === path
      path.inject(self) do |parent, pa|
        value = parent.send(pa)
        return if value.nil?
        value
      end
    end

    # Applies the operator block to this object and each domain object in the reference path.
    # This method visits the transitive closure of each recursive path attribute.
    #
    # @param [<Symbol>] path the attributes to visit
    # @yieldparam [Symbol] attribute the attribute to visit
    # @return the visit result
    # @see ReferencePathVisitor
    def visit_path(*path, &operator)
      visitor = ReferencePathVisitor.new(self.class, path)
      visitor.visit(self, &operator)
    end

    # Applies the operator block to the transitive closure of this domain object's dependency relation.
    # The block argument is a dependent.
    #
    # @yield [dep] operation on the visited domain object
    # @yieldparam [Resource] dep the domain object to visit 
    def visit_dependents(&operator) # :yields: dependent
      DEPENDENT_VISITOR.visit(self, &operator)
    end

    # Applies the operator block to the transitive closure of this domain object's owner relation.
    #
    # @yield [dep] operation on the visited domain object
    # @yieldparam [Resource] dep the domain object to visit 
    def visit_owners(&operator) # :yields: owner
      ref = owner
      yield(ref) and ref.visit_owners(&operator) if ref
    end

    # @param q the PrettyPrint queue 
    # @return [String] the formatted content of this Resource
    def pretty_print(q)
      q.text(qp)
      content = printable_content
      q.pp_hash(content) unless content.empty?
    end

    # Prints this domain object's content and recursively prints the referenced content.
    # The optional selector block determines the attributes to print. The default is the
    # {Propertied#java_attributes}.
    #
    #
    # TODO caRuby override to do_without_lazy_loader
    # 
    # @yield [owner] the owner attribute selector
    # @yieldparam [Resource] owner the domain object to print
    # @return [String] the domain object content
    def dump(&selector)
      DetailPrinter.new(self, &selector).pp_s
    end

    # Prints this domain object in the format:
    #   class_name@object_id{attribute => value ...}
    # The default attributes include identifying attributes.
    #
    # @param [<Symbol>] attributes the attributes to print
    # @return [String] the formatted content
    def to_s(attributes=nil)
      content = printable_content(attributes)
      content_s = content.pp_s(:single_line) unless content.empty?
      "#{print_class_and_id}#{content_s}"
    end

    alias :inspect :to_s

    # Returns this domain object's attributes content as an attribute => value hash
    # suitable for printing.
    #
    # The default attributes are this object's saved attributes. The optional
    # reference_printer is used to print a referenced domain object.
    #
    # @param [<Symbol>, nil] attributes the attributes to print
    # @yield [ref] the reference print formatter 
    # @yieldparam [Resource] ref the referenced domain object to print
    # @return [{Symbol => String}] the attribute => content hash
    def printable_content(attributes=nil, &reference_printer)
      attributes ||= printworthy_attributes
      vh = value_hash(attributes)
      vh.transform_value { |value| printable_value(value, &reference_printer) }
    end

    # Returns whether value equals other modulo the given matches according to the following tests:
    # * _value_ == _other_
    # * _value_ and _other_ are Resource instances and _value_ is a {#match?} with _other_.
    # * _value_ and _other_ are Enumerable with members equal according to the above conditions.
    # * _value_ and _other_ are DateTime instances and are equal to within one second.
    #
    # The DateTime comparison accounts for differences in the Ruby -> Java -> Ruby roundtrip
    # of a date attribute, which loses the seconds fraction.
    #
    # @return [Boolean] whether value and other are equal according to the above tests
    def self.value_equal?(value, other, matches=nil)
      value = value.to_ruby_date if Java::JavaUtil::Date === value
      other = other.to_ruby_date if Java::JavaUtil::Date === other
      if value == other then
        true
      elsif value.collection? and other.collection? then
        collection_value_equal?(value, other, matches)
      elsif Date === value and Date === other then
        (value - other).abs.floor.zero?
      elsif Resource === value and value.class === other then
        value.matches?(other)
      elsif matches then
        matches[value] == other
      else
        false
      end
    end
    
    protected

    # Returns whether this Resource's attribute value matches the given value.
    # A domain attribute match is determined by {#match?}.
    # A non-domain attribute match is determined by an equality comparison.
    #
    # @param [Symbol] attribute the attribute to match
    # @param value the value to compare
    # @return [Boolean] whether the values match
    def matches_attribute_value?(attribute, value)
      v = send(attribute)
      Resource === v ? value.matches?(v) : value == v
    end

    # @return [<Symbol>] the required attributes for this domain object which are nil or empty
    def missing_mandatory_attributes
      mandatory_attributes.select { |pa| send(pa).nil_or_empty? }
    end
    
    # Adds the default values to this object, if necessary, and its dependents.
    # 
    # @see #each_defaultable_reference
    def add_defaults_recursive
      # Add the local defaults.
      add_defaults_local
      # Recurse to the dependents.
      each_defaultable_reference { |ref| ref.add_defaults_recursive }
    end

    private

    # The copy merge call options.
    # @private
    COPY_MERGE_OPTS = {:inverse => false}

    # The dependent attribute visitor.
    #
    # @see #visit_dependents
    # @private
    DEPENDENT_VISITOR = Jinx::ReferenceVisitor.new { |obj| obj.class.dependent_attributes }

    DEF_MATCHER = Matcher.new
    
    # Extends the including module with an {Importer}.
    #
    # @param [Module] mod the module which includes this Resource mix-in
    def self.included(mod)
      super
      mod.extend(Importer)
    end

    # Sets the default attribute values for this domain object. Unlike {#add_defaults}, this
    # method does not set defaults for dependents. This method sets the configuration values
    # for this domain object as described in {#add_defaults}, but does not set defaults for
    # dependents.
    #
    # This method is the integration point for subclasses to augment defaults with programmatic
    # logic. If a subclass overrides this method, then it should call super before setting the
    # local default attributes. This ensures that configuration defaults takes precedence.
    def add_defaults_local
      logger.debug { "Adding defaults to #{qp}..." }
      merge_attributes(self.class.defaults)
    end
    
    # Validates that this domain object is internally consistent.
    # Subclasses override this method for additional validation, but should call super first.
    #
    # @see #validate_mandatory_attributes
    # @see #validate_owner
    def validate_local
      validate_mandatory_attributes
      validate_owner
    end
    
    # Validates that this domain object contains a non-nil value for each mandatory attribute.
    #
    # @raise [ValidationError] if a mandatory attribute value is missing
    def validate_mandatory_attributes
      invalid = missing_mandatory_attributes
      unless invalid.empty? then
        logger.error("Validation of #{qp} unsuccessful - missing #{invalid.join(', ')}:\n#{dump}")
        Jinx.fail(ValidationError, "Required attribute value missing for #{self}: #{invalid.join(', ')}")
      end
      validate_owner
    end
    
    # Validates that this domain object either doesn't have an owner attribute or has a unique
    # effective owner.
    #
    # @raise [ValidationError] if there is an owner reference attribute that is not set
    # @raise [ValidationError] if there is more than effective owner
    def validate_owner
      # If there is an unambigous owner, then we are done.
      return unless owner.nil?
      # If there is more than one owner attribute, then check that there is at most one
      # unambiguous owner reference. The owner method returns nil if the owner is ambiguous.
      if self.class.owner_attributes.size > 1 then
        vh = value_hash(self.class.owner_attributes)
        if vh.size > 1 then
          Jinx.fail(ValidationError, "Dependent #{self} references multiple owners #{vh.pp_s}:\n#{dump}")
        end
      end
      # If there is an owner reference attribute, then there must be an owner.
      if self.class.bidirectional_dependent? then
        Jinx.fail(ValidationError, "Dependent #{self} does not reference an owner")
      end
    end
    
    # Enumerates referenced domain objects for setting defaults. This base implementation
    # includes the {#dependents}. Subclasses can override this# method to add references
    # which should be defaulted or to set the order in which defaults are applied.
    #
    # @yield [dep] operate on the dependent
    # @yieldparam [<Resource>] dep the dependent to which the defaults are applied
    def each_defaultable_reference(&block)
      dependents.each(&block)
    end

    def self.collection_value_equal?(value, other, matches=nil)
      value.size == other.size and value.all? { |v| other.include?(v) or (matches and other.include?(matches[v])) }
    end

    # A DetailPrinter formats a domain object value for printing using {#to_s} the first time the object
    # is encountered and a ReferencePrinter on the object subsequently.
    # @private
    class DetailPrinter
      alias :to_s :pp_s

      alias :inspect :to_s

      # Creates a DetailPrinter on the base object.
      def initialize(base, visited=Set.new, &selector)
        @base = base
        @visited = visited << base
        @selector = selector || Proc.new { |ref| ref.class.printable_attributes }
      end

      def pretty_print(q)
        q.text(@base.qp)
        # pretty-print the standard attribute values
        pas = @selector.call(@base)
        content = @base.printable_content(pas) do |ref|
          if @visited.include?(ref) then
            ReferencePrinter.new(ref)
          else
            DetailPrinter.new(ref, @visited) { |ref| @selector.call(ref) }
          end
        end
        q.pp_hash(content)
      end
    end

    # A ReferencePrinter formats a reference domain object value for printing with just the class and Ruby object_id.
    # @private
    class ReferencePrinter
      extend Forwardable

      def_delegator(:@base, :qp, :to_s)

      alias :inspect :to_s

      # Creates a ReferencePrinter on the base object.
      def initialize(base)
        @base = base
      end
    end

    # Returns a value suitable for printing. If value is a domain object, then the block provided to this method is called.
    # The default block creates a new ReferencePrinter on the value.
    def printable_value(value, &reference_printer)
      Jinx::Collector.on(value) do |item|
        if Resource === item then
          block_given? ? yield(item) : printable_value(item) { |ref| ReferencePrinter.new(ref) }
        else
          item
        end
      end
    end

    # Returns an attribute => value hash which identifies the object.
    # If this object has a complete primary key, than the primary key attributes are returned.
    # Otherwise, if there are secondary key attributes, then they are returned.
    # Otherwise, if there are nondomain attributes, then they are returned.
    # Otherwise, if there are fetched attributes, then they are returned.
    #
    # @return [<Symbol] the attributes to print
    def printworthy_attributes
      if self.class.primary_key_attributes.all? { |pa| !!send(pa) } then
        self.class.primary_key_attributes
      elsif not self.class.secondary_key_attributes.empty? then
        self.class.secondary_key_attributes
      elsif not self.class.nondomain_java_attributes.empty? then
        self.class.nondomain_java_attributes
      else
        self.class.fetched_attributes
      end
    end

    # Returns whether this domain object matches the other domain object as follows:
    # * The classes are the same.
    # * There are not conflicting primary key values.
    # * Each non-owner secondary key value matches.
    #
    # Note that objects without a secondary key match.
    # 
    # @param (see #match_in)
    # @return [Boolean] whether there is a non-owner match
    def matches_without_owner_attribute?(other)
      return false unless other.class == self.class
      # check the primary key
      return false unless self.class.primary_key_attributes.all? do |ka|
        kv = send(ka)
        okv = other.send(ka)
        kv.nil? or okv.nil? or kv == okv
      end
      # match on the non-owner secondary key
      oas = self.class.owner_attributes
      self.class.secondary_key_attributes.all? do |ka|
        oas.include?(ka) or other.matches_attribute_value?(ka, send(ka))
      end
    end

    # @param [Property] prop the attribute to set
    # @param [Resource] ref the inverse value
    # @param [Symbol] the inverse => self writer method
    def delegate_to_inverse_setter(prop, ref, writer)
      logger.debug { "Setting #{qp} #{prop} by setting the #{ref.qp} inverse attribute #{prop.inverse}..." }
      ref.send(writer, self)
    end

    # Returns 0 if attribute is a Java primitive number,
    # +false+ if attribute is a Java primitive boolean,
    # an empty collectin if the Java attribute is a collection,
    # nil otherwise.
    def empty_value(attribute)
      type = java_type(attribute) || return
      if type.primitive? then
        type.name == 'boolean' ? false : 0
      else
        self.class.empty_value(attribute)
      end
    end

    # Returns the Java type of the given attribute, or nil if attribute is not a Java property attribute.
    def java_type(attribute)
      prop = self.class.property(attribute)
      prop.property_descriptor.attribute_type if JavaProperty === prop
    end
    
    # Returns the source => target hash of matches for the given prop newval sources and
    # oldval targets. If the matcher block is given, then that block is called on the sources
    # and targets. Otherwise, {Resource.match_all} is called.
    #
    # @param [Property] prop the attribute to match
    # @param newval the source value
    # @param oldval the target value
    # @yield [sources, targets] matches sources to targets
    # @yieldparam [<Resource>] sources an Enumerable on the source value
    # @yieldparam [<Resource>] targets an Enumerable on the target value
    # @return [{Resource => Resource}] the source => target matches
    def match_attribute_value(prop, newval, oldval)
      # make Enumerable targets and sources for matching
      sources = newval.to_enum
      targets = oldval.to_enum
      
      # match sources to targets
      unless oldval.nil_or_empty? then
        logger.debug { "Matching source #{newval.qp} to target #{qp} #{prop} #{oldval.qp}..." }
      end
      matches = block_given? ? yield(sources, targets) : Resource.match_all(sources, targets)
      logger.debug { "Matched #{qp} #{prop}: #{matches.qp}." } unless matches.empty?
      matches
    end
    
    # @param [<Symbol>] attributes the attributes to match
    # @return [Boolean] whether there is a non-nil value for each attribute and the value matches
    #   the other attribute value
    def matches_key_attributes?(other, attributes)
      return false if attributes.empty?
      attributes.all? do |pa|
        v = send(pa)
        if v.nil? then
          false
        else
          ov = other.send(pa)
          Resource === v ? v.matches?(ov) : v == ov
        end
      end
    end
    
    # Returns the object in others which uniquely matches this domain object on the given attributes,
    # or nil if there is no unique match. This method returns nil if any attributes value is nil.
    def match_unique_object_with_attributes(others, attributes)
      vh = value_hash(attributes)
      return if vh.empty? or vh.size < attributes.size
      matches = others.select do |other|
        self.class == other.class and
          vh.all? { |pa, v| other.matches_attribute_value?(pa, v) }
      end
      matches.first if matches.size == 1
    end

    # Returns the attribute => value hash to use for matching this domain object as follows:
    # * If this domain object has a database identifier, then the identifier is the sole match criterion attribute.
    # * Otherwise, if a secondary key is defined for the object's class, then those attributes are used.
    # * Otherwise, all attributes are used.
    #
    # If any secondary key value is nil, then this method returns an empty hash, since the search is ambiguous.
    def search_attribute_values
      # if this object has a database identifier, then the identifier is the search criterion
      identifier.nil? ? non_id_search_attribute_values : { :identifier => identifier }
    end

    # Returns the attribute => value hash to use for matching this domain object.
    # @see #search_attribute_values the method specification
    def non_id_search_attribute_values
      # if there is a secondary key, then search on those attributes.
      # otherwise, search on all attributes.
      key_props = self.class.secondary_key_attributes
      pas = key_props.empty? ? self.class.nondomain_java_attributes : key_props
      # associate the values
      attr_values = pas.to_compact_hash { |pa| send(pa) }
      # if there is no secondary key, then cull empty values
      key_props.empty? ? attr_values.delete_if { |pa, value| value.nil? } : attr_values
    end
  end
end