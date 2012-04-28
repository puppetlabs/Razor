# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class Base < ProjectRazor::Object
      include(ProjectRazor::Logging)

      attr_accessor :name
      attr_accessor :label
      attr_accessor :type
      attr_accessor :description
      attr_accessor :hidden
      attr_accessor :callback
      attr_accessor :current_state
      attr_accessor :node_bound
      attr_accessor :system_type
      attr_accessor :final_state
      attr_accessor :counter
      attr_accessor :log

      # init
      # @param hash [Hash]
      def initialize(hash)
        super()
        @name = "model_base"
        @hidden = true
        @type = :base
        @description = "Base model type"
        @req_metadata_hash = {}
        @callback = {}
        @current_state = :init
        @node_bound = nil
        @policy_bound = nil
        @system_type = false # by default
        @final_state = :nothing
        @counter = 0
                             # Model Log
        @log = []
        @_collection = :model
        from_hash(hash) unless hash == nil
      end

      def callback_init(callback_namespace, args_array, node, policy_uuid, system)
        @system = system
        @args_array = args_array
        @node = node
        @policy_uuid = policy_uuid
        logger.debug "callback method called #{callback_namespace}"
        self.send(callback_namespace)
      end

      def fsm
        # used to defined base tree elements like System
        base_fsm_tree = {
            :system_fail => {
                :else => :system_fail,
                :retry => @final_state},
            :system_wait => {
                :else => :system_wait},
            :system_success => {
                :else => :system_success}
        }
        fsm_tree.merge base_fsm_tree
      end

      def fsm_tree
        # Overridden with custom tree within child model
        {}
      end

      def fsm_action(action, method)
        # We only change state if we have a node bound
        if @node_bound
          old_state = @current_state
          old_state = :init unless old_state
          begin
            if fsm[@current_state][action] != nil
              @current_state = fsm[@current_state][action]
            else
              @current_state = fsm[@current_state][:else]
            end
          rescue => e
            logger.error "FSM ERROR: #{e.message}"
          end

        else
          logger.debug "Action #{action} called with state #{@current_state} but no Node bound"
        end
        fsm_log(:state => @current_state,
                :old_state => old_state,
                :action => action,
                :method => method,
                :node_uuid => node_bound.uuid,
                :timestamp => Time.now.to_i)
        # If in final state we check system assignment
        if @current_state.to_s == @final_state.to_s || @current_state.to_s == "system_fail"
          system_check
        end
      end

      def fsm_log(options)
        logger.debug "state update: #{options[:old_state]} => #{options[:state]} on #{options[:action]} for #{options[:node_uuid]}"
        @log << options
      end

      def system_check
        # We need to check if a system is attached
        unless @system
          logger.error "No system defined"
          return
        end
        case @system_type
          when :agent
            return system_agent_handoff
          when :proxy
            return false # Replace with proxy handling
          else
            return false # Systems disabled for model
        end
        false
      end

      def system_agent_handoff
        # Implemented by child model
        false
      end

      def node_metadata
        begin
        logger.debug "Building metadata"
        meta = {}
        logger.debug "Adding razor stuff"
        meta[:razor_tags] = @node.tags.join(',')
        meta[:razor_node_uuid] = @node.uuid
        meta[:razor_bound_policy_uuid] = @policy_uuid
        meta[:razor_model_uuid] = @uuid
        meta[:razor_model_name] = @name
        meta[:razor_model_description] = @description
        meta[:razor_model_type] = @type.to_s
        meta[:razor_policy_count] = @counter.to_s
        logger.debug "Finished metadata build"
        rescue => e
          logger.error "metadata error: #{p e}"
        end
        meta
      end

      def callback_url(namespace, action)
        "#{api_svc_uri}/policy/callback/#{@policy_uuid}/#{namespace}/#{action}"
      end

      def print_header
        return "Label", "Type", "Description", "UUID"
      end

      def print_items
        return @label, @type.to_s, @description, @uuid
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
