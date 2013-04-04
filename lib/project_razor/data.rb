require 'project_razor/utility'
require 'project_razor/logging'
require 'project_razor/persist/controller'

require "yaml"
require "singleton"

# This class is the interface to all querying and saving of objects for ProjectRazor
module ProjectRazor
  class Data
    include Singleton
    include(ProjectRazor::Utility)
    include(ProjectRazor::Logging)

    # {ProjectRazor::Config::Server} object for {ProjectRazor::Data}
    # {ProjectRazor::Controller} object for {ProjectRazor::Data}
    attr_accessor :persist_ctrl

    # Initializes our {ProjectRazor::Data} object
    #  Attempts to load {ProjectRazor::Configuration} and initialize {ProjectRazor::Persist::Controller}
    def initialize
      logger.debug "Initializing object"
      setup_persist
    end

    def check_init
      setup_persist if !@persist_ctrl || !@persist_ctrl.check_connection
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
      persist_ctrl.object_hash_get_all(object_symbol).map do |object_hash|
        object_hash_to_object(object_hash)
      end
    end

    # Fetches a document from database with a specific 'uuid', converts to an object, and returns it
    #
    # @param [Symbol] object_symbol
    # @param [String] object_uuid
    # @return [Object, nil]
    def fetch_object_by_uuid(object_symbol, object_uuid)
      logger.debug "Fetching object by uuid (#{object_uuid}) in collection (#{object_symbol})"
      object_hash = persist_ctrl.object_hash_get_by_uuid({"@uuid" => object_uuid}, object_symbol)
      if object_hash
        object_hash_to_object(object_hash)
      else
        nil
      end
    end

    # Fetches a document from database with a specific 'uuid'. This form uses partial matching of 'uuid' and only returns if a single entry matches otherwise it returns nil
    #
    # @param [Symbol] object_symbol
    # @param [String] object_uuid
    # @return [Object, nil]
    def fetch_object_by_uuid_pattern(object_symbol, object_uuid_pattern)
      logger.debug "Fetching object by pattern  (#{object_uuid_pattern}) in collection (#{object_symbol})"
      found_objects = fetch_all_objects(object_symbol).select do |object|
        object.uuid.include?(object_uuid_pattern)
      end
      if found_objects.count == 1
        found_objects.first
      else
        nil
      end

    end

    # Fetches a document from database using a filter hash - which matches any objects using `check_filter_vs_hash`
    #
    # @param [Symbol] object_symbol
    # @param [Hash] object_filter
    # @return [Object, nil]
    def fetch_objects_by_filter(object_symbol, object_filter)
      logger.debug "Fetching objects by filter (#{object_filter}) in collection (#{object_symbol})"
      fetch_all_objects(object_symbol).select do |object|
        check_filter_vs_hash(object_filter, object.to_hash)
      end
    end

    # Takes an {ProjectRazor::Object} and creates/persists it within the database.
    # @note If {ProjectRazor::Object} already exists it is simply updated
    #
    # @param [ProjectRazor::Object, Array] object
    # @return [ProjectProjectRazor::Object] returned object is a copy of passed {ProjectRazor::Object} with bindings enabled for {ProjectRazor::ProjectRazor#refresh_self} and {ProjectRazor::ProjectRazor#update_self}
    def persist_object(object, options = {})
      if object.class == Array
        logger.debug "Persisting a set of objects (#{object.count})"
        unless options[:multi_collection]
          raise ProjectRazor::Error::MissingMultiCollectionOnGroupPersist, "Missing namespace on multiple object  persist"
        end
        persist_ctrl.object_hash_update_multi(object.map {|o| o.to_hash }, options[:multi_collection])
        object.each {|o| o._persist_ctrl = persist_ctrl && (o.refresh_self if options[:refresh])}
        object.each {|o| o.refresh_self} if options[:refresh]
      else
        logger.debug "Persisting an object (#{object.uuid})"
        persist_ctrl.object_hash_update(object.to_hash, object._namespace)
        object._persist_ctrl = persist_ctrl
        object.refresh_self if options[:refresh]
      end
      object
    end

    alias :persist_objects :persist_object

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
      persist_ctrl.object_hash_remove(object.to_hash, object._namespace)
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
      @persist_ctrl = ProjectRazor::Persist::Controller.new
    end


    # Uses a provided Filter Hash to match against an Object hash
    # @param filter_hash [Hash]
    # @param object_hash [Hash]
    def check_filter_vs_hash(filter_hash, object_hash, loop = false)
      object_hash = sanitize_hash(object_hash)
      filter_hash = sanitize_hash(filter_hash)
      # Iterate over each key/value checking if there is a match within the object_hash level
      # if we run into a key/value that is a hash we check for a matching hash and call this same method
      filter_hash.each_key do |filter_key|
        logger.debug "looking for key: #{filter_key}"
        # Find a matching key / return false if there is none

        unless object_hash.has_key? filter_key
          logger.debug "not found: #{filter_key}"
          return false
        end

        logger.debug "found: #{filter_key} #{object_hash.class.to_s}"

        # If our keys match and the values are Hashes then iterate again catching the return and
        # passing if it is False
        if filter_hash[filter_key].class == Hash && object_hash[filter_key].class == Hash
          # Check deeper, setting the loop value to prevent changing the key prefix
          logger.debug "both values are hash, going deeper"
          return false if !check_filter_vs_hash(filter_hash[filter_key], object_hash[filter_key], true)
        else

          # Eval if our keys (one of which isn't a Hash) match
          # We accept either exact or Regex match
          # If the filter key value is empty we are ok with it just existing and return true

          if filter_hash[filter_key] != ""
            begin
              logger.debug "Looking for match: #{filter_hash[filter_key]} : #{object_hash[filter_key]}"
              if filter_hash[filter_key].class == Hash || object_hash[filter_key].class == Hash
                logger.debug "one of these is a hash when the other isn't"
                return false
              end

              # If the filter_hash[filter_key] value is a String and it starts with 'regex:'
              # then use a regular expression for comparison; else compare as literals
              if filter_hash[filter_key].class == String && filter_hash[filter_key].start_with?('regex:')
                regex_key = filter_hash[filter_key].sub(/^regex:/,"")
                if Regexp.new(regex_key).match(object_hash[filter_key]) == nil
                  logger.debug "no match - regex"
                  return false
                end
              else
                if filter_hash[filter_key] != object_hash[filter_key]
                  logger.debug "no match - literal"
                  return false
                end
              end
            rescue => e
              # Error encountered - likely nil or Hash -> String / return false as this means key != key
              logger.error e.message
              return false
            end
          end
        end
      end
      logger.debug "match found"
      true
    end
  end
end
