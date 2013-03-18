module ProjectRazor
  # Used for binding of policy+models to a node
  # this is permanent unless a user removed the binding or deletes a node
  class Policies < ProjectRazor::Object
    include(ProjectRazor::Logging)
    include(Singleton)

    POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"
    MODEL_PREFIX = "ProjectRazor::ModelTemplate::"


    # table
    # ensure unique
    # store as single object


    class PolicyTable < ProjectRazor::Object
      attr_accessor :p_table
      def initialize(hash)
        super()
        # @todo danielp 2013-03-18: this non-UUID value is used to ensure that
        # we have a consistent value for this object, allowing us to access
        # the same object from any location that wants to modify it.
        #
        # We could, and probably should, use a real UUID hard-coded, but the
        # original authors didn't.  In migration to a real storage engine,
        # that totally should happen.
        @uuid = "policy_table"
        @_namespace = :policy_table
        @p_table = []
        from_hash(hash)
      end

      def get_line_number(policy_uuid)
        @p_table.each_with_index { |p_item_uuid, index| return index if p_item_uuid == policy_uuid }
      end

      def add_p_item(policy_uuid)
        @p_table.push policy_uuid unless exists_in_array?(policy_uuid)
        update_table
      end


      def resolve_duplicates
        @p_table.inject(Hash.new(0)) {|h,v| h[v] += 1; h}.reject{|k,v| v==1}.keys
      end

      def remove_missing
        policy_uuid_array = get_data.fetch_all_objects(:policy).map {|p| p.uuid}
        @p_table.map! do
        |p_item_uuid|
          p_item_uuid if policy_uuid_array.select {|uuid| uuid == p_item_uuid}.count > 0
        end
        @p_table.compact!
      end

      def exists_in_array?(policy_uuid)
        @p_table.each { |p_item_uuid|
          return true if p_item_uuid == policy_uuid }
        false
      end

      def update_table
        resolve_duplicates
        remove_missing
        self.update_self
      end

      def move_higher(policy_uuid)
        policy_index = find_policy_index(policy_uuid)
        unless policy_index == 0
          @p_table[policy_index], @p_table[policy_index - 1] = @p_table[policy_index - 1], @p_table[policy_index]
          update_table
          return true
        end
        false
      end

      def move_lower(policy_uuid)
        policy_index = find_policy_index(policy_uuid)
        #puts "#{policy_index} == #{(@p_table.count - 1)}"
        unless policy_index == (@p_table.count - 1)
          @p_table[policy_index], @p_table[policy_index + 1] = @p_table[policy_index + 1], @p_table[policy_index]
          update_table
          return true
        end
        false
      end

      def move_to_idx(policy_uuid, new_index)
        policy_index = find_policy_index(policy_uuid)
        #puts "#{policy_index} == #{(@p_table.count - 1)}"
        # throw an error if the new_index is not within the bounds of the policy table
        if new_index > (@p_table.count - 1) || new_index < 0
          raise ProjectRazor::Error::Slice::InputError, "New line number '#{new_index}' is not valid; should be an between 0 and #{@p_table.count - 1}"
        end
        # skip operation if new_index is the same as the existing index or out of the bounds
        # of the policy table
        unless new_index == policy_index
          if policy_index > new_index
            # moving policy higher
            while policy_index > new_index
              @p_table[policy_index], @p_table[policy_index - 1] = @p_table[policy_index - 1], @p_table[policy_index]
              policy_index -= 1
            end
          else
            # moving policy lower
            while policy_index < new_index
              @p_table[policy_index], @p_table[policy_index + 1] = @p_table[policy_index + 1], @p_table[policy_index]
              policy_index += 1
            end
          end
          update_table
          return true
        end
        false
      end

      def find_policy_index(policy_uuid)
        @p_table.index(policy_uuid)
      end

    end

    def policy_table
      policy_table_clean

      pt = get_data.fetch_object_by_uuid(:policy_table, "policy_table")
      return pt if pt
      pt = ProjectRazor::Policies::PolicyTable.new({})
      pt = get_data.persist_object(pt)
      raise ProjectRazor::Error::CannotCreatePolicyTable, "Cannot create policy table" unless pt
      pt
    end

    # This method ensures that no junk entries exist in the policy table collection
    # after a period of time this will be removed by a new code push
    # nweaver - 11/6/2012
    def policy_table_clean
      # Fetch all does automatic version cleanup for us.
      get_data.fetch_all_objects(:policy_table)
    end



    # Get Array of Models that are compatible with a Policy Template
    def get_models(model_template)
      models = []
      get_data.fetch_all_objects(:model).each do
      |mc|
        models << mc if mc.template == model_template
      end
      models
    end

    # Get Array of Policy Templates available
    def get_templates
      ProjectRazor::PolicyTemplate.class_children.map do |policy_template|
        policy_template_obj = ::Object.full_const_get(POLICY_PREFIX + policy_template[0]).new({})
        !policy_template_obj.hidden ? policy_template_obj : nil
      end.reject { |e| e.nil? }
    end

    def get_model_templates
      ProjectRazor::ModelTemplate.class_children.map do |policy_template|
        policy_template_obj = ::Object.full_const_get(MODEL_PREFIX + policy_template[0]).new({})
        !policy_template_obj.hidden ? policy_template_obj : nil
      end.reject { |e| e.nil? }
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
      policies_array = get_data.fetch_all_objects(:policy)
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
      get_data.persist_object(new_policy)
      pt = policy_table
      pt.add_p_item(new_policy.uuid)
    end

    alias :update :add

    def get_line_number(policy_uuid)
      pt = policy_table
      pt.get_line_number(policy_uuid)
    end

    # Down is up in numbers (++)
    def move_policy_up(policy_uuid)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.move_higher(policy_uuid)
    end

    def move_policy_down(policy_uuid)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.move_lower(policy_uuid)
    end

    def move_policy_to_idx(policy_uuid, new_idx)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.move_to_idx(policy_uuid, new_idx)
    end

    def policy_exists?(new_policy)
      get_data.fetch_object_by_uuid(:policy, new_policy)
    end

  end
end
