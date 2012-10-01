# Root namespace for ProjectRazor
module ProjectRazor
  module BrokerPlugin

    # Root namespace for Brokers defined in ProjectRazor for node hand off
    # @abstract
    class Base < ProjectRazor::Object
      attr_accessor :name
      attr_accessor :plugin
      attr_accessor :servers
      attr_accessor :broker_version
      attr_accessor :description
      attr_accessor :user_description
      attr_accessor :hidden

      def initialize(hash)
        super()
        @hidden = true
        @plugin = :base
        @noun = "broker"
        @servers = []
        @broker_version = nil
        @description = "Base broker plugin - not used"
        @_namespace = :broker
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
        if @is_template
          return "Plugin", "Description"
        else
          return "Name", "Description", "Plugin", "Servers", "UUID", "Version"
        end
      end

      def print_items
        if @is_template
          return @plugin.to_s, @description.to_s
        else
          # Default string is printed for the broker if the version is false or nil (supports old brokers)
          broker_version = (@broker_version.nil? || !@broker_version) ? "Default" : @broker_version
          return @name, @user_description, @plugin.to_s, "[#{@servers.join(",")}]", @uuid, broker_version
        end
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
