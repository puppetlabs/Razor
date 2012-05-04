# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root namespace for system objects
# used to find them in object space for type checking
SYSTEM_PREFIX = "ProjectRazor::System::"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice System
    # Used for system management
    # @author Nicholas Weaver
    class System < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::System including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true # switch to new slice style
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_system",
                           :get => {["all", '{}', /^{.*}$/, nil] => "get_system_all",
                                    [/type/,"t"] => "get_system_types",
                                    :default => "get_system_all",
                                    :else => "get_system_with_uuid",
                                    :help => "razor system get all|type|(uuid)"},
                           :type => "get_system_types",
                           [/type/,"t"] => "get_system_types",
                           :default => "get_system_all",
                           :remove => "remove_system",
                           :else => :get,
                           :help => "razor system add|remove|get [all|type|(uuid)]"}
        # Obsolete but left here in case debugging is needed (uncomment)
        #@slice_commands_help = {:get => "system ".red + "[all|types|(System UUID)]".yellow,
        #                        :add => "system " + "(system type) (Name) (Description) [(server hostname),{server hostname}]".yellow,
        #                        :remove => "system " + "(System UUID)".yellow}
        @slice_name = "System"
      end

      # Returns all system instances
      def get_system_all
        # Get all system instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("system_instances", :systems), "System Instances"
      end

      # Returns the system types available
      def get_system_types
        # We use the common method in Utility to fetch object types by providing Namespace prefix
        print_object_array get_types_as_object_types(SYSTEM_PREFIX), "\nPossible System Types:"
      end

      def get_system_with_uuid
        @command_help_text = "razor system get all|type|(uuid)"
        @arg = @command_array.shift
        system = get_object("system instances", :systems, @arg)
        case system
          when nil
            slice_error("Cannot Find System with UUID: [#@arg]")
          else
            print_object_array [system]
        end
      end

      def add_system
        # Set the command we have selected
        @command =:add
        # Set out help text
        @command_help_text = "razor system " + "(system type) (Name) (Description) [(server hostname),{server hostname}]".yellow
        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
            # System type (must match a proper system type)
            @type = @vars_hash['type']
            # System Name (user defined)
            @name = @vars_hash['name']
            # System User Description (user defined)
            @user_description = @vars_hash['description']
            # System Servers (user defined comma-delimited list of servers, must be at list one)
            @servers = @vars_hash['servers']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @type, @name, @user_description, @servers = *@command_array
          end
        end
        @type, @name, @user_description, @servers = *@command_array unless @type || @name || @user_description || @servers
        # Validate our args are here
        return slice_error("Must Provide System Type [type]") unless validate_arg(@type)
        return slice_error("Must Provide System Name [name]") unless validate_arg(@name)
        return slice_error("Must Provide System Description [description]") unless validate_arg(@user_description)
        return slice_error("Must Provide System Servers [servers]") unless validate_arg(@servers)
        # Convert our servers var to an Array if it is not one already
        @servers = @servers.split(",") unless @servers.respond_to?(:each)
        return slice_error("Must Provide At Least One System Server [servers]") unless @servers.count > 0
        # We use the [is_valid_type?] method from Utility to validate our type vs our object namespace prefix
        unless is_valid_type?(SYSTEM_PREFIX, @type)
          # Return error
          slice_error("InvalidSystemType")
          # Also print possible types if not a REST call
          get_system_types unless @web_command
          return
        end
        new_system = new_object_from_type_name(SYSTEM_PREFIX, @type)
        new_system.name = @name
        new_system.user_description = @user_description
        new_system.servers = @servers
        setup_data
        @data.persist_object(new_system)
        if new_system
          @command_array.unshift(new_system.uuid)
          get_system_with_uuid
        else
          slice_error("CouldNotSaveSystem")
        end
      end

      def remove_system
        @command_help_text = "razor system remove all|(uuid)"
        # Grab the arg
        @arg = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data # setup the data object
            @data.delete_all_objects(:systems) # remove all system instances
            slice_success("All System deleted") # return success
          when nil
            slice_error("Command Error") # return error for no arg
          else
            system = get_object("system instances", :systems, @arg) # attempt to find system with uuid
            case system
              when nil
                slice_error("Cannot Find System with UUID: [#@arg]") # error when it is invalid
              else
                setup_data
                @data.delete_object_by_uuid(:systems, @arg)
                slice_success("System deleted")
            end
        end
      end
    end
  end
end

