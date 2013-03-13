require "securerandom"
require "pg"

module ProjectRazor
  module Persist
    # PostgreSQL version of {ProjectRazor::Persist::PluginInterface}
    # used by {ProjectRazor::Persist::Controller} when ':postgres' is the 'persist_mode'
    # in ProjectRazor configuration
    class PostgresPlugin < PluginInterface
      include(ProjectRazor::Logging)
      def initialize
        @statements = Set.new # Set to keep track of named prepared statements
      end

      # Closes connection if it is active
      #
      # @return [Boolean] Connection status
      #
      def teardown
        logger.debug "Connection teardown"
        @connection.finished? or disconnect
        not @connection.finished?
      end

      # Establishes connection to PostgreSQL database with the name "project_razor". The
      # database will be created if it doesn't exist.
      #
      # @param hostname DNS name or IP-address of host
      # @param port [Integer] Port number to use when connecting to the host
      # @param username [String] Username that will be used to authenticate to the host
      # @param password [String] Password that will be used to authenticate to the host
      # @param timeout [Integer] Connection timeout
      # @return [Boolean] Connection status
      #
      def connect(hostname, port, username, password, timeout)
        logger.debug "Connecting to PostgreSQL (#{username}@#{hostname}:#{port}) with timeout (#{timeout})"
        dbname = "project_razor"
        begin
          @connection = PG::Connection.new(:host => hostname, :port => port, :connect_timeout => timeout, :dbname => dbname, :user => username, :password => password)
        rescue PG::Error => e
          if e.message.include? 'database "' + dbname + '" does not exist'
            @connection = create_database(hostname, port, dbname, timeout)
          else
            logger.error e.message
            raise
          end
        end
        @connection.db == dbname
      end

      # Disconnects connection
      #
      # @return [Boolean] Connection status
      #
      def disconnect
        logger.debug "Disconnecting from PostgreSQL server"
        @statements.clear
        @connection.close
        not @connection.finished?
      end

      # Checks whether the database is connected and active
      #
      # @return [Boolean] Connection status
      #
      def is_db_selected?
        @connection != nil and not @connection.finished?
      end

      # Returns all entries from the collection named 'collection_name'
      #
      # @param collection_name [Symbol]
      # @return [Array<Hash>]
      #
      def object_doc_get_all(collection_name)
        statement_name = "all:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'SELECT value::varchar FROM ' + table_for_collection(collection_name))
        end
        exec_select_on_collection(statement_name, [])
      end

      # Returns the entry keyed by the '@uuid' of the given 'object_doc' from the collection
      # named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] or nil if the object cannot be found
      #
      def object_doc_get_by_uuid(object_doc, collection_name)
        uuid = object_doc['@uuid']
        statement_name = "one:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'SELECT value::varchar FROM ' + table_for_collection(collection_name) + ' WHERE id = $1::' + id_type_for(collection_name).downcase)
        end
        hits = exec_select_on_collection(statement_name, [unpack_uuid(uuid)])
        return hits.count == 0 ? nil : hits[0]
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
        ensure_prepared_update_statements(collection_name)
        transaction{|conn|insert_or_update(conn, object_doc, collection_name)}
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
        ensure_prepared_update_statements(collection_name)
        transaction do
          |conn|
          object_docs.each do
            |object_doc| insert_or_update(conn, object_doc, collection_name)
          end
        end
        object_docs
      end

      # Removes a document identified by from the '@uuid' of the given 'object_doc' from the
      # collection named 'collection_name'
      #
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Boolean] - returns 'true' if an object was removed
      #
      def object_doc_remove(object_doc, collection_name)
        statement_name = "delete:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'DELETE FROM ' + table_for_collection(collection_name) + ' WHERE id = $1::' + id_type_for(collection_name))
        end
        result = nil
        transaction {|conn| result = conn.exec_prepared(statement_name, [unpack_uuid(object_doc['@uuid'])])}
        return result.cmd_tuples() == 1
      end

      # Removes all documents from the collection named 'collection_name'
      #
      # @param collection_name [Symbol]
      # @return [Boolean] - returns 'true' if successful
      #
      def object_doc_remove_all(collection_name)
        statement_name = "delete_all:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'DELETE FROM ' + table_for_collection(collection_name))
        end
        transaction {|conn|conn.exec_prepared(statement_name)}
        return true
      end

      private # PostgreSQL internal stuff we don't want exposed'

      SQLSTATE_NO_SUCH_TABLE = '42P01'

      # Return the SQLSTATE string from the given error
      #
      # @param error [PG::Error]
      # @return [String] The sqlstate
      #
      def sqlstate(error)
        error.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      end

      # Create the database used for storing collections
      #
      # @param hostname DNS name or IP-address of host
      # @param port [Integer] Port number to use when connecting to the host
      # @param username [String] Username that will be used to authenticate to the host
      # @param password [String] Password that will be used to authenticate to the host
      # @param dbname Name of the database
      # @param timeout [Integer] Connection timeout
      # @return [PG::Connection] A connection to the new database
      #
      def create_database(hostname, port, username, password, dbname, timeout)
        pg_conn = PG::Connection.new(:host => hostname, :port => port, :connect_timeout => timeout, :dbname => "postgres", :user => username, :password => password)
        begin
          pg_conn.exec('CREATE DATABASE ' + dbname)
        ensure
          pg_conn.close
        end
        PG::Connection.new(:host => hostname, :port => port, :connect_timeout => timeout, :dbname => dbname, :user => username, :password => password)
      end

      # If the version is 0, then fetch the record from the table associated with the 'collection_name'. If
      # no record is found, the object_doc is inserted and given the version 1. If a record is found, then
      # the object_doc receives the version from that record + 1 and is updated.
      #
      # If the version is not 0, then it will be incremented by one and the corresponding record in the
      # table will be updated.
      #
      # @param conn [PG::Connection] The connection for the current the transaction
      # @param object_doc [Hash] The document to update
      # @param collection_name [Symbol] The name of the collection where the document is stored
      # @return The updated document (with new version)
      #
      def insert_or_update(conn, object_doc, collection_name)
        encoded_object_doc = Utility.encode_symbols_in_hash(object_doc)

        if encoded_object_doc['@version'] == 0 || collection_name == :active
          # obtain the version if possible
          version = table_fetch_version(conn, encoded_object_doc['@uuid'], collection_name)
          return table_insert(conn, encoded_object_doc, collection_name) if version === nil
          encoded_object_doc['@version'] = version
        end
        table_update(conn, encoded_object_doc, collection_name)
      end

      # Fetch the current version for the given 'uuid' from the collection named 'collection_name'
      #
      # @param conn [PG::Connection] The connection for the current the transaction
      # @param uuid [String] The uuid to fetch the version for
      # @param collection_name [Symbol] The name of the collection where the document is stored
      # @return The document or nil if not found
      #
      def table_fetch_version(conn, uuid, collection_name)
        raise ArgumentError.new("document has no uuid") if uuid === nil
        statement_name = "version:#{collection_name}"
        hits = conn.exec_prepared(statement_name, [unpack_uuid(uuid)], 0)
        return  hits.count == 0 ? nil : hits.getvalue(0,0).to_i
      end

      # Insert document into table
      #
      # @param conn [PG::Connection] The connection for the current the transaction
      # @param object_doc [Hash] The document to insert
      # @param collection_name [Symbol] The name of the collection where the document is stored
      # @return The updated document (with version 1)
      #
      def table_insert(conn, object_doc, collection_name)
        uuid = object_doc['@uuid']
        if uuid != nil
          uuid = unpack_uuid(uuid)
        else
          uuid = SecureRandom.uuid.to_s
          object_doc['@uuid'] = pack_uuid(uuid)
        end

        object_doc['@version'] = 1
        begin
          conn.exec_prepared("insert:#{collection_name}", [uuid, JSON.generate(object_doc)]);
        rescue Exception => e
          object_doc['@version'] = 0
          raise e
        end
        object_doc
      end

      # Update document in table
      #
      # @param conn [PG::Connection] The connection for the current the transaction
      # @param object_doc [Hash] The document to update
      # @param collection_name [Symbol] The name of the collection where the document is stored
      # @return The updated document (with new version)
      #
      def table_update(conn, object_doc, collection_name)
        # Obtain current version and increase it in the document that we are about to save
        uuid = unpack_uuid(object_doc['@uuid'])
        version = object_doc['@version']

        object_doc['@version'] = version + 1
        begin
          result = conn.exec_prepared("update:#{collection_name}", [uuid, version,  JSON.generate(object_doc)])
          if result.cmd_tuples() < 1
            raise Error.new('No rows updated')
          end
        rescue Exception => e
          # restore previous version
          object_doc['@version'] = version
          raise e
        end
        object_doc
      end

      # execute a select statement that values from a given table
      #
      # @param statement_name Name of previously prepared select
      # @param params [Array] Parameters used when executing the select
      # @return [Array] Array of hashes
      #
      def exec_select_on_collection(statement_name, params)
        @connection.exec_prepared(statement_name, params, 0).collect do
          | row | Utility.decode_symbols_in_hash(JSON.parse!(row['value']))
        end
      end

      # Prepare a statement that will do some DML on a table used for storing collection entries. If
      # it's discovered that this table doesn't exist, then it will be created
      #
      # @param statement_name Name to give the statement
      # @param collection_name Name of the collection that the statement is for
      # @param statement The SQL for the statement
      #
      def prepare_on_collection(statement_name, collection_name, statement)
        if is_db_selected?
          begin
            return @connection.prepare(statement_name, statement)
          rescue PG::Error => e
            if sqlstate(e) == SQLSTATE_NO_SUCH_TABLE
              @connection.exec('CREATE TABLE ' + table_for_collection(collection_name) + "(id #{id_type_for(collection_name)} PRIMARY KEY NOT NULL, version INTEGER NOT NULL, value VARCHAR NOT NULL)")
              return @connection.prepare(statement_name, statement)
            else
              raise e
            end
          end
        else
          raise "DB appears to be down"
        end
        nil
      end

      # transform an UUID in the form XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX to
      # a compressed form without the dashes and then convert that into a
      # big number and then a the base62 encoded string representation
      #
      # @param uuid to transform
      # @return base62 encoded UUID
      #
      def pack_uuid(uuid)
        return uuid if uuid == "policy_table"

        compressed = uuid.gsub!(/^(\h{8})-?(\h{4})-?(\h{4})-?(\h{4})-?(\h{12})$/, '\1\2\3\4\5')
        if compressed === nil
          raise ArgumentError.new('Not a valid UUID: "' + uuid + '"')
        end
        compressed.to_i(16).base62_encode
      end

      # ensures that the statements used for insert/update in the table for the
      # given collection have been created
      #
      # @param collection_name
      #
      def ensure_prepared_update_statements(collection_name)
        statement_name = "version:#{collection_name}"
        id_type = id_type_for(collection_name).downcase
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'SELECT version::int FROM ' + table_for_collection(collection_name) + ' WHERE id = $1::' + id_type)
        end
        statement_name = "update:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'UPDATE ' + table_for_collection(collection_name) + ' SET version = version + 1, value = $3::varchar WHERE id = $1::' + id_type + ' AND version = $2::int')
        end
        statement_name = "insert:#{collection_name}"
        if @statements.add?(statement_name)
          prepare_on_collection(statement_name, collection_name, 'INSERT INTO ' + table_for_collection(collection_name) + ' (id, version, value) VALUES ($1::' + id_type + ', 1, $2::varchar)')
        end
        nil
      end

      # transform an UUID from base62 encoded form to the expanded
      # XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX form
      #
      # @param base62_encoded_uuid to transform
      # @return expanded UUID
      #
      def unpack_uuid(base62_encoded_uuid)
        return base62_encoded_uuid if base62_encoded_uuid == "policy_table"

        hex = base62_encoded_uuid.base62_decode().to_s(16).rjust(32,'0')
        hex[0,8] + '-' + hex[8,4] + '-' + hex[12,4] + '-' + hex[16,4] + '-' + hex[20,12]
      end

      def table_for_collection(collection_name)
        return PG::Connection.quote_ident(collection_name.to_s)
      end

      # Runs the given code block within transaction boundaries
      #
      # @param code A code block
      #
      def transaction(&code)
        if is_db_selected?
          @connection.transaction(&code)
        else
          raise "DB appears to be down"
        end
        nil
      end

      def id_type_for(collection_name)
        collection_name == :policy_table ? "VARCHAR" : "UUID"
      end
    end
  end
end
