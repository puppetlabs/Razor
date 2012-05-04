# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root namespace for policy objects
# used to find them in object space for type checking
POLICY_PREFIX = "ProjectRazor::Policy::"

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
                           :get => {["all", '{}', /^{.*}$/, nil] => "get_policy_all",
                                    [/type/,/^[Tt]$/] => "get_policy_types",
                                    [/^[Mm]odel/,/^[Mm]$/,"model_config","possible_models"] => {:default => "get_possible_model_configs",
                                                                                                :help => "razor policy get [model|model_config] [all|(policy type)]",
                                                                                                :else => "get_possible_model_configs"},
                                    [/^[Bb]ound/,"bound_policy",/^[Bb]$/] => {["all", '{}', /^{.*}$/, nil] => "get_bound_policy_all",
                                                                              [/^[Ll]og/,/^[Ll]$/] => { :all => "get_bound_log_all",
                                                                                                        :default => "get_bound_log_all",
                                                                                                        :else => "get_bound_log"
                                                                                                        },
                                                                              :default => "get_bound_policy_all",
                                                                              :help => "",
                                                                              :else => "get_bound_policy_with_uuid"},
                                    [/^system/,/^[Ss]$/] => "get_system_instances",
                                    :default => "get_policy_all",
                                    :else => "get_policy_with_uuid",
                                    :help => "razor policy get all|type|(uuid)"},
                           :type => "get_policy_types",
                           :callback => "get_callback",
                           [/type/,/^[Tt]$/] => "get_policy_types",
                           # TODO - Add :move => :up + :down for Policy Rules
                           :default => "get_policy_all",
                           :remove => {:policy => "remove_policy",
                                       [/^[Bb]ound/,"bound_policy",/^[Bb]$/] => "remove_bound",
                                       :default => :policy,
                                       :else => :policy,
                                       :help => "razor policy remove policy[p]|bound[b] all|(policy uuid)"},
                           :else => :get,
                           :help => "razor policy add|remove|get [all[a]|type[t]|(policy rule uuid)|models[m]|bound[b]|systems[s]"}
        @slice_name = "Policy"
      end

      # Returns all policy instances
      def get_policy_all
        # Get all policy instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("policy_instances", :policy_rule), "Policy Rules", :style => :table
      end

      # Returns the policy types available
      def get_policy_types
        # We use the common method in Utility to fetch object types by providing Namespace prefix
        print_object_array get_types_as_object_types(POLICY_PREFIX), "\nPossible policy Types:"
      end

      def get_policy_with_uuid
        @command = :get_policy_with_uuid
        @command_help_text = "razor policy get all|type|(uuid)"
        @arg = @command_array.shift
        policy = get_object("policy instances", :policy_rule, @arg)
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
        @command_help_text = "razor policy add " + "(policy type) (Name) (Model Config UUID) [none|(System Instance UUID)] (tag{,tag,tag})".yellow
        # If a REST call we need to populate the values from the provided JSON string
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
            # Policy type (must match a proper policy type)
            @type = @vars_hash['type']
            # Policy Name (user defined)
            @label = @vars_hash['name']
            # Policy Model Config UUID (must be valid)
            @model_config_uuid = @vars_hash['model_config']
            # Policy System Instance to attached. Can be set to none. Required
            @system_instance_uuid = @vars_hash['system_instance']
            # Policy Tags (Array or comma-delimited string)
            @tags = @vars_hash['servers']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @type, @label, @model_config_uuid, @system_instance_uuid, @tags = *@command_array
          end
        end
        @type, @label, @model_config_uuid, @system_instance_uuid, @tags = *@command_array unless @type || @label || @model_config_uuid || @system_instance_uuid
        # Validate our args are here
        return slice_error("Must Provide Policy Type [type]") unless validate_arg(@type)
        # We use the [is_valid_type?] method from Utility to validate our type vs our object namespace prefix
        unless is_valid_type?(POLICY_PREFIX, @type)
          # Return error
          slice_error("InvalidPolicyType")
          # Also print possible types if not a REST call
          get_policy_types unless @web_command
          return
        end
        # Get our new policy object
        new_policy = new_object_from_type_name(POLICY_PREFIX, @type)
        return slice_error("Must Provide Policy Name [name]") unless validate_arg(@label)
        unless validate_arg(@model_config_uuid)
          slice_error("Must Provide Model Config UUID [model_config]")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.type # push the type in for the next method
          get_possible_model_configs unless @web_command
          return
        end
        unless validate_arg(@system_instance_uuid)
          slice_error("Must Provide System Instance UUID or String:'none' [system_instance]")
          get_system_instances
          return
        end
        # Validate Model Config UUID
        setup_data
        @model_config = @data.fetch_object_by_uuid(:model, @model_config_uuid)
        unless @model_config
          slice_error("Cannot find Model Config with UUID (#{@model_config_uuid})")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.type # push the type in for the next method
          get_possible_model_configs unless @web_command
          return
        end
        unless new_policy.type == @model_config.type
          slice_error("Model Config is not compatible with Policy type (#{new_policy.type.to_s})")
          # Unless REST call, list possible model configs
          @command_array.unshift new_policy.type # push the type in for the next method
          get_possible_model_configs unless @web_command
          return
        end
        # Validate System Instance UUID
        if @system_instance_uuid == "none"
          @system = nil
        else
          @system = @data.fetch_object_by_uuid(:systems, @system_instance_uuid)
          unless @system
            slice_error("Cannot find System Instance with UUID (#{@system_instance_uuid})")
            get_system_instances
            return
          end
        end
        # Validate tags
        return slice_error("Must Provide Tags [tags]") unless @tags
        @tags = @tags.split(",") unless @tags.class.to_s == "Array"
        return slice_error("Must Provide at least one tag [tags]") unless @tags.count > 0
        new_policy.label = @label
        new_policy.model = @model_config
        new_policy.system = @system
        new_policy.tags = @tags

        policy_rules = ProjectRazor::PolicyRules.instance
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
            @data.delete_all_objects(:policy_rule) # remove all policy instances
            slice_success("All Policy deleted") # return success
          when nil
            slice_error("Command Error") # return error for no arg
          else
            policy = get_object("policy instances", :policy_rule, @arg) # attempt to find policy with uuid
            case policy
              when nil
                slice_error("Cannot Find Policy with UUID: [#@arg]") # error when it is invalid
              else
                setup_data
                @data.delete_object_by_uuid(:policy_rule, @arg)
                slice_success("Policy deleted")
            end
        end
      end

      def get_bound_policy_all
        # Get all bound policy instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("bound_policy_instance", :bound_policy), "Bound Policy", :style => :table
      end

      def get_bound_policy_with_uuid
        @command = :get_bound_policy_with_uuid
        @command_help_text = "razor policy get bound[b] all|type|(uuid)"
        @arg = @command_array.shift
        bound_policy = get_object("bound_policy_instance", :bound_policy, @arg)
        case bound_policy
          when nil
            slice_error("Cannot Find Bound Policy with UUID: [#@arg]")
          else
            print_object_array [bound_policy]
        end
      end


      def get_bound_log_all
        bound_policies = get_object("bound_policy_instances", :bound_policy)
        log_items = []
        bound_policies.each do
        |bp|
          log_items = log_items | bp.print_log_all
        end
        log_items.sort! {|a,b| a.print_items[3] <=> b.print_items[3]}
        log_items.each {|li| li.print_items[3] = Time.at(li.print_items[3]).strftime("%H:%M:%S")}
        print_object_array(log_items, "All Bound Policy Logs:", :style => :table)
      end

      def get_bound_log
        @command = :get_bound_log
        @command_help_text = "razor policy get bound[b] log (uuid)"
        @arg = @command_array.shift
        bound_policy = get_object("bound_policy_instance", :bound_policy, @arg)
        unless bound_policy.class != Array
          slice_error("Must provide Bound Policy UUID")
          get_bound_policy_all unless @web_command
          return
        end
        case bound_policy
          when nil
            slice_error("Cannot Find Bound Policy with UUID: [#@arg]")
          else
            print_object_array bound_policy.print_log, :style => :table
        end
      end

      def remove_bound
        @command_help_text = "razor policy remove bound[b] all|(uuid)"
        # Grab the arg
        @arg = @command_array.shift
        case @arg
          when "all" # if [all] we remove all instances
            setup_data # setup the data object
            @data.delete_all_objects(:bound_policy) # remove all policy instances
            slice_success("All Bound Policies deleted") # return success
          when nil
            slice_error("Command Error") # return error for no arg
          else
            policy = get_object("bound policy instances", :bound_policy, @arg) # attempt to find policy with uuid
            case policy
              when nil
                slice_error("Cannot Find Bound Policy with UUID: [#@arg]") # error when it is invalid
              else
                setup_data
                @data.delete_object_by_uuid(:bound_policy, @arg)
                slice_success("Bound Policy deleted")
            end
        end

      end

      def get_possible_model_configs
        @command = :get_possible_model_configs
        @command_help_text = "razor policy get [model|model_config] [all|(policy type)]"
        # TODO - This parsing get/post/line below for web should be in the Base object or Util. Need to make common and move. Too much repeating
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))
            # Policy type (must match a proper policy type)
            @policy_type = @vars_hash['policy_type']
          else
            #Same vars as above but pulled from CLI arg / Web PATH
            @policy_type = @command_array.first
          end
        end
        @policy_type = @command_array.first unless @policy_type
        case @policy_type
          when "all", '{}', nil
            # Just print all model configs
            print_object_array get_object("model_configs", :model), "All Model Configs"
          else
            possible_model_configs = []
            setup_data
            @data.fetch_all_objects(:model).each do |model_config|
              possible_model_configs << model_config if model_config.type.to_s == @policy_type.to_s
            end
            print_object_array possible_model_configs, "Valid Model Configs for (#{@policy_type.to_s})"
        end
      end

      def get_system_instances
        @command = :get_system_instances
        @command_help_text = "razor policy [get] systems"
        # Just print all system instances
        print_object_array get_object("system_instances", :systems), "All System Instances"
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
        active_bound_policy = nil
        engine.bound_policy.each do
        |bp|
          active_bound_policy = bp if bp.uuid == policy_uuid
        end
        if active_bound_policy != nil
          logger.debug "Active bound policy found for callback: #{callback_namespace}"
          make_callback(active_bound_policy, callback_namespace)
          return
        end
        slice_error("InvalidPolicyID")
      end

      def make_callback(bound_policy, callback_namespace)
        callback = bound_policy.model.callback[callback_namespace]
        if callback != nil
          setup_data
          node = @data.fetch_object_by_uuid(:node, bound_policy.node_uuid)
          callback_return = bound_policy.model.callback_init(callback, @command_array, node, bound_policy.uuid, bound_policy.system)
          bound_policy.update_self
          puts callback_return
        else
          slice_error("NoCallbackFound")
        end
      end
    end
  end
end


