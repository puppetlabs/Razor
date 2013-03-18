# ProjectRazor Policy Base class
# Root abstract
require 'project_razor/object'

module ProjectRazor
  module PolicyTemplate
    class Base< ProjectRazor::Object
      include(ProjectRazor::Logging)

      attr_accessor :label
      attr_accessor :enabled
      attr_accessor :model
      attr_accessor :broker
      attr_accessor :tags
      attr_accessor :maximum_count
      attr_reader :hidden
      attr_reader :template
      attr_reader :description

      # Used for binding
      attr_accessor :bound
      attr_accessor :root_policy
      attr_accessor :node_uuid
      attr_accessor :bind_timestamp

      # TODO - method for setting tags that removes duplicates

      # @param hash [Hash]
      def initialize(hash)
        super()
        @tags = []
        @hidden = :true

        @maximum_count = 0 # Default to no maximum
        @enabled = false
        @template = :hidden
        @description = "Base policy rule object. Hidden"
        @node_uuid = nil
        @bind_timestamp = nil
        @bound = false
        @noun = "policy"

        from_hash(hash) unless hash == nil
        # If our policy is bound it is stored in a different collection
        if @bound
          @_namespace = :active
        else
          @_namespace = :policy
        end
      end


      def tags=(new_tags)
        @tags = new_tags.uniq
      end

      def current_count
        engine = ProjectRazor::Engine.instance
        engine.policy_active_model_count(@uuid)
      end

      def is_under_maximum?
        return true if @maximum_count.to_s == "0"
        current_count < @maximum_count.to_i
      end

      def line_number
        policies = ProjectRazor::Policies.instance
        policies.get_line_number(self.uuid)
      end

      def bind_me(node)
        if node
          @model.counter = @model.counter + 1 # increment model counter
          self.update_self # save increment
          @bound = true
          @noun = "active_model"
          @root_policy = @uuid.to_s
          @uuid = create_uuid
          @_namespace = :active
          @bind_timestamp = Time.now.to_i
          @node_uuid = node.uuid
          true
        else
          false
        end
      end

      # These are required methods called by the engine for all policies
      # Called when a MK does a checkin from a node bound to this policy
      def mk_call(node)
        # This is our base model - we have nothing to do so we just tell the MK : acknowledge
        [:acknowledge, {}]
      end
      # Called from a node bound to this policy does a boot and requires a script
      def boot_call(node)

      end
      # Called from either REST slice call by node or daemon doing polling
      def state_call(node, new_state)

      end
      # Placeholder - may be removed and used within state_call
      # intended to be called by node or daemon for connection/hand-off to brokers
      def broker_call(node, new_state)

      end

      def print_header
        if @bound
          return "Label", "State", "Node UUID", "Broker", "Bind #", "UUID"
        else
          if @is_template
            return "Template", "Description"
          else
            return "#", "Enabled", "Label", "Tags", "Model Label", "#/Max", "Counter", "UUID"
          end
        end
      end

      def print_items
        if @bound
          broker_name = @broker ? @broker.name : "none"
          return @label, @model.current_state.to_s, @node_uuid, broker_name, @model.counter.to_s, @uuid
        else
          if @is_template
            return @template.to_s, @description.to_s
          else
            max_num = @maximum_count.to_i == 0 ? '-' : @maximum_count
            return line_number.to_s, @enabled.to_s, @label, "[#{@tags.join(",")}]", @model.label.to_s, "#{current_count.to_s}/#{max_num}", @model.counter.to_s, @uuid
          end
        end
      end

      def print_item_header
        if @bound
          ["UUID",
           "Label",
           "Template",
           "Node UUID",
           "Model Label",
           "Model Name",
           "Current State",
           "Broker Target",
           "Bound Number",
           "Bind Time"]
        else
          ["UUID",
           "Line Number",
           "Label",
           "Enabled",
           "Template",
           "Description",
           "Tags",
           "Model Label",
           "Broker Target",
           "Currently Bound",
           "Maximum Bound",
           "Bound Counter"]
        end
      end

      def print_item
        if @bound
          broker_name = @broker ? @broker.name : "none"
          [@uuid,
           @label,
           @template.to_s,
           @node_uuid,
           @model.label.to_s,
           @model.name.to_s,
           @model.current_state.to_s,
           broker_name,
           @model.counter.to_s,
           Time.at(@bind_timestamp).strftime("%H:%M:%S %m-%d-%Y")]
        else
          broker_name = @broker ? @broker.name : "none"
          [@uuid,
           line_number.to_s,
           @label,
           @enabled.to_s,
           @template.to_s,
           @description,
           "[#{@tags.join(", ")}]",
           @model.label.to_s,
           broker_name,
           current_count.to_s,
           @maximum_count.to_s,
           @model.counter.to_s]
        end
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      # Used to print our model log through slice printing
      # @return [Array]
      def print_log

        # First see if we have the HashPrint class already defined
        begin
          self.class.const_get :HashPrint # This throws an error so we need to use begin/rescue to catch
        rescue
          # Define out HashPrint class for this object
          define_hash_print_class
        end
        # Create an array to store our HashPrint objects
        attr_array = []
        # Take each element in our attributes_hash and store as a HashPrint object in our array
        @last_time = nil
        @model.log.each do
        |log_entry|
          @first_time ||= Time.at(log_entry["timestamp"])
          @last_time ||= Time.at(log_entry["timestamp"])
          @total_time_diff = (Time.at(log_entry["timestamp"].to_i) - @first_time)
          @last_time_diff = (Time.at(log_entry["timestamp"].to_i) - @last_time)
          attr_array << self.class.const_get(:HashPrint).new(%w(State Action Result Time Last Total Node),
                                                             [state_print(log_entry["old_state"].to_s,log_entry["state"].to_s),
                                                              log_entry["action"].to_s,
                                                              log_entry["result"].to_s,
                                                              Time.at(log_entry["timestamp"].to_i).strftime("%H:%M:%S"),
                                                              pretty_time(@last_time_diff.to_i),
                                                              pretty_time(@total_time_diff.to_i), node_uuid.to_s], line_color, header_color)
          @last_time = Time.at(log_entry["timestamp"])
        end
        # Return our array of HashPrint
        attr_array
      end

      def print_log_all
        # First see if we have the HashPrint class already defined
        begin
          self.class.const_get :HashPrint # This throws an error so we need to use begin/rescue to catch
        rescue
          # Define out HashPrint class for this object
          define_hash_print_class
        end
        # Create an array to store our HashPrint objects
        attr_array = []
        # Take each element in our attributes_hash and store as a HashPrint object in our array
        @last_time = nil
        @model.log.each do
        |log_entry|
          @first_time ||= Time.at(log_entry["timestamp"])
          @last_time ||= Time.at(log_entry["timestamp"])
          @total_time_diff = (Time.at(log_entry["timestamp"].to_i) - @first_time)
          @last_time_diff = (Time.at(log_entry["timestamp"].to_i) - @last_time)
          attr_array << self.class.const_get(:HashPrint).new(%w(State Action Result Time Last Total Node),
                                                             [state_print(log_entry["old_state"].to_s,log_entry["state"].to_s),
                                                              log_entry["action"].to_s,
                                                              log_entry["result"].to_s,
                                                              log_entry["timestamp"].to_i,
                                                              pretty_time(@last_time_diff.to_i),
                                                              pretty_time(@total_time_diff.to_i), node_uuid.to_s], line_color, header_color)
          @last_time = Time.at(log_entry["timestamp"])
        end
        # Return our array of HashPrint
        attr_array
      end

      def state_print(old_state, new_state)
        if old_state == new_state
          return new_state
        end
        "#{old_state}=>#{new_state}"
      end

      def pretty_time(in_time)
        float_time = in_time.to_f
        case
          when float_time < 60
            float_time.to_i.to_s + " sec"
          when float_time > 60
            ("%02.1f" % (float_time / 60)) + " min"
          else
            float_time.to_s + " sec"
        end
      end

    end
  end
end
