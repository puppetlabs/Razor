require "json"

# Root namespace for broker objects
# used to find them in object space for plugin checking
BROKER_PREFIX = "ProjectRazor::BrokerPlugin::"

# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # ProjectRazor Slice Broker
    # Used for broker management
    class Broker < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Broker including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden          = false
        @new_slice_style = true # switch to new slice style
                                # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands  = {
            :add            => "add_broker",
            :update         => {
                :default => "get_broker_all",
                :else    => "update_broker"
            },
            :get            => {
                ["all", '{}', /^\{.*\}$/, nil]        => "get_broker_all",
                [/plugin/, "t", /template/, /type/] => "get_broker_plugins",
                :default                            => "get_broker_all",
                :else                               => "get_broker_with_uuid",
                :help                               => "razor broker get all|plugin|(uuid)"
            },
            :plugin         => "get_broker_plugins",
            [/plugin/, "t"] => "get_broker_plugins",
            :default        => "get_broker_all",
            :remove         => {:all => "remove_broker_all",
                                :else => "remove_broker"},
            :else           => :get,
            :help           => "razor broker add|remove|get [all|plugin|(uuid)]"
        }
        @slice_name      = "Broker"
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
        print_object_array get_child_templates(BROKER_PREFIX), "\nAvailable Broker Plugins:"
      end

      def get_broker_with_uuid
        @command_help_text = "razor broker get all|plugin|(uuid)"
        @arg               = @command_array.shift
        broker             = get_object("broker instances", :broker, @arg)
        raise ProjectRazor::Error::Slice::NotFound, "Broker Target UUID: [#@arg]" unless broker
        print_object_array [broker]
      end

      def add_broker
        @command           =:add_broker
        @command_help_text = "razor broker add plugin=(broker plugin) name=(broker target name) description=(description) servers=server{,server,server..}\n"
        @command_help_text << "\t plugin: \t" + " The Broker Plugin to use\n".yellow
        @command_help_text << "\t name: \t" + " A name for this Broker Target\n".yellow
        @command_help_text << "\t description: \t" + " a description for this Broker Target\n".yellow
        @command_help_text << "\t servers: \t" + " A comma delimited list of servers for this Broker Target\n".yellow
        plugin, name, description, servers = *get_web_vars(%w(plugin name description servers)) if @web_command
        plugin, name, description, servers = *get_cli_vars(%w(plugin name description servers)) unless plugin || name || description || servers
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Broker Plugin [plugin]" unless validate_arg(plugin)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Broker Target Name [name]" unless validate_arg(name)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Broker Target Description [description]" unless validate_arg(description)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Broker Target Servers [servers]" unless validate_arg(servers)
        servers = servers.split(",") if servers.is_a? String
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Server [server_hostname(,server_hostname)]" unless servers.count > 0
        raise ProjectRazor::Error::Slice::InvalidPlugin, "Invalid Broker Plugin [#{plugin}]" unless is_valid_template?(BROKER_PREFIX, plugin)
        broker                  = new_object_from_template_name(BROKER_PREFIX, plugin)
        broker.name             = name
        broker.user_description = description
        broker.servers          = servers
        broker.is_template      = false
        setup_data
        get_data.persist_object(broker)
        broker ? print_object_array([broker], "", :success_type => :created) : raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Broker Target")
      end

      def update_broker
        @command           = :update_broker
        @command_help_text = "razor broker update (broker uuid) name=(broker target name) description=(description) servers=server{,server,server..}\n"
        @command_help_text << "\t name: \t" + " A name for this Broker Target\n".yellow
        @command_help_text << "\t description: \t" + " a description for this Broker Target\n".yellow
        @command_help_text << "\t servers: \t" + " A comma delimited list of servers for this Broker Target\n".yellow
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Broker Target UUID" unless validate_arg(@command_array.first)
        broker_uuid = @command_array.shift
        broker      = get_object("broker_with_uuid", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Broker Target with UUID: [#{broker_uuid}]" unless broker
        name, description, servers = *get_web_vars(%w(name description servers)) if @web_command
        name, description, servers = *get_cli_vars(%w(name description servers)) unless name || description || servers
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide at least one value to update" unless name || description || servers
        if servers
          servers = servers.split(",") if servers.is_a? String
          raise ProjectRazor::Error::Slice::MissingArgument, "Broker Server [server_hostname(,server_hostname)]" unless servers.count > 0
        end
        broker.name             = name if name
        broker.user_description = description if description
        broker.servers          = servers if servers
        broker.is_template      = false
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Broker Target [#{broker.uuid}]" unless broker.update_self
        print_object_array [broker], "", :success_type => :updated
      end


      def remove_broker_all
        @command           = :remove_all_policies
        @command_help_text = "razor broker remove all"
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Policies" unless get_data.delete_all_objects(:broker)
        slice_success("All policies removed", :success_type => :removed)
      end

      def remove_broker
        @command           = :remove_broker
        @command_help_text = "razor broker remove (UUID)"
        broker_uuid        = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A broker UUID [broker_uuid]" unless validate_arg(broker_uuid)
        broker = get_object("broker_with_uuid", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find broker with UUID: [#{broker_uuid}]" unless broker
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove broker [#{tagrule.uuid}]" unless get_data.delete_object(broker)
        slice_success("Active broker [#{broker.uuid}] removed", :success_type => :removed)
      end

      def remove_broker_old
        @command_help_text = "razor broker remove all|(uuid)"
        # Grab the arg
        @arg               = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data                        # setup the data object
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

