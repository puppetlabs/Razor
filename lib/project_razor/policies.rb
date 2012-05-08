# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

module ProjectRazor
  # Used for binding of policy+models to a node
  # this is permanent unless a user removed the binding or deletes a node
  class Policies
    include(ProjectRazor::Logging)
    include(Singleton)

    POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"
    MODEL_PREFIX = "ProjectRazor::ModelTemplate::"



    # Get Array of Models that are compatible with a Policy Template
    def get_models(model_template)
      models = []
      $data.fetch_all_objects(:model).each do
      |mc|
        models << mc if mc.template == model_template
      end
      models
    end

    # Get Array of Policy Templates available
    def get_templates
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|
        if object_class.to_s.start_with?(POLICY_PREFIX) &&
            object_class.to_s != POLICY_PREFIX &&
            (/#/ =~ object_class.to_s) == nil
          temp_hash[object_class.to_s] = object_class.to_s.sub(POLICY_PREFIX,"").strip
        end
      end
      policy_template_array = {}
      temp_hash.each_value {|x| policy_template_array[x] = x}
      policy_template_array.each_value.collect {|x| x}
      valid_templates = []
      policy_template_array.each do
      |policy_template|
        policy_template_obj = Object.full_const_get(POLICY_PREFIX + policy_template[0]).new({})
        valid_templates << policy_template_obj if !policy_template_obj.hidden
      end
      valid_templates
    end

    def get_model_templates
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|
        if object_class.to_s.start_with?(MODEL_PREFIX) && object_class.to_s != MODEL_PREFIX
          temp_hash[object_class.to_s] = object_class.to_s.sub(MODEL_PREFIX,"").strip
        end
      end
      model_template_array = {}
      temp_hash.each_value {|x| model_template_array[x] = x}
      model_template_array.each_value.collect {|x| x}
      valid_templates = []
      model_template_array.each do
      |model_template|
        model_template_obj = Object.full_const_get(MODEL_PREFIX + model_template[0]).new({})
        valid_templates << model_template_obj if !model_template_obj.hidden
      end
      valid_templates
    end

    def new_policy_from_template_name(policy_template_name)
      get_templates.each do
      |template|
        return template if template.template.to_s == policy_template_name
      end
      template
    end

    def is_policy_template?(policy_template_name)
      get_templates.each do
      |template|
        return true if template.template.to_s == policy_template_name
      end
      false
    end

    def is_model_template?(model_name)
      get_model_templates.each do
      |template|
        return template if template.name == model_name
      end
      false
    end


    def get
      # Get all the policy templates
      policies_array = $data.fetch_all_objects(:policy)

      logger.debug "Total policies #{policies_array.count}"
      # Sort the policies based on line_number
      policies_array.sort! do
      |a,b|
        a.line_number <=> b.line_number
      end
      policies_array
    end

    # When adding a policy
    # Line number is preserved for updates, line_number is last for new

    def add(new_policy)
      existing_policy = policy_exists?(new_policy)
      if existing_policy
        new_policy.line_number = existing_policy.line_number
      else
        new_policy.line_number = last_line_number + 1
      end
      $data.persist_object(new_policy)
    end

    alias :update :add


    # Down is up in numbers (++)
    def move_lines_down

    end

    def policy_exists?(new_policy)
      $data.fetch_object_by_uuid(:policy, new_policy)
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