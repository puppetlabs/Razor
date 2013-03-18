require 'project_razor/slice'
require 'project_razor/data'

require "json"

# Root namespace for policy objects
# used to find them in object space for type checking
POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"

# Root ProjectRazor namespace
module ProjectRazor
  class Slice

    # ProjectRazor Slice Policy (NEW))
    # Used for policy management
    class Policy < ProjectRazor::Slice

      # Initializes ProjectRazor::Slice::Policy including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden          = false
        @slice_name      = "Policy"
        @policies        = ProjectRazor::Policies.instance

        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map("policy_help",
                                          "get_all_policies",
                                          "get_policy_by_uuid",
                                          "add_policy",
                                          "update_policy",
                                          "remove_all_policies",
                                          "remove_policy_by_uuid")
        # and add any additional commands specific to this slice
        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
        @slice_commands[:get][:else] = "get_policy_by_uuid"
        @slice_commands[:get][[/^(temp|template|templates|types)$/]] = "get_policy_templates"
        @slice_commands[:get][[/^(callback)$/]] = "get_callback"

      end

      def policy_help
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
        puts get_policy_help
      end

      def get_policy_help
        return ["Policy Slice:".red,
                "Used to view, create, update, and remove policies.".red,
                "Policy commands:".yellow,
                "\trazor policy [get] [all]                      " + "View all policies".yellow,
                "\trazor policy [get] (UUID)                     " + "View a specific policy".yellow,
                "\trazor policy [get] templates|types            " + "View available policy templates".yellow,
                "\trazor policy add (options...)                 " + "Create a new policy".yellow,
                "\trazor policy update (UUID) (options...)       " + "Update an existing policy".yellow,
                "\trazor policy remove (UUID)|all                " + "Remove existing policy(s)".yellow,
                "\trazor policy callback (UUID) (NAMESPACE)      " + "Invoke a callback for an existing policy(s)".yellow,
                "\trazor policy --help|-h                        " + "Display this screen".yellow].join("\n")
      end

      # Returns all policy instances
      def get_all_policies
        @command = :get_all_policies
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        # Get all policy instances and print/return
        print_object_array get_object("policies", :policy), "Policies", :style => :table
      end

      # Returns the policy templates available
      def get_policy_templates
        @command = :get_policy_templates
        if @web_command && @prev_args.peek(0) != "templates"
          not_found_error = "(use of aliases not supported via REST; use '/policy/templates' not '/policy/#{@prev_args.peek(0)}')"
          raise ProjectRazor::Error::Slice::NotFound, not_found_error
        end
        # We use the common method in Utility to fetch object templates by providing Namespace prefix
        print_object_array get_child_templates(ProjectRazor::PolicyTemplate), "\nPolicy Templates:"
      end

      def get_policy_by_uuid
        @command = :get_policy_by_uuid
        # the UUID is the first element of the @command_array
        policy_uuid = @command_array.first
        policy = get_object("get_policy_by_uuid", :policy, policy_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)
        print_object_array [policy], "", :success_type => :generic
      end

      def add_policy
        @command = :add_policy
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor policy add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)

        # check the values that were passed in
        policy = new_object_from_template_name(POLICY_PREFIX, options[:template])

        # assign default values for (missing) optional parameters
        options[:maximum] = "0" if !options[:maximum]
        options[:broker_uuid] = "none" if !options[:broker_uuid]
        options[:enabled] = "false" if !options[:enabled]

        # check for errors in inputs
        raise ProjectRazor::Error::Slice::InvalidPolicyTemplate, "Policy Template is not valid [#{options[:template]}]" unless policy
        setup_data
        model = get_object("model_by_uuid", :model, options[:model_uuid])
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{options[:model_uuid]}]" unless model && (model.class != Array || model.length > 0)
        raise ProjectRazor::Error::Slice::InvalidModel, "Invalid Model Type [#{model.template}] != [#{policy.template}]" unless policy.template.to_s == model.template.to_s
        broker = get_object("broker_by_uuid", :broker, options[:broker_uuid])
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{options[:broker_uuid]}]" unless (broker && (broker.class != Array || broker.length > 0)) || options[:broker_uuid] == "none"
        options[:tags] = options[:tags].split(",") unless options[:tags].class.to_s == "Array"
        raise ProjectRazor::Error::Slice::MissingTags, "Must provide at least one tag [tags]" unless options[:tags].count > 0
        raise ProjectRazor::Error::Slice::InvalidMaximumCount, "Policy maximum count must be a valid integer" unless options[:maximum].to_i.to_s == options[:maximum]
        raise ProjectRazor::Error::Slice::InvalidMaximumCount, "Policy maximum count must be > 0" unless options[:maximum].to_i >= 0

        # Flesh out the policy
        policy.label         = options[:label]
        policy.model         = model
        policy.broker        = broker
        policy.tags          = options[:tags]
        policy.enabled       = options[:enabled]
        policy.is_template   = false
        policy.maximum_count = options[:maximum]
        # Add policy
        policy_rules         = ProjectRazor::Policies.instance
        policy_rules.add(policy) ? print_object_array([policy], "Policy created", :success_type => :created) :
            raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Policy")
      end

      def update_policy
        @command = :update_policy
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        policy_uuid, options = parse_and_validate_options(option_items, "razor policy update UUID (options...)", :require_one)
        includes_uuid = true if policy_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        policy = get_object("policy_with_uuid", :policy, policy_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Policy UUID [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)

        # check the values that were passed in
        if options[:tags]
          options[:tags] = options[:tags].split(",") if options[:tags].is_a? String
          raise ProjectRazor::Error::Slice::MissingArgument, "Policy Tags [tag(,tag)]" unless options[:tags].count > 0
        end
        if options[:model_uuid]
          model = get_object("model_by_uuid", :model, options[:model_uuid])
          raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{options[:model_uuid]}]" unless model && (model.class != Array || model.length > 0)
          raise ProjectRazor::Error::Slice::InvalidModel, "Invalid Model Type [#{model.label}]" unless policy.template == model.template
        end
        if options[:broker_uuid]
          broker = get_object("broker_by_uuid", :broker, options[:broker_uuid])
          raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{options[:broker_uuid]}]" unless (broker && (broker.class != Array || broker.length > 0)) || options[:broker_uuid] == "none"
        end
        new_line_number = (options[:new_line_number] ? options[:new_line_number].strip : nil)
        raise ProjectRazor::Error::Slice::InputError, "New index '#{options[:new_line_number]}' is not an integer" if new_line_number && !/^[+-]?\d+$/.match(new_line_number)
        if options[:enabled]
          raise ProjectRazor::Error::Slice::InputError, "Enabled flag must have a value of 'true' or 'false'" if options[:enabled] != "true" && options[:enabled] != "false"
        end
        if options[:maximum]
          raise ProjectRazor::Error::Slice::InvalidMaximumCount, "Policy maximum count must be a valid integer" unless options[:maximum].to_i.to_s == options[:maximum]
          raise ProjectRazor::Error::Slice::InvalidMaximumCount, "Policy maximum count must be > 0" unless options[:maximum].to_i >= 0
        end
        # Update object properties
        policy.label = options[:label] if options[:label]
        policy.model = model if model
        policy.broker = broker if broker
        policy.tags = options[:tags] if options[:tags]
        policy.enabled = options[:enabled] if options[:enabled]
        policy.maximum_count = options[:maximum] if options[:maximum]
        if new_line_number
          policy_rules = ProjectRazor::Policies.instance
          policy_rules.move_policy_to_idx(policy.uuid, new_line_number.to_i)
        end
        # Update object
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Broker Target [#{broker.uuid}]" unless policy.update_self
        print_object_array [policy], "", :success_type => :updated
      end

      def remove_all_policies
        @command = :remove_all_policies
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Policies" unless @data.delete_all_objects(:policy)
        slice_success("All policies removed", :success_type => :removed)
      end

      def remove_policy_by_uuid
        @command = :remove_policy_by_uuid
        # the UUID was the last "previous argument"
        policy_uuid = get_uuid_from_prev_args
        policy = get_object("policy_with_uuid", :policy, policy_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{policy_uuid}]" unless policy && (policy.class != Array || policy.length > 0)
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove policy [#{policy.uuid}]" unless @data.delete_object(policy)
        slice_success("Active policy [#{policy.uuid}] removed", :success_type => :removed)
      end

      def get_callback
        @command           = :get_callback
        @command_help_text = ""
        active_model_uuid  = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingActiveModelUUID, "Missing active model uuid" unless validate_arg(active_model_uuid)
        callback_namespace = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingCallbackNamespace, "Missing callback namespace" unless validate_arg(callback_namespace)
        engine       = ProjectRazor::Engine.instance
        active_model = nil
        engine.get_active_models.each { |am| active_model = am if am.uuid == active_model_uuid }
        raise ProjectRazor::Error::Slice::ActiveModelInvalid, "Active Model Invalid" unless active_model
        logger.debug "Active bound policy found for callback: #{callback_namespace}"
        make_callback(active_model, callback_namespace)
      end

      def make_callback(active_model, callback_namespace)
        callback = active_model.model.callback[callback_namespace]
        raise ProjectRazor::Error::Slice::NoCallbackFound, "Missing callback" unless callback
        setup_data
        node            = @data.fetch_object_by_uuid(:node, active_model.node_uuid)
        callback_return = active_model.model.callback_init(callback, @command_array, node, active_model.uuid, active_model.broker)
        active_model.update_self
        puts callback_return
      end

    end
  end
end


