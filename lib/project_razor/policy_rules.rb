# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
   # Copyright © 2012 EMC Corporation, All Rights Reserved

module ProjectRazor
  # Used for binding of policy+models to a node
  # this is permanent unless a user removed the binding or deletes a node
  class PolicyRules
    include(ProjectRazor::Logging)
    include(Singleton)

    POLICY_PREFIX = "ProjectRazor::Policy::"
    MODEL_PREFIX = "ProjectRazor::Model::"



    # Get Array of Model Configs that are compatible with a Policy Rule Type
    def get_model_configs(policy_type)
      model_configs = []
      $data.fetch_all_objects(:model).each do
        |mc|
        model_configs << mc if mc.model_type == policy_type
      end
      model_configs
    end

    # Get Array of Policy Rule available
    def get_types
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|

        if object_class.to_s.start_with?(POLICY_PREFIX) && object_class.to_s != POLICY_PREFIX
          temp_hash[object_class.to_s] = object_class.to_s.sub(POLICY_PREFIX,"").strip
        end
      end
      policy_type_array = {}
      temp_hash.each_value {|x| policy_type_array[x] = x}
      policy_type_array.each_value.collect {|x| x}

      valid_types = []
      policy_type_array.each do
        |policy_type|
        policy_type_obj = Object.full_const_get(POLICY_PREFIX + policy_type[0]).new({})
        valid_types << policy_type_obj if !policy_type_obj.hidden
      end

      valid_types
    end

    def get_model_types
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|

        if object_class.to_s.start_with?(MODEL_PREFIX) && object_class.to_s != MODEL_PREFIX
          temp_hash[object_class.to_s] = object_class.to_s.sub(MODEL_PREFIX,"").strip
        end
      end
      model_type_array = {}
      temp_hash.each_value {|x| model_type_array[x] = x}
      model_type_array.each_value.collect {|x| x}

      valid_types = []
      model_type_array.each do
      |model_type|
        model_type_obj = Object.full_const_get(MODEL_PREFIX + model_type[0]).new({})
        valid_types << model_type_obj if !model_type_obj.hidden
      end

      valid_types
    end

    def is_policy_type?(policy_type)
      get_types.each do
        |type|
        return true if type.policy_type.to_s == policy_type
      end
      false
    end

    def is_model_type?(model_name)
      get_model_types.each do
      |type|
        return type if type.name == model_name
      end
      false
    end


    def get
      # Get all the policy rules
      policy_rules_array = $data.fetch_all_objects(:policy_rule)

      logger.debug "Total policy rules #{policy_rules_array.count}"
      # Sort the policy rules based on line_number
      policy_rules_array.sort! do
      |a,b|
        a.line_number <=> b.line_number
      end
      policy_rules_array
    end

    # When adding a rule
    # Line number is preserved for updates, line_number is last for new

    def add(new_policy_rule)
      existing_policy = policy_exists?(new_policy_rule)
      if existing_policy
        new_policy_rule.line_number = existing_policy.line_number
      else
        new_policy_rule.line_number = last_line_number + 1
      end
      $data.persist_object(new_policy_rule)
    end

    alias :update :add


    def remove

    end

    # Down is up in numbers (++)
    def move_lines_down

    end

    def policy_exists?(new_policy_rule)
      $data.fetch_object_by_uuid(:policy_rule, new_policy_rule)
    end

    def last_line_number
      if get.last
        get.last.line_number
      else
        0
      end
    end

  end
end