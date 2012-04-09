# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class Base < ProjectRazor::Object
      attr_accessor :name
      attr_accessor :label
      attr_accessor :model_type
      attr_accessor :description
      attr_accessor :hidden
      attr_accessor :callback
      attr_accessor :current_state
      attr_accessor :node_bound
      attr_accessor :log

      # init
      # @param hash [Hash]
      def initialize(hash)
        super()

        @name = "model_base"
        @hidden = true
        @model_type = :base
        @description = "Base model type"


        @req_metadata_hash = {}

        @callback = {}

        @current_state = :init

        @node_bound = nil
        @policy_bound = nil

        # Model Log
        @log = []


        @_collection = :model
        from_hash(hash) unless hash == nil
      end



      def fsm
        {}
      end


      def fsm_action(action, method)
        # We only change state if we have a node bound
        if @node_bound
          old_state = @current_state
          if fsm[@current_state][action] != nil
            @current_state = fsm[@current_state][action]
          else
            @current_state = fsm[@current_state][:else]
          end
          logger.debug "state update: #{old_state} => #{@current_state} on #{action} for #{node_bound.uuid}"
          @log << {:state => @current_state,
                   :old_state => old_state,
                   :action => action,
                   :method => method,
                   :node_uuid => node_bound.uuid,
                   :timestamp => Time.now.to_i}
        else
          logger.debug "Action #{action} called with state #{@current_state} but no Node bound"
        end

      end


      def print_header
        return "Label", "Type", "Description", "UUID"
      end

      def print_items
        return @label, @model_type.to_s, @description, @uuid
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      def config
        $data.config
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/#{@image_prefix}"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end


    end
  end
end
