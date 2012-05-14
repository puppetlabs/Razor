# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root namespace for broker objects
# used to find them in object space for plugin checking
BROKER_PREFIX = "ProjectRazor::BrokerPlugin::"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Broker
    # Used for broker management
    # @author Nicholas Weaver
    class Broker < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Broker including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true # switch to new slice style
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {
          :add => "add_broker",
          :get => {
            ["all", '{}', /^{.*}$/, nil]     => "get_broker_all",
            [/plugin/,"t",/template/,/type/] => "get_broker_plugins",
            :default                         => "get_broker_all",
            :else                            => "get_broker_with_uuid",
            :help                            => "razor broker get all|plugin|(uuid)"
          },
          :plugin        => "get_broker_plugins",
          [/plugin/,"t"] => "get_broker_plugins",
          :default       => "get_broker_all",
          :remove        => "remove_broker",
          :else          => :get,
          :help          => "razor broker add|remove|get [all|plugin|(uuid)]"
        }
        @slice_name = "Broker"
      end

      # Returns all broker instances
      def get_broker_all
        # Get all broker instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("broker_instances", :broker), "Broker Targets:"
      end

      # Returns the broker plugins available
      def get_broker_plugins
        # We use the common method in Utility to fetch object plugins by providing Namespace prefix
        print_object_array get_plugins_as_object_plugins(BROKER_PREFIX), "\nAvailable Broker Plugins:"
      end

      def get_broker_with_uuid
        @command_help_text = "razor broker get all|plugin|(uuid)"
        @arg = @command_array.shift
        broker = get_object("broker instances", :broker, @arg)

        raise ProjectRazor::Error::Slice::NotFound, "Broker Target UUID: [#@arg]" unless broker
        print_object_array [broker]
      end

      def add_broker
        # Set the command we have selected
        @command =:add
        # Set out help text
        @command_help_text = "razor broker add " + "[broker_plugin] [broker_target_name] [description] [server_hostname(,server_hostname)]".yellow
        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
            # Broker plugin (must match a proper broker plugin)
            @plugin = @vars_hash['plugin']
            # Broker Name (user defined)
            @name = @vars_hash['name']
            # Broker User Description (user defined)
            @user_description = @vars_hash['description']
            # Broker Servers (user defined comma-delimited list of servers, must be at list one)
            @servers = @vars_hash['servers']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @plugin, @name, @user_description, @servers = *@command_array
          end
        end
        @plugin, @name, @user_description, @servers = *@command_array unless @plugin || @name || @user_description || @servers

        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Plugin [broker_plugin]" unless validate_arg(@plugin)
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Target Name [broker_target_name]" unless validate_arg(@name)
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Description [description]" unless validate_arg(@user_description)
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Servers [servers]" unless validate_arg(@servers)

        # convert our servers var to an Array if it is not one already
        @servers = @servers.split(",") unless @servers.respond_to?(:each)
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Server [server_hostname(,server_hostname)]" unless @servers.count > 0
        # we use the [is_valid_template?] method from Utility to validate our plugin vs our object namespace prefix
        unless is_valid_template?(BROKER_PREFIX, @plugin)
          get_broker_plugins unless @web_command
          raise ProjectRazor::Error::Slice::InvalidPlugin, @plugin
        end
        new_broker = new_object_from_template_name(BROKER_PREFIX, @plugin)
        new_broker.name = @name
        new_broker.user_description = @user_description
        new_broker.servers = @servers
        setup_data
        @data.persist_object(new_broker)
        if new_broker
          @command_array.unshift(new_broker.uuid)
          get_broker_with_uuid
        else
          raise ProjectRazor::Error::Slice::InternalError, "could not save broker"
        end
      end

      def remove_broker
        @command_help_text = "razor broker remove all|(uuid)"
        # Grab the arg
        @arg = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data # setup the data object
            @data.delete_all_objects(:broker) # remove all broker instances
            slice_success("All Broker deleted") # return success
          when nil
            raise ProjectRazor::Error::Slice::MissingArgument, "all|UUID"
          else
            broker = get_object("broker instances", :broker, @arg) # attempt to find broker with uuid
            case broker
              when nil
                raise ProjectRazor::Error::Slice::NotFound, "Broker Target with UUID: [#@arg]"
              else
                setup_data
                @data.delete_object_by_uuid(:broker, @arg)
                slice_success("Broker Deleted", :type => :removed)
            end
        end
      end
    end
  end
end

