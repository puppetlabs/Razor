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
        @slice_name = "Node"
        @engine = ProjectRazor::Engine.instance
        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices); note that there is
        # no support for adding, updating, or removing nodes via the slice
        # API, so the last three arguments are nil
        @slice_commands = get_command_map("node_help", "get_all_nodes",
                                          "get_node_by_uuid", nil, nil, nil, nil)
        # and add a few more commands specific to this slice
        @slice_commands[["register", /^[Rr]$/]] = "register_node"
        @slice_commands[["checkin", /^[Cc]$/]] = "checkin_node"
        @slice_commands[:get][/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/][:else] = "get_node_by_uuid"
      end

      def node_help
        if @prev_args.length > 1
          command = @prev_args.peek(1)
          begin
            # load the option items for this command (if they exist) and print them
            option_items = load_option_items(:command => command.to_sym)
            print_command_help(@slice_name.downcase, command, option_items)
            return
          rescue
          end
        end
        # if here, then either there are no specific options for the current command or we've
        # been asked for generic help, so provide generic help
        puts get_node_help
      end

      def get_node_help
        return ["Node Slice: used to view the current list of nodes (or node details)".red,
                "Node Commands:".yellow,
                "\trazor node [get] [all]                      " + "Display list of nodes".yellow,
                "\trazor node [get] (UUID)                     " + "Display details for a node".yellow,
                "\trazor node [get] (UUID) [--field,-f FIELD]  " + "Display node's field values".yellow,
                "\trazor node --help                           " + "Display this screen".yellow,
                "  Note; the FIELD value (above) can be either 'attributes' or 'hardware_ids'".red].join("\n")
      end

      def get_all_nodes
        # Get all node instances and print/return
        @command = :get_all_nodes
        raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
              "Unexpected arguments found in command #{@command} -> #{@command_array.inspect}" if @command_array.length > 0
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        print_object_array get_object("nodes", :node), "Discovered Nodes", :style => :table
      end

      def get_node_by_uuid
        @command = :get_node_by_uuid
        includes_uuid = false
        # ran one argument far when parsing if we were working with a web command
        @command_array.unshift(@prev_args.pop) if @web_command
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :get)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        node_uuid, options = parse_and_validate_options(option_items, "razor node [get] (UUID) [--field,-f FIELD]", :require_all)
        includes_uuid = true if node_uuid
        node = get_object("node_with_uuid", :node, node_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "no matching Node (with a uuid value of '#{node_uuid}') found" unless node && (node.class != Array || node.length > 0)
        selected_option = options[:field]
        # if no options were passed in, then just print out the summary for the specified node
        return print_object_array [node] unless selected_option
        if /^(attrib|attributes)$/.match(selected_option)
          get_node_attributes(node)
        elsif /^(hardware|hardware_id|hardware_ids)$/.match(selected_option)
          get_node_hardware_ids(node)
        else
          raise ProjectRazor::Error::Slice::InputError, "unrecognized fieldname '#{selected_option}'"
        end
      end

      def get_node_attributes(node)
        @command = :get_node_attributes
        if @web_command
          print_object_array [Hash[node.attributes_hash.sort]]
        else
          print_object_array node.print_attributes_hash, "Node Attributes:"
        end
      end

      def get_node_hardware_ids(node)
        @command = :get_node_hardware_ids
        if @web_command
          print_object_array [{"hw_id" => node.hw_id}]
        else
          print_object_array node.print_hardware_ids, "Node Hardware ID's:"
        end
      end

      def register_node
        @command = :register_node
        @command_name = "register_node"
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot register nodes via the CLI" if !@web_command
        # If a REST call we need to populate the values from the provided JSON string
        #if @web_command
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
        #end
        #@hw_id, @last_state, @attributes_hash = *@command_array unless @hw_id || @last_state || @attributes_hash
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
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot checkin nodes via the CLI" if !@web_command
        # If a REST call we need to populate the values from the provided JSON string
        #if @web_command
        # Grab next arg as json string var
        json_string = @command_array.first
        # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
        if is_valid_json?(json_string)
          # Grab vars as hash using sanitize to strip the @ prefix if used
          @vars_hash = sanitize_hash(JSON.parse(json_string))
          @vars_hash['hw_id'] = @vars_hash['uuid'] if @vars_hash['uuid']
          @hw_id = @vars_hash['hw_id']
          @last_state = @vars_hash['last_state']
          @first_checkin = @vars_hash['first_checkin']
        end
        #end
        #@hw_id, @last_state, @first_checkin = *@command_array unless @hw_id || @last_state || @first_checkin
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Hardware IDs[hw_id]" unless validate_arg(@hw_id)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Last State[last_state]" unless validate_arg(@last_state)
        @hw_id = @hw_id.split("_") unless @hw_id.is_a? Array

        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide At Least One Hardware ID [hw_id]" unless @hw_id.count > 0
        # if it's not the first node, check to see if the node exists
        unless @first_checkin
          @new_node = @engine.lookup_node_by_hw_id(:hw_id => @hw_id)
          if @new_node
            # if a node with this hardware id exists, simply acknowledge the checkin request
            command = @engine.mk_checkin(@new_node.uuid, @last_state)
            return slice_success(command, :mk_response => true)
          end
        end
        # otherwise, if we get this far, return a command telling the Microkernel to register
        # (either because no matching node already exists or because it's the first checkin
        # by the Microkernel)
        slice_success(@engine.mk_command(:register,{}), :mk_response => true)
      end
    end
  end
end


