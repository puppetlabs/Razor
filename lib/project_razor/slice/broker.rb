require "json"

# Root namespace for broker objects
# used to find them in object space for plugin checking
BROKER_PREFIX = "ProjectRazor::BrokerPlugin::"

# Root ProjectRazor namespace
module ProjectRazor
  class Slice

    # ProjectRazor Slice Broker
    # Used for broker management
    class Broker < ProjectRazor::Slice

      # Initializes ProjectRazor::Slice::Broker including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden          = false
        @slice_name      = "Broker"

        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map("broker_help",
                                          "get_all_brokers",
                                          "get_broker_by_uuid",
                                          "add_broker",
                                          "update_broker",
                                          "remove_all_brokers",
                                          "remove_broker_by_uuid")
        # and add any additional commands specific to this slice
        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
        @slice_commands[:get][:else] = "get_broker_by_uuid"
        @slice_commands[:get][[/^(plugin|plugins|t)$/]] = "get_broker_plugins"
      end

      def broker_help
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
        puts "Broker Slice: used to add, view, update, and remove Broker Targets.".red
        puts "Broker Commands:".yellow
        puts "\trazor broker [get] [all]                 " + "View all broker targets".yellow
        puts "\trazor broker [get] (UUID)                " + "View specific broker target".yellow
        puts "\trazor broker [get] plugin|plugins|t      " + "View list of available broker plugins".yellow
        puts "\trazor broker add (options...)            " + "Create a new broker target".yellow
        puts "\trazor broker update (UUID) (options...)  " + "Update a specific broker target".yellow
        puts "\trazor broker remove (UUID)|all           " + "Remove existing (or all) broker target(s)".yellow
        puts "\trazor broker --help|-h                   " + "Display this screen".yellow
      end

      # Returns all broker instances
      def get_all_brokers
        @command = :get_all_brokers
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        print_object_array get_object("broker_instances", :broker), "Broker Targets:"
      end

      # Returns the broker plugins available
      def get_broker_plugins
        @command = :get_broker_plugins
        if @web_command && @prev_args.peek(0) != "plugins"
          not_found_error = "(use of aliases not supported via REST; use '/broker/plugins' not '/broker/#{@prev_args.peek(0)}')"
          raise ProjectRazor::Error::Slice::NotFound, not_found_error
        end
        # We use the common method in Utility to fetch object plugins by providing Namespace prefix
        print_object_array get_child_templates(ProjectRazor::BrokerPlugin), "\nAvailable Broker Plugins:"
      end

      def get_broker_by_uuid
        @command = :get_broker_by_uuid
        # the UUID is the first element of the @command_array
        broker_uuid = @command_array.first
        broker = get_object("broker instances", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::NotFound, "Broker Target UUID: [#{broker_uuid}]" unless broker && (broker.class != Array || broker.length > 0)
        print_object_array [broker]
      end

      def add_broker
        @command = :add_broker
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor broker add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        plugin = options[:plugin]
        name = options[:name]
        description = options[:description]
        servers = options[:servers]
        broker_version = options[:version]
        # check the values that were passed in
        servers = servers.flatten if servers.is_a? Array
        servers = servers.split(",") if servers.is_a? String
        raise ProjectRazor::Error::Slice::MissingArgument, "Broker Server [server_hostname(,server_hostname)]" unless servers.count > 0
        raise ProjectRazor::Error::Slice::InvalidPlugin, "Invalid broker plugin [#{plugin}]" unless is_valid_template?(BROKER_PREFIX, plugin)
        # use the arguments passed in (above) to create a new broker
        broker                  = new_object_from_template_name(BROKER_PREFIX, plugin)
        broker.name             = name
        broker.user_description = description
        broker.servers          = servers
        broker.broker_version   = broker_version
        broker.is_template      = false
        # persist that broker, and print the result (or raise an error if cannot persist it)
        setup_data
        get_data.persist_object(broker)
        broker ? print_object_array([broker], "", :success_type => :created) : raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Broker Target")
      end

      def update_broker
        @command = :update_broker
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        broker_uuid, options = parse_and_validate_options(option_items, "razor broker update (UUID) (options...)", :require_one)
        includes_uuid = true if broker_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        plugin = options[:plugin]
        name = options[:name]
        description = options[:description]
        servers = options[:servers]
        broker_version = options[:version]
        # check the values that were passed in
        if servers
          servers = servers.split(",") if servers.is_a? String
          raise ProjectRazor::Error::Slice::MissingArgument, "Broker Server [server_hostname(,server_hostname)]" unless servers.count > 0
        end
        broker = get_object("broker_with_uuid", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Broker Target with UUID: [#{broker_uuid}]" unless broker && (broker.class != Array || broker.length > 0)
        broker.name             = name if name
        broker.user_description = description if description
        broker.servers          = servers if servers
        broker.broker_version   = broker_version if broker_version
        broker.is_template      = false
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Broker Target [#{broker.uuid}]" unless broker.update_self
        print_object_array [broker], "", :success_type => :updated
      end

      def remove_broker
        @command = :remove_broker
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :remove)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        broker_uuid, options = parse_and_validate_options(option_items, "razor broker remove (UUID)|(--all)", :require_all)
        if !@web_command
          broker_uuid = @command_array.shift
        end
        includes_uuid = true if broker_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, true)

        # and then invoke the right method (based on usage)
        # selected_option = options.select { |k, v| v }.keys[0].to_s
        if options[:all]
          # remove all Brokers from the system
          remove_all_brokers
        elsif includes_uuid
          # remove a specific Broker (by UUID)
          remove_broker_with_uuid(broker_uuid)
        else
          # if get to here, no UUID was specified and the '--all' option was
          # no included, so raise an error and exit
          raise ProjectRazor::Error::Slice::MissingArgument, "Must provide a UUID for the broker to remove (or select the '--all' option)"
        end
      end

      def remove_all_brokers
        @command = :remove_all_brokers
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Brokers via REST" if @web_command
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Brokers" unless get_data.delete_all_objects(:broker)
        slice_success("All brokers removed", :success_type => :removed)
      end

      def remove_broker_by_uuid
        @command = :remove_broker_by_uuid
        # the UUID is the first element of the @command_array
        broker_uuid = get_uuid_from_prev_args
        broker = get_object("broker_with_uuid", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Broker with UUID: [#{broker_uuid}]" unless broker && (broker.class != Array || broker.length > 0)
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove policy [#{broker.uuid}]" unless @data.delete_object(broker)
        slice_success("Broker [#{broker.uuid}] removed", :success_type => :removed)
      end

    end
  end
end
