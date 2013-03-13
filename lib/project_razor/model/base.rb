require "json"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class Base < ProjectRazor::Object
      include(ProjectRazor::Logging)

      attr_accessor :name
      attr_accessor :label
      attr_accessor :template
      attr_accessor :description
      attr_accessor :hidden
      attr_accessor :callback
      attr_accessor :current_state
      attr_accessor :node_bound
      attr_accessor :broker_plugin
      attr_accessor :final_state
      attr_accessor :counter
      attr_accessor :log
      attr_accessor :req_metadata_hash

      # init
      # @param hash [Hash]
      def initialize(hash)
        super()
        @name = "model_base"
        @hidden = true
        @template = :base
        @noun = "model"
        @description = "Base model template"
        @req_metadata_hash = {}
        @callback = {}
        @current_state = :init
        @node = nil
        @policy_bound = nil
        @broker_plugin = false # by default
        @final_state = :nothing
        @counter = 0
        @result = nil
                               # Model Log
        @log = []
        @_namespace = :model
        from_hash(hash) unless hash == nil
      end

      def callback_init(callback_namespace, args_array, node, policy_uuid, broker)
        @broker = broker
        @args_array = args_array
        @node = node
        @policy_uuid = policy_uuid
        logger.debug "callback method called #{callback_namespace}"
        self.send(callback_namespace)
      end

      def fsm
        # used to defined base tree elements like Broker
        base_fsm_tree = {
            :broker_fail => {
                :else => :broker_fail,
                :retry => @final_state},
            :broker_wait => {
                :else => :broker_wait},
            :broker_success => {
                :else => :broker_success},
            :complete_no_broker => {
                :else => :complete_no_broker}
        }
        fsm_tree.merge base_fsm_tree
      end

      def fsm_tree
        # Overridden with custom tree within child model
        {}
      end

      def fsm_action(action, method)
        # We only change state if we have a node bound
        if @node
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
            raise e
          end

        else
          logger.debug "Action #{action} called with state #{@current_state} but no Node bound"
        end
        fsm_log(:state => @current_state,
                :old_state => old_state,
                :action => action,
                :method => method,
                :node_uuid => @node.uuid,
                :timestamp => Time.now.to_i)
        # If in final state we check broker assignment
        if @current_state.to_s == @final_state.to_s # Enable to help with broker debug || @current_state.to_s == "broker_fail"
          broker_check
        end
      end

      def fsm_log(options)
        logger.debug "state update: #{options[:old_state]} => #{options[:state]} on #{options[:action]} for #{options[:node_uuid]}"
        options[:result] = @result
        options[:result] ||= "n/a"
        @log << options
        @result = nil
      end

      def broker_check
        # We need to check if a broker is attached
        unless @broker
          logger.error "No broker defined"
          @result = "No broker attached"
          @current_state = :complete_no_broker
          fsm_log(:state => @current_state,
                  :old_state => @final_state,
                  :action => :broker_check,
                  :method => :broker_check,
                  :node_uuid => @node.uuid,
                  :timestamp => Time.now.to_i)
          return
        end
        case @broker_plugin
          when :agent
            return broker_agent_handoff
          when :proxy
            return broker_proxy_handoff
          else
            return false # Brokers disabled for model
        end
      end

      def broker_agent_handoff
        # Implemented by child model
        false
      end

      def broker_proxy_handoff
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
          meta[:razor_active_model_uuid] = @policy_uuid
          meta[:razor_model_uuid] = @uuid
          meta[:razor_model_name] = @name
          meta[:razor_model_description] = @description
          meta[:razor_model_template] = @template.to_s
          meta[:razor_policy_count] = @counter.to_s
          logger.debug "Finished metadata build"
        rescue => e
          logger.error "metadata error: #{e}"
        end
        meta
      end

      def callback_url(namespace, action)
        "#{api_svc_uri}/policy/callback/#{@policy_uuid}/#{namespace}/#{action}"
      end

      def print_header
        if @is_template
          return "Template Name", "Description"
        else
          return "Label", "Template", "Description", "UUID"
        end
      end

      def print_item
        if @is_template
          return @name.to_s, @description.to_s
        else
          image_uuid_str = image_uuid ? image_uuid : "n/a"
          return @label, @template.to_s, @description, @uuid, image_uuid_str
        end
      end

      def print_item_header
        if @is_template
          return "Template Name", "Description"
        else
          return "Label", "Template", "Description", "UUID", "Image UUID"
        end
      end

      def print_items
        if @is_template
          return @name.to_s, @description.to_s
        else
          return @label, @template.to_s, @description, @uuid
        end
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      def config
        ProjectRazor.config
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/#{@image_prefix}"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end

      def web_create_metadata(provided_metadata)
        missing_metadata = []
        rmd = req_metadata_hash
        rmd.each_key do
        |md|
          metadata = map_keys_to_symbols(rmd[md])
          provided_metadata = map_keys_to_symbols(provided_metadata)
          md = (!md.is_a?(Symbol) ? md.gsub(/^@/,'').to_sym : md)
          md_fld_name = '@' + md.to_s
          if provided_metadata[md]
            raise ProjectRazor::Error::Slice::InvalidModelMetadata, "Invalid Metadata [#{md.to_s}:'#{provided_metadata[md]}']" unless
                set_metadata_value(md_fld_name, provided_metadata[md], metadata[:validation])
          else
            if metadata[:default] != ""
              raise ProjectRazor::Error::Slice::MissingModelMetadata, "Missing metadata [#{md.to_s}]" unless
                  set_metadata_value(md_fld_name, metadata[:default], metadata[:validation])
            else
              raise ProjectRazor::Error::Slice::MissingModelMetadata, "Missing metadata [#{md.to_s}]" if metadata[:required]
            end
          end
        end
      end

      def cli_create_metadata
        puts "--- Building Model (#{name}): #{label}\n".yellow
        req_metadata_hash.each_key { |key|
          metadata = map_keys_to_symbols(req_metadata_hash[key])
          key = key.to_sym if !key.is_a?(Symbol)
          flag = false
          until flag
            print "Please enter " + "#{metadata[:description]}".yellow.bold
            print " (example: " + "#{metadata[:example]}".yellow + ") \n"
            puts "default: " + "#{metadata[:default]}".yellow if metadata[:default] != ""
            puts metadata[:required] ? quit_option : skip_quit_option
            print " > "
            response = STDIN.gets.strip
            case response
              when "SKIP"
                if metadata[:required]
                  puts "Cannot skip, value required".red
                else
                  flag = true
                end
              when "QUIT"
                return false
              when ""
                if metadata[:default] != ""
                  flag = set_metadata_value(key, metadata[:default], metadata[:validation])
                else
                  puts "No default value, must enter something".red
                end
              else
                flag = set_metadata_value(key, response, metadata[:validation])
                puts "Value (".red + "#{response}".yellow + ") is invalid".red unless flag
            end
          end
        }
        true
      end

      def map_keys_to_symbols(hash)
        tmp = {}
        hash.each { |key, val|
          key = key.to_sym if !key.is_a?(Symbol)
          tmp[key] = val
        }
        tmp
      end

      def set_metadata_value(key, value, validation)
        regex = Regexp.new(validation)
        if regex =~ value
          self.instance_variable_set(key.to_sym, value)
          true
        else
          false
        end
      end

      def skip_quit_option
        "(" + "SKIP".white + " to skip, " + "QUIT".red + " to cancel)"
      end

      def quit_option
        "(" + "QUIT".red + " to cancel)"
      end

      def mk_call(node, policy_uuid)
        @node, @policy_uuid = node, policy_uuid
      end

      def boot_call(node, policy_uuid)
        @node, @policy_uuid = node, policy_uuid
      end

      def broker_fsm_log
        fsm_log(:state     => @current_state,
                :old_state => @final_state,
                :action    => :broker_agent_handoff,
                :method    => :broker,
                :node_uuid => @node.uuid,
                :timestamp => Time.now.to_i)
      end
    end
  end
end
