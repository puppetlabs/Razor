require "mongo"
require "set"

# MongoDB version of ProjectRazor::Controller::Plugin
# used by ProjectRazor::Controller when ':mongo' is the 'persist_mode' in ProjectRazor configuration
module ProjectRazor
  module Persist
    class MongoPlugin
      include(ProjectRazor::Logging)

      # Closes connection if it is active
      # @return [true, false] - returns connection status
      def teardown
        logger.debug "Connection teardown"
        @connection.active? && disconnect
        @connection.active?
      end

      # Establishes connection to MongoDB
      # @param hostname [String]
      # @param port [String]
      # @param suppress_logging [Boolean]  Used to suppress logging when this method
      # is called from outside of the main Razor thread of execution (for example,
      # in the starting section of the razor_daemon.rb script, before the main Razor
      # process has been forked off as a separate daemon process)
      # @return [true, false] - returns connection status
      def connect(hostname, port, timeout, suppress_logging = false)
        logger.debug "Connecting to MongoDB (#{hostname}:#{port}) with timeout (#{timeout})" unless suppress_logging
        begin
          @connection = Mongo::Connection.new(hostname, port, { :connect_timeout => timeout })
        rescue Mongo::ConnectionTimeoutError
          logger.error "Mongo::ConnectionTimeoutError" unless suppress_logging
          return false
        rescue Mongo::ConnectionError
          logger.error "Mongo::ConnectionError" unless suppress_logging
          return false
        rescue Mongo::ConnectionFailure
          logger.error "Mongo::ConnectionFailure" unless suppress_logging
          return false
        rescue Mongo::OperationTimeout
          logger.error "Mongo::OperationTimeout" unless suppress_logging
          return false
        end
        @razor_database = @connection.db("project_razor")
        @connection.active?
      end

      # Disconnects connection
      # @return [true, false] - returns connection status
      def disconnect
        logger.debug "Disconnecting from MongoDB"
        @connection.close
        @connection.active?
      end

      # Checks whether DB 'ProjectRazor' is selected in MongoDB
      # @return [true, false]
      def is_db_selected?
        #logger.debug "Is ProjectRazor DB selected?(#{(@razor_database != nil and @connection.active?)})"
        (@razor_database != nil and @connection.active?)
      end


      # From [Array] of documents return [Array] containing newest/unique documents
      # this also takes all older/duplicate documents and calls [cleanup_old_documents] to remove them
      # @param collection_name [Symbol]
      # @return [Array]
      def object_doc_get_all(collection_name)
        collection_by_name(collection_name).create_index("@version") #ensure index on version
        logger.debug "Get all documents from collection (#{collection_name})"
        objects_set   = Set.new # Set to hold uuid's for version checking. Using a Set for speed reasons.
        old_objects   = [] # outdated versions of objects
        objects_array = [] # objects to return
        this          = collection_by_name(collection_name).find().sort("@version", -1).to_a
        this.each do
        |object|
          if objects_set.add?(object['@uuid'])
            objects_array << object
          else
            old_objects << object
          end
        end
        cleanup_old_docs(old_objects, collection_name) if old_objects.count > 0 # only run clean if we need to
        remove_mongo_keys(objects_array)
      end

      def object_doc_get_by_uuid(object_doc, collection_name)
        collection_by_name(collection_name).create_index("@uuid") #ensure index on uuid
        logger.debug "Get document from collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        object_array = collection_by_name(collection_name).find("@uuid" => object_doc["@uuid"]).sort("@version", -1).to_a
        if object_array.count > 0
          object_array[0]
        else
          nil
        end
      end


      # Adds object document to the collection with an incremented "@version" key
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] - returns the updated [Hash] of doc
      def object_doc_update(object_doc, collection_name)
        logger.debug "Update document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        # We use this to always pull newest
        object_doc["@version"] = get_next_version(object_doc, collection_name)
        collection_by_name(collection_name).insert(object_doc)
        # Remove all older versions
        object_doc
      end

      def object_doc_update_multi(object_docs, collection_name)
        logger.debug "Update documents in collection (#{collection_name})"
        # We use this to always pull newest
        object_docs.each do
        |object_doc|
          object_doc["@version"] = get_next_version(object_doc, collection_name)
        end
        collection_by_name(collection_name).insert(object_docs)
        object_docs
      end

      # Removes all documents from collection: 'collection_name' with 'uuid' in 'object_doc''
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
              # @return [true, Hash] - returns 'true' if successful, otherwise returns 'Hash' with last error
      def object_doc_remove(object_doc, collection_name)
        logger.debug "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        while collection_by_name(collection_name).find({ "@uuid" => object_doc["@uuid"] }).count > 0
          unless collection_by_name(collection_name).remove({ "@uuid" => object_doc["@uuid"] })
            return false
          end
        end
        true
      end

      def object_doc_remove_all(collection_name)
        logger.debug "Remove all documents in collection (#{collection_name})"
        while collection_by_name(collection_name).count > 0
          unless collection_by_name(collection_name).remove()
            return false
          end
        end
        true
      end


      private # Mongo internal stuff we don't want exposed'

      # Gets the current version number and returns an incremented value, or returns '1' if none exists
      # @param object_doc [Hash]
      # @param collection_name [String]
      def get_next_version(object_doc, collection_name)
        logger.debug "Get next version number for document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        object_array =collection_by_name(collection_name).find("@uuid" => object_doc["@uuid"]).sort("@version", -1).to_a
        if object_array.count < 1
          version = 0
        else
          version = object_array[0]["@version"]
        end
        version += 1
        version
      end

      # Takes [Array] of docs and removes MongoDB specific keys
      # @param object_doc_array [Array]
      # @return [Array]
      def remove_mongo_keys(object_doc_array)
        logger.debug "Strip MongoDB keys from document"
        object_doc_array.each do
        |object_doc|
          # remove the doc "_id" key as it won't match an instance variable
          object_doc.delete("_id")
          # remove timestamp also
          object_doc.delete("_timestamp")
        end

        object_doc_array # return modified object_doc_array
      end

      # Takes an [Array] of docs and removes each from collection: 'collection_name'
      # @param old_object_doc_array [Array]
      # @param collection_name [Symbol]
      def cleanup_old_docs(old_object_doc_array, collection_name)
        logger.debug "Clean up old documents"
        # iterate over each old doc
        old_object_doc_array.each do
        |old_object_doc|
          # Remove it from MongoDB by referencing '_id' key
          collection_by_name(collection_name).remove({ "_id" => old_object_doc["_id"] })
        end
      end

      # Returns corresponding MongoDB Collection to 'collection_name'
      # @param collection_name [Symbol]
      # @return [Mongo::Collection]
      def collection_by_name(collection_name)
        if is_db_selected?
          @razor_database.collection(collection_name.to_s)
        else
          raise "DB appears to be down"
        end
      end

    end
  end
end


