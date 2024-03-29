require 'jinx/helpers/transitive_closure'
require 'jinx/metadata'

module Jinx
  # Importer extends a module with Java class import support. Importer is an aspect
  # of a {Metadata} module. Including +Metadata+ in an application domain module
  # extends that module with Importer capability.
  #
  # The Importer module imports a Java class or interface on demand by referencing
  # the class name in the context of the module.
  # The imported class {Metadata} is introspected.
  #
  # Import on demand is induced by a reference to the class.
  # The +family+ example illustrates a domain package extended
  # with metadata capability. The first non-definition reference to +Family::Parent+
  # imports the Java class +family.Parent+ into the JRuby class wrapper
  # +Family+ and introspects the Java property meta-data.
  module Importer
    # Declares that the given {Resource} classes will be dynamically modified.
    # This method introspects the classes, if necessary.
    #
    # @param [<Class>] classes the classes to augment
    def shims(*classes)
      # Nothing to do, since all this method does is ensure that the arguments are
      # introspected when they are referenced.
    end
    
    # Returns whether the given Java class or interface is imported into this
    # domain module. This method imports the class or interface on demand.
    #
    # @param [Module] the class to check
    # @return [Boolean] whether the class or interface is imported into this
    #   domain module
    def contains?(klass)
      # Import a domain class on demand by referencing the class base name in the context
      # of this module. If the class name can be resolved, then also check that it
      # was introspected. Primitive classes like String can be resolved, but are not
      # introspected. Domain classes are introspected when the name is resolved.
      (!!const_get(klass.name.demodulize) rescue false) and @introspected.include?(klass)
    end
    
    # Imports a Java class constant on demand. If the class does not already
    # include this module's mixin, then the mixin is included in the class.
    #
    # @param [Symbol, String] sym the missing constant
    # @return [Class] the imported class
    # @raise [NameError] if the symbol is not an importable Java class
    def const_missing(sym)
      # Load the class definitions in the source directory, if necessary.
      # If a load is performed as a result of referencing the given symbol,
      # then dereference the class constant again after the load, since the class
      # might have been loaded or referenced during the load.
      unless defined? @introspected then
        configure_importer
        load_definitions
        return const_get(sym)
      end
      
      # Append the symbol to the package to make the Java class name.
      logger.debug { "Detecting whether #{sym} is a #{self} Java class..." }
      klass = @packages.detect_value do |pkg|
        begin
           java_import "#{pkg}.#{sym}"
        rescue NameError
          nil
        end
      end
      if klass then
        logger.debug { "Added #{klass} to the #{self} module." }
      else
        # Not a Java class; print a log message and pass along the error.
        logger.debug { "#{sym} is not recognized as a #{self} Java class." }
        super
      end
      
      # Introspect the Java class meta-data, if necessary.
      unless introspected?(klass) then
        add_metadata(klass)
        # Print the class meta-data.
        logger.info(klass.pp_s)
      end
      
      klass
    end
    
    # @param [String] the module name to resolve in the context of this module
    # @return [Module] the corresponding module
    # @raise [NameError] if the name cannot be resolved
    def module_for_name(name)
      begin
        # Incrementally resolve the module.
        name.split('::').inject(self) { |ctxt, mod| ctxt.const_get(mod) }
      rescue NameError
        # If the application domain module set the parent module i.v.. then continue
        # the look-up in that parent importer.
        raise unless @parent_importer
        mod = @parent_importer.module_for_name(name)
        if mod then
          logger.debug { "Module #{name} found in #{qp} parent module #{@parent_importer}." }
        end
        mod
      end
    end
    
    private
    
    # Initializes this importer on demand. This method is called the first time a class
    # is referenced.
    def configure_importer
      # The default package conforms to the JRuby convention for mapping a package name
      # to a module name.
      @packages ||= [name.split('::').map { |n| n.downcase }.join('.')]
      @packages.each do |pkg|
        begin
          eval "java_package Java::#{pkg}"
        rescue Exception => e
          raise ArgumentError.new("#{self} Java package #{pkg} not found - #{$!}")
        end
      end
      # The introspected classes.
      @introspected = Set.new
      # The name => file hash for file definitions that are not in the packages.
      @unresolved_defs = {}
    end
    
    # If the given *names* argument is empty, then returns the package names.
    # Otherwise, sets the package names. The default package conforms to the JRuby convention
    # for mapping a package name to a module name, e.g. the +MyApp::Domain+ default package
    # is +myapp.domain+. Clients set the package if it differs from the default.
    #
    # @param [<String>] name the package names
    def packages(*names)
      names.empty? ? @packages : @packages = names
    end
    
    # Alias for the common case of a single package.
    alias :package :packages

    # If the given *directories* argument is empty, then return the definition directories.
    # Otherwise, set the definitions.
    #
    # @param [<String>] directories the Ruby class definitions directories
    # @return [<String>] the definition directories
    def definitions(*directories)
      directories.empty? ? @definitions : @definitions = directories
    end
    
    def load_definitions
      return if @definitions.nil_or_empty?
      # Load the class definitions in the source directories.
      @definitions.each { |dir| load_dir(File.expand_path(dir)) }
      # Print each introspected class's content.
      @introspected.sort { |k1, k2| k1.name <=> k2.name }.each { |klass| logger.info(klass.pp_s) }
      true
    end
    
    # Loads the Ruby source files in the given directory.
    #
    # @param [String] dir the source directory
    def load_dir(dir)
      logger.debug { "Loading the class definitions in #{dir}..." }
      # Import the classes.
      srcs = sources(dir)
      # Introspect and load the classes in reverse class order, i.e. superclass before subclass.
      klasses = srcs.keys.transitive_closure { |k| [k.superclass] }.select { |k| srcs[k] }.reverse
      # Introspect the classes as necessary.
      klasses.each { |klass| add_metadata(klass) unless introspected?(klass) }
      # Load the classes.
      klasses.each do |klass|
        file = srcs[klass]
        load_definition(klass, file)
      end
      logger.debug { "Loaded the class definitions in #{dir}." }
    end
    
    def load_definition(klass, file)
      logger.debug { "Loading the #{klass.qp} definition #{file}..." }
      begin
        require file
      rescue Exception
        logger.error("Could not load the #{klass} definition #{file} - " + $!)
        raise
      end
      logger.debug { "Loaded the #{klass.qp} definition #{file}." }
    end

    # @param [String] dir the source directory
    # @return [{Class => String}] the source class => file hash
    def sources(dir)
      # the domain class definitions
      files = Dir.glob(File.join(dir, "*.rb"))
      # Infer each class symbol from the file base name.
      # Ignore files which do not resolve to a class.
      files.to_compact_hash do |file|
        name = File.basename(file, ".rb").camelize
        klass = resolve_class(name)
        if klass.nil? then
          logger.debug { "The class definition file #{file} does not correspond to a class in the standard #{qp} packages." }
          @unresolved_defs[name] = file
        end
        klass
      end.invert
    end
    
    # @param [String] name the demodulized class name
    # @param [String] package the Java package, or nil for all packages
    # @return [Class, nil] the {Resource} class imported into this module,
    #   or nil if the class cannot be resolved
    def resolve_class(name, package=nil)
      if const_defined?(name) then
        return const_get(name)
      end
      if package.nil? then
        return @packages.detect_value { |pkg| resolve_class(name, pkg) }
      end
      # Append the class name to the package to make the Java class name.
      full_name = "#{package}.#{name}"
      # If the class is already imported, then java_import returns nil. In that case,
      # evaluate the Java class.
      begin
        java_import(full_name)
      rescue
        module_eval("Java::#{full_name}") rescue nil
      end
    end
    
    # Introspects the given class meta-data.
    #
    # @param [Class] klass the Java class or interface to introspect
    def add_metadata(klass)
      logger.debug("Adding #{self}::#{klass.qp} metadata...")
      # Mark the class as introspected. Do this first to preclude a recursive loop back
      # into this method when the references are introspected below.
      @introspected << klass
      # Add the superclass meta-data if necessary.
      add_superclass_metadata(klass)
      # Include this resource module into the class, unless this has already occurred.
      unless klass < self then
        m = self
        klass.class_eval { include m }
      end
      # Import the class into this resource module, unless this has already occurred.
      name = klass.name.demodulize
      unless const_defined?(name) then
        java_import(klass.java_class.name)
      end
      # Add introspection capability to the class.
      md_mod = @metadata_module || Metadata
      logger.debug { "Extending #{self}::#{klass.qp} with #{md_mod.name}..." }
      klass.extend(md_mod)
      # Set the class domain module.
      klass.domain_module = self
      # Introspect the Java properties.
      klass.introspect
      # Add the {attribute => value} initializer.
      klass.add_attribute_value_initializer if Class === klass
      # Add referenced domain class metadata as necessary.
      klass.each_property do |prop|
        ref = prop.type
        if ref.nil? then raise MetadataError.new("#{self} #{prop} domain type is unknown.") end
        if introspectible?(ref) then
          logger.debug { "Introspecting the #{klass.qp} #{prop} reference type #{ref.qp}..." }
          add_metadata(ref)
        end
      end
      # If the class has a definition file but does not resolve to a standard package, then
      # load it now based on the demodulized class name match.
      file = @unresolved_defs[name]
      load_definition(klass, file) if file
      
      logger.debug("#{self}::#{klass.qp} metadata added.")
    end
    
    def add_superclass_metadata(klass)
      if Class === klass then
        sc = klass.superclass
        add_metadata(sc) unless introspected?(sc) or sc == Java::java.lang.Object
      end
    end
    
    # @param [Class] the class to check
    # @return [Boolean] whether the class is an introspected {Resource} class
    def introspected?(klass)
       klass < Resource and klass.introspected?
    end
                               
    # @param [Class] klass the class to check                          
    # @return [Boolean] whether the given class has a Java package among this module's
    #  {#packages} and has not yet been introspected
    def introspectible?(klass)
      not introspected?(klass) and Class === klass and @packages.include?(klass.java_class.package.name)
    end
  end
end