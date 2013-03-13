module ProjectRazor
  module Persist
    # Stores key/value pairs in the form of uuid and hashes. The hash is typically stored as a
    # JSON or BSON impage. The storage also maintains an integer version which is incremented every
    # time that the value is updated.
    # @abstract
    class PluginInterface
      # Closes connection if it is active
      #
      # @return [Boolean] Connection status
      #
      def teardown
        raise NotImplementedError
      end

      # Establishes connection to the data store.
      #
      # @param hostname [String] DNS name or IP-address of host
      # @param port [Integer] Port number to use when connecting to the host
      # @param username [String] Username that will be used to authenticate to the host
      # @param password [String] Password that will be used to authenticate to the host
      # @param timeout [Integer] Connection timeout
      # @return [Boolean] Connection status
      #
      def connect(hostname, port, username, password, timeout)
        raise NotImplementedError
      end

      # Disconnects connection
      #
      # @return [Boolean] Connection status
      #
      def disconnect
        raise NotImplementedError
      end

      # Checks whether the database is connected and active
      #
      # @return [Boolean] Connection status
      #
      def is_db_selected?
        raise NotImplementedError
      end

      # Returns all entries from the collection named 'collection_name'
      #
      # @param collection_name [Symbol]
      # @return [Array<Hash>]
      #
      def object_doc_get_all(collection_name)
        raise NotImplementedError
      end

      # Returns the entry keyed by the '@uuid' of the given 'object_doc' from the collection
      # named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] or nil if the object cannot be found
      #
      def object_doc_get_by_uuid(object_doc, collection_name)
        raise NotImplementedError
      end

      # Adds or updates 'obj_document' in the collection named 'collection_name' with an incremented
      # '@version' value
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] The updated doc
      #
      def object_doc_update(object_doc, collection_name)
        raise NotImplementedError
      end

      # Adds or updates multiple object documents in the collection named 'collection_name'. This will
      # increase the '@version' value of all the documents
      #
      # @param object_docs [Array<Hash>]
      # @param collection_name [Symbol]
      # @return [Array<Hash>] The updated documents
      #
      def object_doc_update_multi(object_docs, collection_name)
        raise NotImplementedError
      end

      # Removes a document identified by from the '@uuid' of the given 'object_doc' from the
      # collection named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Boolean] - returns 'true' if an object was removed
      #
      def object_doc_remove(object_doc, collection_name)
        raise NotImplementedError
      end

      # Removes all documents from the collection named 'collection_name'
      #
      # @param collection_name [Symbol]
      # @return [Boolean] - returns 'true' if all entries were successfully removed
      #
      def object_doc_remove_all(collection_name)
        raise NotImplementedError
      end
    end
  end
end
