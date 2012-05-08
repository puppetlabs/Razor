# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root namespace for ProjectRazor
# @author Nicholas Weaver
module ProjectRazor
  module BrokerPlugin

    # Root namespace for Brokers defined in ProjectRazor for node hand off
    # @author Nicholas Weaver
    # @abstract
    class Base < ProjectRazor::Object
      attr_accessor :name
      attr_accessor :plugin
      attr_accessor :servers
      attr_accessor :description
      attr_accessor :user_description
      attr_accessor :hidden

      def initialize(hash)
        super()
        @hidden = true
        @plugin = :base
        @servers = []
        @description = "Base broker plugin - not used"
        @_collection = :broker
        from_hash(hash) if hash
      end

      def template
        @plugin
      end


      def agent_hand_off(options = {})

      end

      def proxy_hand_off(options = {})

      end

      # Method call for validating that a Broker instance successfully received the node
      def validate_broker_hand_off(options = {})
        # return false because the Base object does nothing
        # Child objects do not need to call super
        false
      end

      def print_header
        return "Name", "Description", "Plugin", "Servers", "UUID"
      end

      def print_items
        return @name, @user_description, @plugin.to_s, "[#{@servers.join(",")}]", @uuid
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