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
        return "#", "Label", "Type", "Tags", "Model Label", "System Name", "Count", "UUID"
      end

      def print_items
        system_name = @system ? @system.name : "none"
        return @line_number.to_s, @label, @type.to_s, "[#{@tags.join(",")}]", @model.type.to_s, system_name, @model.counter.to_s, @uuid
      end

      def print_item_header
        ["UUID",
         "Line Number",
         "Label",
         "Type",
         "Description",
         "Tags",
         "Model Label",
         "System Name",
         "Count"]
      end

      def print_item
        system_name = @system ? @system.name : "none"
        [@uuid,
         @line_number.to_s,
         @label,
         @type.to_s,
         @description,
         "[#{@tags.join(", ")}]",
         @model.type.to_s,
         system_name,
         @model.counter.to_s]
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

    end
  end
end