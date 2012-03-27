# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# ProjectRazor Policy Base class
# Root abstract
module ProjectRazor
  module Policy
    class Base< ProjectRazor::Object
      attr_accessor :label
      attr_accessor :line_number
      attr_accessor :model
      attr_accessor :tags
      attr_reader :hidden
      attr_reader :policy_type
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
        @policy_type = :hidden
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
          @bound = true
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



    end
  end
end