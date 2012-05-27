require "yaml"
require "extlib"
require "singleton"

# This class is the interface to all querying and saving of objects for ProjectRazor
module ProjectRazor
  class Data
    include Singleton
    include(ProjectRazor::Utility)
    include(ProjectRazor::Logging)
    include(ProjectRazor::Filtering)

    # {ProjectRazor::Config::Server} object for {ProjectRazor::Data}
    # {ProjectRazor::Controller} object for {ProjectRazor::Data}
    attr_accessor :persist_ctrl

    # Initializes our {ProjectRazor::Data} object
    #  Attempts to load {ProjectRazor::Configuration} and initialize {ProjectRazor::Persist::Controller}
    def initialize
      logger.debug "Initializing object"
      load_config
      setup_persist
    end

    def check_init
      load_config
      setup_persist if !@persist_ctrl || !@persist_ctrl.check_connection
    end

    def config
      load_config
      @razor_config
    end

    # Called when work with {ProjectRazor::Data} is complete
    def teardown
      logger.debug "Teardown called"
      @persist_ctrl.teardown
    end

    # Fetches documents from database, converts to objects, and returns within an [Array]
    #
    # @param [Symbol] object_symbol
    # @return [Array]
    def fetch_all_objects(object_symbol)
      logger.debug "Fetching all objects (#{object_symbol})"
      object_array = []
      object_hash_array = persist_ctrl.object_hash_get_all(object_symbol)
      object_hash_array.each { |object_hash| object_array << object_hash_to_object(object_hash) }
      object_array
    end

    # Fetches a document from database with a specific 'uuid', converts to an object, and returns it
    #
    # @param [Symbol] object_symbol
    # @param [String] object_uuid
    # @return [Object, nil]
    def fetch_object_by_uuid(object_symbol, object_uuid)
      logger.debug "Fetching object by uuid (#{object_uuid}) in collection (#{object_symbol})"
      fetch_all_objects(object_symbol).each do
      |object|
        return object if object.uuid == object_uuid
      end
      nil
    end

    # Fetches a document from database with a specific 'uuid'. This form uses partial matching of 'uuid' and only returns if a single entry matches otherwise it returns nil
    #
    # @param [Symbol] object_symbol
    # @param [String] object_uuid
    # @return [Object, nil]
    def fetch_object_by_uuid_pattern(object_symbol, object_uuid_pattern)
      logger.debug "Fetching object by pattern  (#{object_uuid_pattern}) in collection (#{object_symbol})"
      found_objects = []
      fetch_all_objects(object_symbol).each do
      |object|
        scan_array = object.uuid.scan(object_uuid_pattern)
        found_objects << object if scan_array.count > 0
        #return object if object.uuid == object_uuid
      end
      if found_objects.count == 1
        found_objects.first
      else
        nil
      end

    end

    # Fetches a document from database using a filter hash - which matches any objects using ProjectRazor::Filtering module
    #
    # @param [Symbol] object_symbol
    # @param [Hash] object_filter
    # @return [Object, nil]
    def fetch_objects_by_filter(object_symbol, object_filter)
      logger.debug "Fetching objects by filter (#{object_filter}) in collection (#{object_symbol})"
      object_array = []
      fetch_all_objects(object_symbol).each do
      |object|
        object_array << object if check_filter_vs_hash(object_filter, object.to_hash)
      end
      object_array
    end

    # Takes an {ProjectRazor::Object} and creates/persists it within the database.
    # @note If {ProjectRazor::Object} already exists it is simply updated
    #
    # @param [ProjectRazor::Object] object
    # @return [ProjectProjectRazor::Object] returned object is a copy of passed {ProjectRazor::Object} with bindings enabled for {ProjectRazor::ProjectRazor#refresh_self} and {ProjectRazor::ProjectRazor#update_self}
    def persist_object(object)
      logger.debug "Persisting an object (#{object.uuid})"
      persist_ctrl.object_hash_update(object.to_hash, object._collection)
      object._persist_ctrl = persist_ctrl
      object.refresh_self
      object
    end

    # Removes all {ProjectRazor::Object}'s that exist in the collection name given
    #
    # @param [Symbol] object_symbol The name of the collection
    # @return [true, false]
    def delete_all_objects(object_symbol)
      logger.debug "Deleting all objects (#{object_symbol})"
      persist_ctrl.object_hash_remove_all(object_symbol)
    end

    # Removes specific {ProjectRazor::Object} that exist in the collection name given
    #
    # @param [ProjectProjectRazor::Object] object The {ProjectRazor::Object} to delete
    # @return [true, false]
    def delete_object(object)
      logger.debug "Deleting an object (#{object.uuid})"
      persist_ctrl.object_hash_remove(object.to_hash, object._collection)
    end

    # Removes specific {ProjectRazor::Object} that exist in the collection name with given 'uuid'
    #
    # @param [Symbol] object_symbol The name of the collection
    # @param [String] object_uuid The 'uuid' of the {ProjectRazor::Object}
    # @return [true, false]
    def delete_object_by_uuid(object_symbol, object_uuid)
      logger.debug "Deleting an object by uuid (#{object_uuid} #{object_symbol}"
      fetch_all_objects(object_symbol).each do
      |object|
        return persist_ctrl.object_hash_remove(object.to_hash, object_symbol) if object.uuid == object_uuid
      end
      false
    end





    # Takes a [Hash] from a {ProjectRazor::Persist:Controller} document and converts back into an {ProjectRazor::Object}
    # @api private
    # @param [Hash] object_hash The hash of the object
    # @return [ProjectRazor::Object, ProjectRazor]
    def object_hash_to_object(object_hash)
      #logger.debug "Converting object hash to object (#{object_hash['@classname']})"
      begin
      object = ::Object::full_const_get(object_hash["@classname"]).new(object_hash)
      object._persist_ctrl = @persist_ctrl
      object
      rescue => e
        logger.error "Couldn't not convert: #{object_hash.inspect} back to object(#{e.message})"
        raise e
      end
    end

    # Initiates the {ProjectRazor::Persist::Controller} for {ProjectRazor::Data}
    # @api private
    #
    # @return [ProjectRazor::Persist::Controller, ProjectRazor]
    def setup_persist
      logger.debug "Persist controller init"
      @persist_ctrl = ProjectRazor::Persist::Controller.new(config)
    end

    # Attempts to load the './conf/razor_server.conf' YAML file into @config
    # @api private
    #
    # @return [ProjectRazor::Config::Server, ProjectRazor]
    def load_config
      logger.debug "Loading config at (#{$config_server_path}"
      loaded_config = nil
      if File.exist?($config_server_path)
        begin
          conf_file = File.open($config_server_path)
          #noinspection RubyResolve,RubyResolve
          loaded_config = YAML.load(conf_file)
            # We catch the basic root errors
        rescue SyntaxError
          logger.warn "SyntaxError loading (#{$config_server_path})"
          loaded_config = nil
        rescue StandardError
          logger.warn "Generic error loading (#{$config_server_path})"
          loaded_config = nil
        ensure
          conf_file.close
        end
      end

      # If our object didn't load we run our config reset
      if loaded_config.is_a?(ProjectRazor::Config::Server)
        if loaded_config.validate_instance_vars
          @razor_config = loaded_config
        else
          logger.warn "Config parameter validation error loading (#{$config_server_path})"
          logger.warn "Resetting (#{$config_server_path}) and loading default config"
          reset_config
        end
      else
        logger.warn "Cannot load (#{$config_server_path})"

        reset_config
      end
    end

    # Creates new 'razor_server.conf' if one does not already exist
    # @api private
    #
    # @return [ProjectRazor::Config::Server, ProjectRazor]
    def reset_config
      logger.warn "Resetting (#{$config_server_path}) and loading default config"
      # use default init
      new_conf = ProjectRazor::Config::Server.new

      # Very important that we only write the file if it doesn't exist as we may not be the only thread using it
      unless File.exist?($config_server_path)
        begin
          new_conf_file = File.new($config_server_path, 'w+')
          new_conf_file.write(("#{new_conf_header}#{YAML.dump(new_conf)}"))
          new_conf_file.close
          logger.info "Default config saved to (#{$config_server_path})"
        rescue
          logger.error "Cannot save default config to (#{$config_server_path})"
        end
      end
      @razor_config = new_conf
    end

    # Returns a header for new 'razor_server.conf' files
    # @api private
    #
    # @return [ProjectRazor::Config::Server, ProjectRazor]
    def new_conf_header
      "\n# This file is the main configuration for ProjectRazor\n#\n# -- this was system generated --\n#\n#\n"
    end

  end
end
