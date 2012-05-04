# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Node (NEW)
    # Used for policy management
    # @author Nicholas Weaver
    class Node < ProjectRazor::Slice::Base
      # @param [Array] args
      def initialize(args)
        super(args)
        @new_slice_style = true
        @slice_commands = {:get => {
            ["all",nil,/^{.*}$/] => "get_nodes_all",
            [/[Aa]ttrib/,/^[Aa]$/] => "get_node_attributes",
            [/[H]ardware/,/^[Hh]$/] => "get_node_hardware_ids",
            :default => "get_nodes_all",
            :else => "get_node_with_uuid"
        },
                           ["register",/^[Rr]$/] => "register_node",
                           ["checkin",/^[Cc]$/] => "checkin_node",
                           :default => :get,
                           :else => :get
        }
        @slice_name = "Node"
      end

      def get_nodes_all
        # Get all node instances and print/return
        @command = :get_nodes_all
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("nodes", :node), "Discovered Nodes", :style => :table
      end

      def get_node_with_uuid
        @command = :get_node_with_uuid
        @command_help_text = "razor node [get] (uuid)"
        @arg = @command_array.shift
        node = get_object("node_with_uuid", :node, @arg)
        case node
          when nil
            slice_error("Cannot Find Node with UUID: [#@arg]")
          else
            print_object_array [node]
        end
      end

      def get_node_attributes
        @command = :get_node_attributes
        @command_help_text = "razor node [get] attributes[a] (uuid)"
        @arg = @command_array.shift
        node = get_object("node_with_uuid", :node, @arg)
        case node
          when nil
            slice_error("Cannot Find Node with UUID: [#@arg]")
          else
            print_object_array node.print_attributes_hash, "Node Attributes:"
        end
      end

      def get_node_hardware_ids
        @command = :get_node_attributes
        @command_help_text = "razor node [get] attributes[a] (uuid)"
        @arg = @command_array.shift
        node = get_object("node_with_uuid", :node, @arg)
        case node
          when nil
            slice_error("Cannot Find Node with UUID: [#@arg]")
          else
            print_object_array node.print_hardware_ids, "Node Hardware ID's:"
        end
      end

      def register_node
        @command = :register_node
        @command_name = "register_node"

        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))

            if @vars_hash['uuid']
              @vars_hash['hw_id'] = @vars_hash['uuid']
            end
            @hw_id = @vars_hash['hw_id']
            @last_state = @vars_hash['last_state']
            @attributes_hash = @vars_hash['attributes_hash']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @hw_id, @last_state, @attributes_hash = *@command_array
          end
        end
        @hw_id, @last_state, @attributes_hash = *@command_array unless @hw_id || @last_state || @attributes_hash
        # Validate our args are here
        return slice_error("Must Provide Hardware IDs[hw_id]") unless validate_arg(@hw_id)
        return slice_error("Must Provide Last State[last_state]") unless validate_arg(@last_state)
        return slice_error("Must Provide Attributes Hash[attributes_hash]") unless validate_arg(@attributes_hash)
        # Convert our servers var to an Array if it is not one already
        @hw_id = @hw_id.split("_") unless @hw_id.respond_to?(:each)
        return slice_error("Must Provide At Least One Hardware ID [hw_id]") unless @hw_id.count > 0

        @engine = ProjectRazor::Engine.instance
        @new_node = @engine.lookup_node_by_hw_id(:hw_id => @hw_id)
        if @new_node
          @new_node.hw_id = @new_node.hw_id | @hw_id
        else
          shell_node = ProjectRazor::Node.new({})
          shell_node.hw_id = @hw_id
          @new_node = @engine.register_new_node_with_hw_id(shell_node)
          unless @new_node
            slice_error("Could not register new node", true)
            return
          end
        end
        @new_node.timestamp = Time.now.to_i
        @new_node.attributes_hash = @attributes_hash
        @new_node.last_state = @last_state

        if @new_node.update_self
          slice_success(@new_node.to_hash, true)
        else
          logger.error "Could not register node"
          slice_error("CouldNotRegister", true)
        end
      end

      def checkin_node
        @command = :checkin_node
        @command_name = "checkin_node"

        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))

            if @vars_hash['uuid']
              @vars_hash['hw_id'] = @vars_hash['uuid']
            end
            @hw_id = @vars_hash['hw_id']
            @last_state = @vars_hash['last_state']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @hw_id, @last_state = *@command_array
          end
        end
        @hw_id, @last_state = *@command_array unless @hw_id || @last_state
        # Validate our args are here
        return slice_error("Must Provide Hardware IDs[hw_id]") unless validate_arg(@hw_id)
        return slice_error("Must Provide Last State[last_state]") unless validate_arg(@last_state)
        @hw_id = @hw_id.split("_") unless @hw_id.respond_to?(:each)
        return slice_error("Must Provide At Least One Hardware ID [hw_id]") unless @hw_id.count > 0
        @engine = ProjectRazor::Engine.instance
        @new_node = @engine.lookup_node_by_hw_id(:hw_id => @hw_id)
        if @new_node
          command = @engine.mk_checkin(@new_node.uuid, @last_state)
          return slice_success(command, true)
        else
          return slice_success(@engine.mk_command(:register,{}), true)
        end
      end
    end
  end
end


