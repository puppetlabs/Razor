require "mongo"
require "set"

module ProjectRazor
  module Persist
    # MongoDB version of {ProjectRazor::Persist::PluginInterface}
    # used by {ProjectRazor::Persist::Controller} when ':mongo' is the 'persist_mode' in
    # ProjectRazor configuration
    class MongoPlugin < PluginInterface
      include(ProjectRazor::Logging)

      # Closes connection if it is active
      #
      # @return [Boolean] Connection status
      #
      def teardown
        logger.debug "Connection teardown"
        @connection.active? && disconnect
        @connection.active?
      end

      # Establishes connection to MongoDB
      #
      # @param hostname [String]
      # @param port [Integer]
      # @param username [String] Username that will be used to authenticate to the host
      # @param password [String] Password that will be used to authenticate to the host
      # @param timeout [Integer] Connection timeout
      # @return [Boolean] Connection status
      #
      def connect(hostname, port, username, password, timeout)
        logger.debug "Connecting to MongoDB (#{hostname}:#{port}) with timeout (#{timeout})"
        begin
          @connection = Mongo::Connection.new(hostname, port, { :connect_timeout => timeout })
        rescue Mongo::ConnectionTimeoutError
          logger.error "Mongo::ConnectionTimeoutError"
          return false
        rescue Mongo::ConnectionError
          logger.error "Mongo::ConnectionError"
          return false
        rescue Mongo::ConnectionFailure
          logger.error "Mongo::ConnectionFailure"
          return false
        rescue Mongo::OperationTimeout
          logger.error "Mongo::OperationTimeout"
          return false
        end
        @razor_database = @connection.db("project_razor")
        @connection.active?
      end

      # Disconnects connection
      #
      # @return [Boolean] Connection status
      #
      def disconnect
        logger.debug "Disconnecting from MongoDB"
        @connection.close
        @connection.active?
      end

      # Checks whether DB 'ProjectRazor' is selected in MongoDB
      #
      # @return [Boolean] Connection status
      #
      def is_db_selected?
        #logger.debug "Is ProjectRazor DB selected?(#{(@razor_database != nil and @connection.active?)})"
        (@razor_database != nil and @connection.active?)
      end


      # Returns the newest/unique documents from the collection named 'collection_name'
      # All older/duplicate documents are removed from the collection.
      #
      # @param collection_name [Symbol]
      # @return [Array<Hash>]
      #
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

      # Returns the entry keyed by the '@uuid' of the given 'object_doc' from the collection
      # named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] or nil if the object cannot be found
      #
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

      # Adds or updates 'obj_document' in the collection named 'collection_name' with an incremented
      # '@version' value
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] The updated doc
      #
      def object_doc_update(object_doc, collection_name)
        logger.debug "Update document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        # We use this to always pull newest
        object_doc["@version"] = get_next_version(object_doc, collection_name)
        collection_by_name(collection_name).insert(object_doc)
        # Remove all older versions
        object_doc
      end

      # Adds or updates multiple object documents in the collection named 'collection_name'. This will
      # increase the '@version' value of all the documents
      #
      # @param object_docs [Array<Hash>]
      # @param collection_name [Symbol]
      # @return [Array<Hash>] The updated documents
      #
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

      # Removes a document identified by from the '@uuid' of the given 'object_doc' from the
      # collection named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [true] - returns 'true' if an object was removed
      #
      def object_doc_remove(object_doc, collection_name)
        logger.debug "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        while collection_by_name(collection_name).find({ "@uuid" => object_doc["@uuid"] }).count > 0
          unless collection_by_name(collection_name).remove({ "@uuid" => object_doc["@uuid"] })
            return false
          end
        end
        true
      end

      # Removes all documents from the collection named 'collection_name'
      #
      # @param collection_name [Symbol]
      # @return [Boolean] - returns 'true' if all entries were successfully removed
      #
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


