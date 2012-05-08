# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root namespace for policy objects
# used to find them in object space for type checking
POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Policy (NEW))
    # Used for policy management
    # @author Nicholas Weaver
    class Policy < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Policy including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true # switch to new slice style
                                # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_policy",
                           :get => {["all", '{}', /^{.*}$/, nil,/^[Aa]$/] => "get_policy_all",
                                    [/type/,/^[Tt]$/,/template/] => "get_policy_templates",
                                    [/^[Mm]odel/,/^[Mm]$/,"model_config","possible_models"] => {:default => "get_possible_models",
                                                                                                :help => "razor policy get [models] [all|(policy template)]",
                                                                                                :else => "get_possible_models"},
                                    ["active_model",/active/,/^[Aa][Mm]$/] => {["all", '{}', /^{.*}$/, nil] => "get_active_model_all",
                                                                              [/^[Ll]og/,/^[Ll]$/] => { :all => "get_active_log_all",
                                                                                                        :default => "get_active_log_all",
                                                                                                        :else => "get_active_log"
                                                                                                        },
                                                                              :default => "get_active_model_all",
                                                                              :help => "",
                                                                              :else => "get_active_model_with_uuid"},
                                    [/^[Bb][Tt]$/,/broker/] => "get_broker_targets",
                                    :default => "get_policy_all",
                                    :else => "get_policy_with_uuid",
                                    :help => "razor policy get all[a]|template[t]|(uuid)"},
                           :template => "get_policy_templates",
                           :callback => "get_callback",
                           [/type/,/^[Tt]$/,/template/] => "get_policy_templates",
                           # TODO - Add :move => :up + :down for Policy Rules
                           :default => "get_policy_all",
                           :remove => {:policy => "remove_policy",
                                       [/^[Bb]ound/,"active_model",/^[Bb]$/] => "remove_active",
                                       :default => :policy,
                                       :else => :policy,
                                       :help => "razor policy remove policy[p]|active_model[am] all|(policy uuid)"},
                           :else => :get,
                           :help => "razor policy add|remove|get [all[a]|template[t]|(policy rule uuid)|models[m]|active_model[am]|broker targets[bt]"}
        @slice_name = "Policy"
      end

      # Returns all policy instances
      def get_policy_all
        # Get all policy instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("policies", :policy), "Policies", :style => :table
      end

      # Returns the policy templates available
      def get_policy_templates
        # We use the common method in Utility to fetch object templates by providing Namespace prefix
        print_object_array get_templates_as_object_templates(POLICY_PREFIX), "\nPolicy Templates:"
      end

      def get_policy_with_uuid
        @command = :get_policy_with_uuid
        @command_help_text = "razor policy get all|template|(uuid)"
        @arg = @command_array.shift
        policy = get_object("policy instances", :policy, @arg)
        case policy
          when nil
            slice_error("Cannot Find Policy with UUID: [#@arg]")
          else
            print_object_array [policy]
        end
      end

      def add_policy
        # Set the command we have selected
        @command =:add
        # Set out help text
        @command_help_text = "razor policy add " + "(policy templates) (Name) (Model Config UUID) [none|(Broker Target UUID)] (tag{,tag,tag})".yellow
        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
            # Policy template (must match a proper policy template)
            @template = @vars_hash['template']
            # Policy Name (user defined)
            @label = @vars_hash['name']
            # Policy Model Config UUID (must be valid)
            @model_config_uuid = @vars_hash['model_config']
            # Policy Broker Target to attached. Can be set to none. Required
            @broker_target_uuid = @vars_hash['broker_target']
            # Policy Tags (Array or comma-delimited string)
            @tags = @vars_hash['servers']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @template, @label, @model_config_uuid, @broker_target_uuid, @tags = *@command_array
          end
        end
        @template, @label, @model_config_uuid, @broker_target_uuid, @tags = *@command_array unless @template || @label || @model_config_uuid || @broker_target_uuid
        # Validate our args are here
        return slice_error("Must Provide Policy Template [template]") unless validate_arg(@template)
        # We use the [is_valid_template?] method from Utility to validate our template vs our object namespace prefix
        unless is_valid_template?(POLICY_PREFIX, @template)
          # Return error
          slice_error("InvalidPolicyTemplate")
          # Also print possible templates if not a REST call
          get_policy_templates unless @web_command
          return
        end
        # Get our new policy object
        new_policy = new_object_from_template_name(POLICY_PREFIX, @template)
        return slice_error("Must Provide Policy Name [name]") unless validate_arg(@label)
        unless validate_arg(@model_config_uuid)
          slice_error("Must Provide Model Config UUID [model_config]")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.template # push the template in for the next method
          get_possible_models unless @web_command
          return
        end
        unless validate_arg(@broker_target_uuid)
          slice_error("Must Provide Broker Target UUID or String:'none' [broker_target]")
          get_broker_targets
          return
        end
        # Validate Model Config UUID
        setup_data
        @model_config = @data.fetch_object_by_uuid(:model, @model_config_uuid)
        unless @model_config
          slice_error("Cannot find Model Config with UUID (#{@model_config_uuid})")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.template # push the template in for the next method
          get_possible_models unless @web_command
          return
        end
        unless new_policy.template == @model_config.template
          slice_error("Model Config is not compatible with Policy template (#{new_policy.template.to_s})")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.template # push the template in for the next method
          get_possible_models unless @web_command
          return
        end
        # Validate Broker Target UUID
        if @broker_target_uuid == "none"
          @broker = nil
        else
          @broker = @data.fetch_object_by_uuid(:broker, @broker_target_uuid)
          unless @broker
            slice_error("Cannot find Broker Target with UUID (#{@broker_target_uuid})")
            get_broker_targets
            return
          end
        end
        # Validate tags
        return slice_error("Must Provide Tags [tags]") unless @tags
        @tags = @tags.split(",") unless @tags.class.to_s == "Array"
        return slice_error("Must Provide at least one tag [tags]") unless @tags.count > 0
        new_policy.label = @label
        new_policy.model = @model_config
        new_policy.broker = @broker
        new_policy.tags = @tags

        policy_rules = ProjectRazor::Policies.instance
        if policy_rules.add(new_policy)
          @command_array.unshift(new_policy.uuid)
          get_policy_with_uuid
        else
          slice_error("CouldNotSavePolicy")
        end
      end

      def remove_policy
        @command_help_text = "razor policy remove policy[p] all|(uuid)"
        # Grab the arg
        @arg = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data # setup the data object
            @data.delete_all_objects(:policy) # remove all policy instances
            slice_success("All Policy deleted") # return success
          when nil
            slice_error("Command Error") # return error for no arg
          else
            policy = get_object("policy instances", :policy, @arg) # attempt to find policy with uuid
            case policy
              when nil
                slice_error("Cannot Find Policy with UUID: [#@arg]") # error when it is invalid
              else
                setup_data
                @data.delete_object_by_uuid(:policy, @arg)
                slice_success("Policy deleted")
            end
        end
      end

      def get_active_model_all
        # Get all active model instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("active_models", :active), "Active Models:", :style => :table
      end

      def get_active_model_with_uuid
        @command = :get_active_model_with_uuid
        @command_help_text = "razor policy get active[am] all|template|(uuid)"
        @arg = @command_array.shift
        active_model = get_object("active_model_instance", :active, @arg)
        case active_model
          when nil
            slice_error("Cannot Find Active Model with UUID: [#@arg]")
          else
            print_object_array [active_model]
        end
      end


      def get_active_log_all
        @command = :get_active_log_all
        active_models = get_object("active_models", :active)
        log_items = []
        active_models.each do
        |bp|
          log_items = log_items | bp.print_log_all
        end
        log_items.sort! {|a,b| a.print_items[3] <=> b.print_items[3]}
        log_items.each {|li| li.print_items[3] = Time.at(li.print_items[3]).strftime("%H:%M:%S")}
        print_object_array(log_items, "All Active Model Logs:", :style => :table)
      end

      def get_active_log
        @command = :get_active_log
        @command_help_text = "razor policy get active_model[am] log (uuid)"
        @arg = @command_array.shift
        active_model = get_object("active_model_instance", :active, @arg)
        unless active_model.class != Array
          slice_error("Must provide Active Model UUID")
          get_active_model_all unless @web_command
          return
        end
        case active_model
          when nil
            slice_error("Cannot Find Active Model with UUID: [#@arg]")
          else
            print_object_array active_model.print_log, :style => :table
        end
      end

      def remove_active
        @command_help_text = "razor policy remove active_model[am] all|(uuid)"
        # Grab the arg
        @arg = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data # setup the data object
            @data.delete_all_objects(:active) # remove all policy instances
            slice_success("All Active Models deleted") # return success
          when nil
            slice_error("Command Error") # return error for no arg
          else
            active_model = get_object("active model", :active, @arg) # attempt to find policy with uuid
            case active_model
              when nil
                slice_error("Cannot Find Active Model with UUID: [#@arg]") # error when it is invalid
              else
                setup_data
                @data.delete_object_by_uuid(:active, @arg)
                slice_success("Active Model deleted")
            end
        end

      end

      def get_possible_models
        @command = :get_possible_models
        @command_help_text = "razor policy get [model|model_config] [all|(policy template)]"
        # TODO - This parsing get/post/line below for web should be in the Base object or Util. Need to make common and move. Too much repeating
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
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
        @command = :get_broker_target
        @command_help_text = "razor policy [get] broker"
        # Just print all broker targets
        print_object_array get_object("broker_targets", :broker), "All Broker Target"
      end

      def get_callback
        @command = :get_callback
        @command_help_text = ""
        policy_uuid = @command_array.shift
        unless validate_arg(policy_uuid)
          slice_error("MissingUUID")
          return
        end
        callback_namespace = @command_array.shift
        unless validate_arg(callback_namespace)
          slice_error("MissingCallbackNamespace")
          return
        end
        # First we check for a bound policy with a matching uuid
        engine = ProjectRazor::Engine.instance
        active_policy = nil
        engine.get_active_models.each do
        |bp|
          active_policy = bp if bp.uuid == policy_uuid
        end
        if active_policy != nil
          logger.debug "Active bound policy found for callback: #{callback_namespace}"
          make_callback(active_policy, callback_namespace)
          return
        end
        slice_error("InvalidPolicyID")
      end

      def make_callback(active_model, callback_namespace)
        callback = active_model.model.callback[callback_namespace]
        if callback != nil
          setup_data
          node = @data.fetch_object_by_uuid(:node, active_model.node_uuid)
          callback_return = active_model.model.callback_init(callback, @command_array, node, active_model.uuid, active_model.broker)
          active_model.update_self
          puts callback_return
        else
          slice_error("NoCallbackFound")
        end
      end
    end
  end
end


