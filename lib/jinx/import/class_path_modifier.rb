module Jinx
  # Helper class which adds files to the Java class path.
  class ClassPathModifier
    # Adds the directories in the given path and all Java jar files contained in
    # the directories to the Java classpath.
    #
    # @quirk Java The jar files found by this method are added to the classpath
    # in sort order. Java applications usually add jars in sort order. For examle,
    # the Apache Ant directory-based classpath tasks are in sort order, although
    # this is not stipulated in the documentation. Well-behaved Java libraries are
    # not dependent on the sort order of included jar files. For poorly-behaved
    # Java libraries, ensure that the classpath is in the expected order. If the
    # classpath must be in a non-sorted order, then call {#add_to_classpath}
    # on each jar file instead.
    #
    # @param [String] path the colon or semi-colon separated directories
    def expand_to_class_path(path)
      # the path separator
      sep = path[WINDOWS_PATH_SEP] ? WINDOWS_PATH_SEP : UNIX_PATH_SEP
      # the path directories
      dirs = path.split(sep).map { |dir| File.expand_path(dir) }
      expanded = expand_jars(dirs)
      expanded.each { |dir| add_to_classpath(dir) }
    end

    # Adds the given jar file or directory to the classpath.
    #
    # @param [String] file the jar file or directory to add
    def add_to_classpath(file)
      unless File.exist?(file) then
        logger.warn("File to place on Java classpath does not exist: #{file}")
        return
      end
      if File.extname(file) == '.jar' then
        # require is preferred to classpath append for a jar file.
        require file
      else
        # A directory must end in a slash since JRuby uses an URLClassLoader.
        if File.directory?(file) then
          last = file[-1, 1]
          if last == "\\" then
            file = file[0...-1] + '/'
          elsif last != '/' then
            file = file + '/'
          end
        end
        # Append the file to the classpath.
        $CLASSPATH << file
      end
    end

    private
  
    # The Windows semi-colon path separator.
    WINDOWS_PATH_SEP = ';'
  
    # The Unix colon path separator.
    UNIX_PATH_SEP = ':'
    
    # Expands the given directories to include the contained jar files.
    # If a directory contains jar files, then the jar files are included in
    # the resulting array. Otherwise, the directory itself is included in
    # the resulting array.
    #
    # @param [<String>] directories the directories containing jars to add
    # @return [<String>] each directory or its jars
    def expand_jars(directories)
      # If there are jar files, then the file list is the sorted jar files.
      # Otherwise, the file list is a singleton directory array.
      expanded = directories.map do |dir|
        jars = Dir[File.join(dir , "**", "*.jar")].sort
        jars.empty? ? [dir] : jars
      end
      expanded.flatten
    end
  end
end  