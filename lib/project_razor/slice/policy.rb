require "json"

# Root namespace for policy objects
# used to find them in object space for type checking
POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"

# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # ProjectRazor Slice Policy (NEW))
    # Used for policy management
    class Policy < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Policy including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden          = false
        @new_slice_style = true # switch to new slice style
                                # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands  = { :add                           => "add_policy",
                             :move                          => {
                                 :higher => "move_policy_higher",
                                 :lower  => "move_policy_lower",
                             },
                             :enable => "enable_policy",
                             :disable => "disable_policy",
                             :get                           => { ["all", '{}', /^\{.*\}$/, nil, /^[Aa]$/]                     => "get_policy_all",
                                                                 [/type/, /^[Tt]$/, /template/]                             => "get_policy_templates",
                                                                 [/^[Mm]odel/, /^[Mm]$/, "model_config", "possible_models"] => { :default => "get_possible_models",
                                                                                                                                 :help    => "razor policy get [models] [all|(policy template)]",
                                                                                                                                 :else    => "get_possible_models" },
                                                                 ["active_model", /active/, /^[Aa][Mm]$/]                   => { ["all", '{}', /^\{.*\}$/, nil] => "get_active_model_all",
                                                                                                                                 [/^[Ll]og/, /^[Ll]$/]        => { :all     => "get_active_log_all",
                                                                                                                                                                   :default => "get_active_log_all",
                                                                                                                                                                   :else    => "get_active_log"
                                                                                                                                 },
                                                                                                                                 :default                     => "get_active_model_all",
                                                                                                                                 :help                        => "",
                                                                                                                                 :else                        => "get_active_model_with_uuid" },
                                                                 [/^[Bb][Tt]$/, /broker/]                                   => "get_broker_targets",
                                                                 :default                                                   => "get_policy_all",
                                                                 :else                                                      => "get_policy_by_uuid",
                                                                 :help                                                      => "razor policy get all[a]|template[t]|(uuid)" },
                             :template                      => "get_policy_templates",
                             :callback                      => "get_callback",
                             [/type/, /^[Tt]$/, /template/] => "get_policy_templates",
                             # TODO - Add :move => :up + :down for Policy Rules
                             :default                       => "get_policy_all",
                             :remove                        => { :all                                     => "remove_all_policies",
                                                                 :policy                                  => "remove_policy",
                                                                 [/^[Aa]ctive/, "active_model", /^[Bb]$/] => "remove_active",
                                                                 :default                                 => :policy,
                                                                 :else                                    => :policy,
                                                                 :help                                    => "razor policy remove policy[p]|active_model[am] all|(policy uuid)" },
                             :else                          => :get,
                             :help                          => "razor policy add|remove|get [all[a]|template[t]|(policy rule uuid)|models[m]|active_model[am]|broker targets[bt]" }
        @slice_name      = "Policy"
        @policies = ProjectRazor::Policies.instance
      end

      def move_policy_higher
        @command           = :move_policy_higher
        @command_help_text = "razor policy move higher (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy UUID" unless validate_arg(@command_array.first)
        policy = get_object("get_policy_by_uuid", :policy, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{@command_array.first}]" unless policy
        policy_rules = ProjectRazor::Policies.instance
        policy_rules.move_policy_up(policy.uuid)
        policy_all = get_object("policies", :policy)
        print_object_array policy_all.sort { |a, b| a.line_number <=> b.line_number }, "Policies", :style => :table
      end

      def move_policy_lower
        @command           = :move_policy_lower
        @command_help_text = "razor policy move lower (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy UUID" unless validate_arg(@command_array.first)
        policy = get_object("get_policy_by_uuid", :policy, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{@command_array.first}]" unless policy
        policy_rules = ProjectRazor::Policies.instance
        policy_rules.move_policy_down(policy.uuid)
        policy_all = get_object("policies", :policy)
        print_object_array policy_all.sort { |a, b| a.line_number <=> b.line_number }, "Policies", :style => :table
      end

      # Returns all policy instances
      def get_policy_all
        # Get all policy instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        policy_all = get_object("policies", :policy)
        print_object_array @policies.get, "Policies", :style => :table
      end

      # Returns the policy templates available
      def get_policy_templates
        # We use the common method in Utility to fetch object templates by providing Namespace prefix
        print_object_array get_child_templates(POLICY_PREFIX), "\nPolicy Templates:"
      end

      def get_policy_by_uuid
        @command           = :get_policy_by_uuid
        @command_help_text = "razor policy [get] (uuid)"
        policy             = get_object("get_policy_by_uuid", :policy, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{@command_array.first}]" unless policy
        print_object_array [policy], "", :success_type => :generic
      end

      def enable_policy
        @command           = :enable_policy
        @command_help_text = "razor policy enable (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy UUID" unless validate_arg(@command_array.first)
        policy             = get_object("get_policy_by_uuid", :policy, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{@command_array.first}]" unless policy
        policy.enabled = true
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not enable Policy [#{policy.uuid}]" unless policy.update_self
        print_object_array @policies.get, "Policies", :style => :table
      end

      def disable_policy
        @command           = :disable_policy
        @command_help_text = "razor policy disable (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy UUID" unless validate_arg(@command_array.first)
        policy             = get_object("get_policy_by_uuid", :policy, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{@command_array.first}]" unless policy
        policy.enabled = false
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not enable Policy [#{policy.uuid}]" unless policy.update_self
        print_object_array @policies.get, "Policies", :style => :table
      end

      def add_policy
        @command           =:add_policy
        @command_help_text = "razor model add template=(policy template) label=(policy label) model_uuid=(model UUID) broker_uuid=(broker UUID)|none tags=(tag){,(tag),(tag)..} {enabled=true|false}\n"
        @command_help_text << "\t template: \t" + " The Policy Template name to use\n".yellow
        @command_help_text << "\t label: \t" + " A label to name this Policy\n".yellow
        @command_help_text << "\t model_uuid: \t" + " The Model to attach to the Policy\n".yellow
        @command_help_text << "\t broker_uuid: \t" + " The Broker to attach to the Policy or 'none'\n".yellow
        @command_help_text << "\t tags: \t" + " At least one tag to trigger the Policy. Comma delimited\n".yellow
        @command_help_text << "\t enabled: \t" + " Whether the Policy is enabled or not. Optional and defaults to false\n".yellow
        template, label, model_uuid, broker_uuid, tags, enabled = *get_web_vars(%w(template label model_uuid broker_uuid tags enabled)) if @web_command
        template, label, model_uuid, broker_uuid, tags, enabled = *get_cli_vars(%w(template label model_uuid broker_uuid tags enabled)) unless template || label || model_uuid || broker_uuid || tags
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy Template [template]" unless validate_arg(template)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy Label [label]" unless validate_arg(label)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Model UUID [model_uuid]" unless validate_arg(model_uuid)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Broker UUID or 'none' [broker_uuid]" unless validate_arg(broker_uuid)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide At Least One Tag [tags]" unless validate_arg(tags)
        policy = new_object_from_template_name(POLICY_PREFIX, template)
        raise ProjectRazor::Error::Slice::InvalidPolicyTemplate, "Policy Template is not valid [template]" unless policy
        setup_data
        model = get_object("model_by_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{model_uuid}]" unless model
        raise ProjectRazor::Error::Slice::InvalidModel, "Invalid Model Type [#{model.label}]" unless policy.template == model.template
        broker = get_object("model_by_uuid", :broker, broker_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{broker_uuid}]" unless broker || broker_uuid == "none"
        tags = tags.split(",") unless tags.class.to_s == "Array"
        raise ProjectRazor::Error::Slice::MissingTags, "Must provide at least one tag [tags]" unless tags.count > 0
        policy.label  = label
        policy.model  = model
        policy.broker = broker
        policy.tags   = tags
        policy.enabled = true if enabled == "true"
        policy.is_template = false
        policy_rules       = ProjectRazor::Policies.instance
        policy_rules.add(policy) ? print_object_array([policy], "Policy created", :success_type => :created) : raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Policy")
      end


      def remove_all_policies
        @command           = :remove_all_policies
        @command_help_text = "razor policy remove all"
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Policies" unless @data.delete_all_objects(:policy)
        slice_success("All policies removed", :success_type => :removed)
      end

      def remove_policy
        @command           = :remove_policy
        @command_help_text = "razor policy remove (UUID)"
        policy_uuid        = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Policy UUID [policy_uuid]" unless validate_arg(policy_uuid)
        policy = get_object("policy_with_uuid", :policy, policy_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Policy with UUID: [#{policy_uuid}]" unless policy
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove policy [#{tagrule.uuid}]" unless @data.delete_object(policy)
        slice_success("Active policy [#{policy.uuid}] removed", :success_type => :removed)
      end

      def get_active_model_all
        # Get all active model instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("active_models", :active), "Active Models:", :style => :table
      end

      def get_active_model_with_uuid
        @command           = :get_active_model_with_uuid
        @command_help_text = "razor policy get active (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide An Active Model UUID" unless validate_arg(@command_array.first)
        active_model             = get_object("active_model_instance", :active, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{@command_array.first}]" unless active_model
        print_object_array [active_model], "", :success_type => :generic
      end


      def get_active_log_all
        @command      = :get_active_log_all
        active_models = get_object("active_models", :active)
        log_items     = []
        active_models.each { |bp| log_items = log_items | bp.print_log_all }
        log_items.sort! { |a, b| a.print_items[3] <=> b.print_items[3] }
        log_items.each { |li| li.print_items[3] = Time.at(li.print_items[3]).strftime("%H:%M:%S") }
        print_object_array(log_items, "All Active Model Logs:", :style => :table)
      end

      def get_active_log
        @command           = :get_active_log
        @command_help_text = "razor policy get active log (uuid)"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide An Active Model UUID" unless validate_arg(@command_array.first)
        active_model             = get_object("active_model_instance", :active, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{@command_array.first}]" unless active_model
        print_object_array [active_model], "", :success_type => :generic
        print_object_array(active_model.print_log, :style => :table)
      end


      def remove_active
        @command           = :remove_active
        @command_help_text = "razor policy active remove (UUID)"
        active_model_uuid  = @command_array.shift
        active_model       = get_object("active_model_with_uuid", :active, active_model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{active_model}]" unless active_model
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Active Model [#{active_model.uuid}]" unless @data.delete_object(active_model)
        slice_success("Active Model [#{active_model.uuid}] removed", :success_type => :removed)
      end

      def get_possible_models
        @command           = :get_possible_models
        @command_help_text = "razor policy get [model|model_config] [all|(policy template)]"
        # TODO - This parsing get/post/line below for web should be in the Base object or Util. Need to make common and move. Too much repeating
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash       = sanitize_hash(JSON.parse(json_string))
            # Policy template (must match a proper policy template)
            @policy_template = @vars_hash['policy_template']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @policy_template = @command_array.first
          end
        end
        @policy_template = @command_array.first unless @policy_template
        case @policy_template
          when "all", '{}', nil
            # Just print all models
            print_object_array get_object("models", :model), "All Models"
          else
            possible_models = []
            setup_data
            @data.fetch_all_objects(:model).each do |model|
              possible_models << model if model.template.to_s == @policy_template.to_s
            end
            print_object_array possible_models, "Valid Models for (#{@policy_template.to_s})"
        end
      end

      def get_broker_targets
        @command           = :get_broker_target
        @command_help_text = "razor policy [get] broker"
        # Just print all broker targets
        print_object_array get_object("broker_targets", :broker), "All Broker Target"
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


