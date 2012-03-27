# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"
require "yaml"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice
    # ProjectRazor Node Module
    # Handles all Node management
    # @author Nicholas Weaver
    class Node < ProjectRazor::Slice::Base

      # TODO finish logging
      # TODO fill out comments


      # Initializes ProjectRazor::Slice::Node including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:register => "register_node",
                           :checkin => "checkin_node",
                           :default => "query_node"}
        @slice_commands_help = {:register => "node register (JSON STRING)",
                                :default => "node (JSON STRING)"}
        @slice_name = "Node"
      end

      # Runs a node checkin returning appropriate command
      def checkin_node
        # Ensure there are at least uuid & state
        @command_query_string = @command_array.shift
        if @command_query_string != "{}" && @command_query_string != nil
          begin
            params = JSON.parse(@command_query_string)
            if params["uuid"] != nil && params["last_state"] != nil

              # We call the engine
              engine = ProjectRazor::Engine.instance
              command = engine.mk_checkin(params["uuid"],params["last_state"])
              # Return the command the Engine provided us
              slice_success(command, true)
            else
              slice_error("InvalidOrMissingParameters", true)
            end
          rescue StandardError => e
            slice_error(e.message, true)
          end
        else
          slice_error("MissingRequiredParameters(uuid, state)", true)
        end
      end





      # Registers node
      def register_node
        logger.debug "Register node called"
        @command_name = "register_node"

        if @web_command
          @command_query_string = @command_array.shift
          if @command_query_string == "{}"
            logger.error "Missing node details"
            slice_error("MissingDetails")
          else
            details = JSON.parse(@command_query_string)

            if details['@uuid'] != nil && details['@last_state'] != nil && details['@attributes_hash'] != nil

              logger.debug "node: #{details['@uuid']} #{details['@_last_state']}"
              details['@timestamp'] = Time.now.to_i
              new_node = insert_node(details)

              if new_node.refresh_self
                slice_success(new_node.to_hash, true)
              else
                logger.error "Could not register node"
                slice_error("CouldNotRegister", true)
              end
            else
              logger.error "Incomplete node details"
              slice_error("IncompleteDetails",true)
            end
          end
        end
      end

      # Inserts node using hash
      # @param [Hash] node_hash
      # @return [ProjectRazor::Node]
      def insert_node(node_hash)
        setup_data
        existing_node = @data.fetch_object_by_uuid(:node, node_hash['@uuid'])
        if existing_node != nil
          existing_node.last_state = node_hash['@last_state']
          existing_node.attributes_hash = node_hash['@attributes_hash']
          existing_node.update_self
          existing_node
        else
          @data.persist_object(ProjectRazor::Node.new(node_hash))
        end
      end

      def query_node
        print_node get_object("node", :node)
      end




    end
  end
end