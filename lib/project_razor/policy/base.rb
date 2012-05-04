# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# ProjectRazor Policy Base class
# Root abstract
module ProjectRazor
  module Policy
    class Base< ProjectRazor::Object
      include(ProjectRazor::Logging)

      attr_accessor :label
      attr_accessor :line_number
      attr_accessor :model
      attr_accessor :system
      attr_accessor :tags
      attr_reader :hidden
      attr_reader :type
      attr_reader :description

      # Used for binding
      attr_accessor :bound
      attr_accessor :node_uuid
      attr_accessor :bind_timestamp

      # TODO - method for setting tags that removes duplicates

      # @param hash [Hash]
      def initialize(hash)
        super()
        @tags = []
        @hidden = :true
        @type = :hidden
        @description = "Base policy rule object. Hidden"
        @node_uuid = nil
        @bind_timestamp = nil
        @bound = false
        from_hash(hash) unless hash == nil
        # If our policy is bound it is stored in a different collection
        if @bound
          @_collection = :bound_policy
        else
          @_collection = :policy_rule
        end
      end

      def bind_me(node)
        if node

          @model.counter = @model.counter + 1 # increment model counter
          self.update_self # save increment

          @bound = true
          @uuid = create_uuid
          @_collection = :bound_policy
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
      # intended to be called by node or daemon for connection/hand-off to systems
      def system_call(node, new_state)

      end

      def print_header
        if @bound
          return "Label", "Model Label", "Node UUID", "System", "Bind #", "UUID"
        else
          return "#", "Label", "Type", "Tags", "Model Label", "System Name", "Count", "UUID"
        end
      end

      def print_items
        if @bound
          system_name = @system ? @system.name : "none"
          return @label, @model.type.to_s, @node_uuid, system_name, @model.counter.to_s, @uuid
        else
          system_name = @system ? @system.name : "none"
          return @line_number.to_s, @label, @type.to_s, "[#{@tags.join(",")}]", @model.type.to_s, system_name, @model.counter.to_s, @uuid
        end
      end

      def print_item_header
        if @bound
          ["UUID",
           "Label",
           "Type",
           "Node UUID",
           "Model Label",
           "Model Name",
           "Current State",
           "System Name",
           "Bound Number",
           "Bind Time"]
        else
          ["UUID",
           "Line Number",
           "Label",
           "Type",
           "Description",
           "Tags",
           "Model Label",
           "System Name",
           "Bound Count"]
        end
      end

      def print_item
        if @bound
          system_name = @system ? @system.name : "none"
          [@uuid,
           @label,
           @type.to_s,
           @node_uuid,
           @model.label.to_s,
           @model.name.to_s,
           @model.current_state.to_s,
           system_name,
           @model.counter.to_s,
           Time.at(@bind_timestamp).strftime("%H:%M:%S %m-%d-%Y")]
        else
          system_name = @system ? @system.name : "none"
          [@uuid,
           @line_number.to_s,
           @label,
           @type.to_s,
           @description,
           "[#{@tags.join(", ")}]",
           @model.label.to_s,
           system_name,
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