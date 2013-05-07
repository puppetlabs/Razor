require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class Opensuse12 < ProjectRazor::ModelTemplate::Base
      include(ProjectRazor::Logging)

      # Assigned image
      attr_accessor :image_uuid
      # Metadata
      attr_accessor :hostname
      # Compatible Image Prefix
      attr_accessor :image_prefix

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @template = :linux_deploy
        @name = "opensuse_12"
        @description = "OpenSuSE Suse 12 Model"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state = :init
        # Image UUID
        @image_uuid = true
        # Image prefix we can attach
        @image_prefix = "os"
        # Enable agent brokers for this model
        @broker_plugin = :agent
        @osversion = 12
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
        @req_metadata_hash = {
            "@hostname_prefix" => {
                :default     => "node",
                :example     => "node",
                :validation  => '^[a-zA-Z0-9][a-zA-Z0-9\-]*$',
                :required    => true,
                :description => "node hostname prefix (will append node number)"
            },
            "@root_password" => {
                :default     => "test1234",
                :example     => "P@ssword!",
                :validation  => '^[\S]{8,}',
                :required    => true,
                :description => "root password (> 8 characters)"
            },
        }
      end

      def callback
        {
          "broker"      => :broker_agent_handoff,
          "yast"        => :yast_call,
          "postinstall" => :postinstall_call,
        }
      end

      def broker_agent_handoff
        logger.debug "Broker agent called for: #{@broker.name}"
        if @node_ip
          options = {
              :username  => "root",
              :password  => @root_password,
              :metadata  => node_metadata,
              :uuid  => @node.uuid,
              :ipaddress => @node_ip,
          }
          @current_state = @broker.agent_hand_off(options)
        else
          logger.error "Node IP address isn't known"
          @current_state = :broker_fail
        end
        broker_fsm_log
      end

      def yast_call
        @arg = @args_array.shift
        case @arg
          when  "start"
            @result = "Acknowledged yast read"
            fsm_action(:yast_start, :yast)
            return "ok"
          when "end"
            @result = "Acknowledged yast end"
            fsm_action(:yast_end, :yast)
            return "ok"
          when "file"
            @result = "Replied with yast file"
            fsm_action(:yast_file, :yast)
            return generate_yast(@policy_uuid)
          else
            return "error"
        end
      end

      def postinstall_call
        @arg = @args_array.shift
        case @arg
          when "inject"
            fsm_action(:postinstall_inject, :postinstall)
            return os_boot_script(@policy_uuid)
          when "boot"
            fsm_action(:os_boot, :postinstall)
            return os_complete_script(@node)
          when "source_fix"
            fsm_action(:source_fix, :postinstall)
            return
          when "send_ips"
            #fsm_action(:source_fix, :postinstall)
            # Grab IP string
            @ip_string = @args_array.shift
            logger.debug "Node IP String: #{@ip_string}"
            @node_ip = @ip_string if @ip_string =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
            return
          else
            fsm_action(@arg.to_sym, :postinstall)
            return
        end
      end

      # Defines our FSM for this model
      #  For state => {action => state, ..}
      def fsm_tree
        {
            :init => {
                :mk_call       => :init,
                :boot_call     => :init,
                :yast_start => :preinstall,
                :yast_file  => :init,
                :yast_end   => :postinstall,
                :timeout       => :timeout_error,
                :error         => :error_catch,
                :else          => :init
            },
            :preinstall => {
                :mk_call         => :preinstall,
                :boot_call       => :preinstall,
                :yast_start   => :preinstall,
                :yast_file    => :init,
                :yast_end     => :postinstall,
                :yast_timeout => :timeout_error,
                :error           => :error_catch,
                :else            => :preinstall
            },
            :postinstall => {
                :mk_call            => :postinstall,
                :boot_call          => :postinstall,
                :yast_end        => :postinstall,
                :source_fix         => :postinstall,
                :postinstall_inject => :postinstall,
                :os_boot            => :os_complete,
                :post_error         => :error_catch,
                :post_timeout       => :timeout_error,
                :error              => :error_catch,
                :else               => :postinstall
            },
            :os_complete => {
                :mk_call   => :os_complete,
                :boot_call => :os_complete,
                :else      => :os_complete,
                :reset     => :init
            },
            :timeout_error => {
                :mk_call   => :timeout_error,
                :boot_call => :timeout_error,
                :else      => :timeout_error,
                :reset     => :init
            },
            :error_catch => {
                :mk_call   => :error_catch,
                :boot_call => :error_catch,
                :else      => :error_catch,
                :reset     => :init
            },
        }
      end

      def mk_call(node, policy_uuid)
        super(node, policy_uuid)
        case @current_state
          # We need to reboot
          when :init, :preinstall, :postinstall, :os_validate, :os_complete, :broker_check, :broker_fail, :broker_success
            ret = [:reboot, {}]
          when :timeout_error, :error_catch
            ret = [:acknowledge, {}]
          else
            ret = [:acknowledge, {}]
        end
        fsm_action(:mk_call, :mk_call)
        ret
      end

      def boot_call(node, policy_uuid)
        super(node, policy_uuid)
        case @current_state
          when :init, :preinstall
            @result = "Starting Suse model install"
            ret = start_install(node, policy_uuid)
          when :postinstall, :os_complete, :broker_check, :broker_fail, :broker_success, :complete_no_broker
            ret = local_boot(node)
          when :timeout_error, :error_catch
            engine = ProjectRazor::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
          else
            engine = ProjectRazor::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
        end
        fsm_action(:boot_call, :boot_call)
        ret
      end

      # ERB.result(binding) is failing in Ruby 1.9.2 and 1.9.3 so template is processed in the def block.
      def template_filepath(filename)
        raise ProjectRazor::Error::Slice::InternalError, "must provide suse version." unless @osversion
        filepath = File.join(File.dirname(__FILE__), "suse/#{@osversion}/#{filename}.erb")
      end

      def os_boot_script(policy_uuid)
        @result = "Replied with os boot script"
        filepath = template_filepath('os_boot')
        ERB.new(File.read(filepath)).result(binding)
      end

      def os_complete_script(node)
        @result = "Replied with os complete script"
        filepath = template_filepath('os_complete')
        ERB.new(File.read(filepath)).result(binding)
      end

      def start_install(node, policy_uuid)
        filepath = template_filepath('boot_install')
        ERB.new(File.read(filepath)).result(binding)
      end

      def local_boot(node)
        filepath = template_filepath('boot_local')
        ERB.new(File.read(filepath)).result(binding)
      end

      def kernel_args(policy_uuid)
        filepath = template_filepath('kernel_args')
        ERB.new(File.read(filepath)).result(binding)
      end

      def hostname
        "#{@hostname_prefix}#{@counter.to_s}"
      end

      def kernel_path
        "boot/x86_64/loader/linux"
      end

      def initrd_path
        "boot/x86_64/loader/initrd"
      end

      def config
        ProjectRazor.config
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/os"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end

      def generate_yast(policy_uuid)
        # TODO: Review hostname
        hostname = "#{@hostname_prefix}#{@counter.to_s}"
        filepath = template_filepath('autoyast')
        ERB.new(File.read(filepath)).result(binding)
      end

    end
  end
end
