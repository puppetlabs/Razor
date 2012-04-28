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
    class Newpolicy < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Policy including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @new_slice_style = true # switch to new slice style
                                # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_policy",
                           :get => {["all", '{}', /^{.*}$/, nil] => "get_policy_all",
                                    [/type/,"t"] => "get_policy_types",
                                    [/^[Mm]odel/,"model_config","possible_models"] => {:default => "get_possible_model_configs",
                                                                                       :help => "razor policy get [model|model_config] [all|(policy type)]",
                                                                                       :else => "get_possible_model_configs"},
                                    [/^system/] => "get_system_instances",
                                    :default => "get_policy_all",
                                    :else => "get_policy_with_uuid",
                                    :help => "razor policy get all|type|(uuid)"},
                           :type => "get_policy_types",
                           [/type/,"t"] => "get_policy_types",
                           # TODO - Add :move => :up + :down for Policy Rules
                           :default => "get_policy_all",
                           :remove => "remove_policy",
                           :else => :get,
                           :help => "razor policy add|remove|get [all|type|(policy rule uuid)|models|systems]"}
        @slice_name = "Newpolicy"
      end

      # Returns all policy instances
      def get_policy_all
        # Get all policy instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("policy_instances", :policy_rule), "Policy Rules"
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
        @command_help_text = "razor policy remove all|(uuid)"
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
          when "all", '{}'
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
    end
  end
end


