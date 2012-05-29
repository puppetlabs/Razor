# Root ProjectRazor namespace
module ProjectRazor
  module Slice
    # ProjectRazor Slice Node (NEW)
    # Used for policy management
    class Node < ProjectRazor::Slice::Base
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden          = false
        @new_slice_style = true
        @slice_name = "Node"
        @engine = ProjectRazor::Engine.instance
        load_slice_commands
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
        node = get_object("node_with_uuid", :node, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Node with UUID: [#{@command_array.first}]" unless node
        print_object_array [node]
      end

      def get_node_attributes
        @command = :get_node_attributes
        @command_help_text = "razor node [get] attributes[a] (uuid)"
        node = get_object("node_with_uuid", :node, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Node with UUID: [#{@command_array.first}]" unless node
        print_object_array node.print_attributes_hash, "Node Attributes:"
      end

      def get_node_hardware_ids
        @command = :get_node_attributes
        @command_help_text = "razor node [get] attributes[a] (uuid)"
        node = get_object("node_with_uuid", :node, @arg)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Node with UUID: [#{@command_array.first}]" unless node
        print_object_array node.print_hardware_ids, "Node Hardware ID's:"
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
            @vars_hash['hw_id'] = @vars_hash['uuid'] if @vars_hash['uuid']
            @hw_id = @vars_hash['hw_id']
            @last_state = @vars_hash['last_state']
            @attributes_hash = @vars_hash['attributes_hash']
          end
        end
        @hw_id, @last_state, @attributes_hash = *@command_array unless @hw_id || @last_state || @attributes_hash
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Hardware IDs[hw_id]" unless validate_arg(@hw_id)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Last State[last_state]" unless validate_arg(@last_state)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Attributes Hash[attributes_hash]" unless @attributes_hash.is_a? Hash and @attributes_hash.size > 0
        @hw_id = @hw_id.split("_") if @hw_id.is_a? String
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide At Least One Hardware ID [hw_id]" unless @hw_id.count > 0
        @engine = ProjectRazor::Engine.instance
        @new_node = @engine.lookup_node_by_hw_id(:hw_id => @hw_id)
        if @new_node
          @new_node.hw_id = @new_node.hw_id | @hw_id
        else
          shell_node = ProjectRazor::Node.new({})
          shell_node.hw_id = @hw_id
          @new_node = @engine.register_new_node_with_hw_id(shell_node)
          raise ProjectRazor::Error::Slice::CouldNotRegisterNode, "Could not register new node" unless @new_node
        end
        @new_node.timestamp = Time.now.to_i
        @new_node.attributes_hash = @attributes_hash
        @new_node.last_state = @last_state
        raise ProjectRazor::Error::Slice::CouldNotRegisterNode, "Could not register node" unless @new_node.update_self
        slice_success(@new_node.to_hash, :mk_response => true)
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
            @vars_hash['hw_id'] = @vars_hash['uuid'] if @vars_hash['uuid']
            @hw_id = @vars_hash['hw_id']
            @last_state = @vars_hash['last_state']
          end
        end
        @hw_id, @last_state = *@command_array unless @hw_id || @last_state
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Hardware IDs[hw_id]" unless validate_arg(@hw_id)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Last State[last_state]" unless validate_arg(@last_state)
        @hw_id = @hw_id.split("_") unless @hw_id.is_a? Array

        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide At Least One Hardware ID [hw_id]" unless @hw_id.count > 0
        @new_node = @engine.lookup_node_by_hw_id(:hw_id => @hw_id)
        if @new_node
          command = @engine.mk_checkin(@new_node.uuid, @last_state)
          return slice_success(command, :mk_response => true)
        end
        slice_success(@engine.mk_command(:register,{}), :mk_response => true)
      end
    end
  end
end


