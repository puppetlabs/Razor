require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class XenServer < ProjectRazor::ModelTemplate::Base
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
        @hidden                  = true
        @template                = :xenserver_hypervisor
        @name                    = "xenserver_generic"
        @description             = "xenserver generic"
        # Metadata vars
        @hostname_prefix         = nil
        @gateway                 = nil
        @nameserver              = nil
        # State / must have a starting state
        @current_state           = :init
        # Image UUID
        @image_uuid              = true
        # Image prefix we can attach
        @image_prefix            = "xenserver"
        # Enable agent brokers for this model
        @broker_plugin           = :proxy
        @final_state             = :os_complete
        # Metadata vars
        @ip_range_network        = nil
        @ip_range_start          = nil
        @ip_range_end            = nil
        @gateway                 = nil
        @hostname_prefix         = nil
        @nameserver              = nil
        @ntpserver               = nil
        # Metadata
        @req_metadata_hash = {
            "@root_password"           => { :default     => "test1234",
                                            :example     => "P@ssword!",
                                            :validation  => '^[\S]{8,}',
                                            :required    => true,
                                            :description => "root password (> 8 characters)" },
            "@ip_range_network"        => { :default     => "",
                                            :example     => "192.168.10",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "IP Network for hosts" },
            "@ip_range_subnet"         => { :default     => "255.255.255.0",
                                            :example     => "255.255.255.0",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "IP Subnet" },
            "@ip_range_start"          => { :default     => "",
                                            :example     => "1",
                                            :validation  => '^\b(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                                            :required    => true,
                                            :description => "Starting IP address (1-254)" },
            "@ip_range_end"            => { :default     => "",
                                            :example     => "50",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                                            :required    => true,
                                            :description => "Ending IP address (2-255)" },
            "@gateway"                 => { :default     => "",
                                            :example     => "192.168.1.1",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "Gateway for node" },
            "@hostname_prefix"         => { :default     => "",
                                            :example     => "xs-node",
                                            :validation  => '^[A-Za-z\d-]{3,}$',
                                            :required    => true,
                                            :description => "Prefix for naming node" },
            "@nameserver"              => { :default     => "",
                                            :example     => "192.168.10.10",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "Nameserver for node" },
            "@ntpserver"               => { :default     => "",
                                            :example     => "ntp.razor.example.local",
                                            :validation  => '^[\w.]{3,}$',
                                            :required    => true,
                                            :description => "NTP server for node" }
        }
      end

      def node_ip_address
        "#{@ip_range_network}.#{(@ip_range_start..@ip_range_end).to_a[@counter - 1]}"
      end

      def hostname
        "#{@hostname_prefix}#{@counter.to_s}"
      end
      
      def broker_agent_handoff
        logger.debug "Broker agent called for: #{@broker.name}"
        if @node_ip
          options = {
            :username  => "root",
            :password  => @root_password,
            :metadata  => node_metadata,
            :uuid  => @node.uuid,
            :ipaddress => @node_ip_address,
          }
          @current_state = @broker.agent_hand_off(options)
        else
          logger.error "Node IP address isn't known"
          @current_state = :broker_fail
        end
        broker_fsm_log
      end
      
      def callback
        {
          "broker"                => :broker_agent_handoff,
          "isolinux_cfg"          => :isolinux_cfg_call,
          "xenserverinstall_xml"  => :xenserverinstall_xml_call,
          "postinstall"           => :postinstall,
        }
      end

      def fsm_tree
        {
            :init          => { :mk_call         => :init,
                                :boot_call       => :init,
                                :xenserverinstall_xml_start => :preinstall,
                                :xenserverinstall_xml_file  => :init,
                                :xenserverinstall_xml_end   => :postinstall,
                                :timeout         => :timeout_error,
                                :error           => :error_catch,
                                :else            => :init },
            :preinstall    => { :mk_call           => :preinstall,
                                :boot_call         => :preinstall,
                                :xenserverinstall_xml_start   => :preinstall,
                                :xenserverinstall_xml_file    => :init,
                                :xenserverinstall_xml_end     => :postinstall,
                                :xenserverinstall_xml_timeout => :timeout_error,
                                :error             => :error_catch,
                                :else              => :preinstall },
            :postinstall   => { :mk_call           => :postinstall,
                                :boot_call         => :postinstall,
                                :postinstall_end   => :os_complete,
                                :xenserverinstall_xml_file    => :postinstall,
                                :xenserverinstall_xml_end     => :postinstall,
                                :postinstallscript_inject => :postinstall,
                                :postinstall_inject => :postinstall,
                                :xenserverinstall_xml_timeout => :postinstall,
                                :error             => :error_catch,
                                :else              => :preinstall },
            :os_complete   => { :mk_call   => :os_complete,
                                :boot_call => :os_complete,
                                :else      => :os_complete,
                                :reset     => :init },
            :timeout_error => { :mk_call   => :timeout_error,
                                :boot_call => :timeout_error,
                                :else      => :timeout_error,
                                :reset     => :init },
            :error_catch   => { :mk_call   => :error_catch,
                                :boot_call => :error_catch,
                                :else      => :error_catch,
                                :reset     => :init },
        }
      end

      def xenserverinstall_xml_call
        @arg = @args_array.shift
        case @arg
          when  "start"
            @result = "Acknowledged xenserverinstall_xml  read"
            fsm_action(:xenserverinstall_xml_start, :xenserverinstall_xml)
            return "ok"
          when "end"
            @result = "Acknowledged xenserverinstall_xml end"
            fsm_action(:xenserverinstall_xml_end, :xenserverinstall_xml)
            return "ok"
          when "file"
            @result = "Replied with xenserverinstall_xml file"
            fsm_action(:xenserverinstall_xml_file, :xenserverinstall_xml)
            return generate_xenserverinstall_xml(@policy_uuid)
          else
            return "error"
        end
      end

      def isolinux_cfg_call
        generate_isolinux_cfg(@policy_uuid)
      end

      def mk_call(node, policy_uuid)
        super(node, policy_uuid)
        case @current_state
          # We need to reboot
          when :init, :preinstall, :postinstall, :os_complete
            ret = [:reboot, { }]
          when :timeout_error, :error_catch
            ret = [:acknowledge, { }]
          else
            ret = [:acknowledge, { }]
        end
        fsm_action(:mk_call, :mk_call)
        ret
      end

      def boot_call(node, policy_uuid)
        super(node, policy_uuid)
        case @current_state
          when :init, :preinstall
            ret = start_install(node, policy_uuid)
          when :postinstall, :os_complete, :broker_check, :broker_fail, :broker_success, :complete_no_broker
            ret = local_boot(node)
          when :timeout_error, :error_catch
            engine = ProjectRazor::Engine.instance
            ret    = engine.default_mk_boot(node.uuid)
          else
            engine = ProjectRazor::Engine.instance
            ret    = engine.default_mk_boot(node.uuid)
        end
        fsm_action(:boot_call, :boot_call)
        ret
      end

      def start_install(node, policy_uuid)
        filepath = template_filepath('boot_install')
        ERB.new(File.read(filepath)).result(binding)
      end

      def local_boot(node)
        filepath = template_filepath('boot_local')
        ERB.new(File.read(filepath)).result(binding)
      end

      def postinstall
        @arg = @args_array.shift
        case @arg
          when "download"
            fsm_action(:postinstallscript_inject, :postinstall)
            return postinstall_script(@policy_uuid)
          when "inject"
            fsm_action(:postinstall_inject, :postinstall)
            return os_boot_script(@policy_uuid)
          when "end"
            fsm_action(:postinstall_end, :postinstall)
            return "ok"
          when "debug"
            ret = "V"
            return ret
          else
            return "error"
        end
      end

      def os_boot_script(policy_uuid)
        @result = "Replied with os boot script"
        filepath = template_filepath('os_boot')
        ERB.new(File.read(filepath)).result(binding)
      end

      def postinstall_script(policy_uuid)
        @result = "Replied with postinstall script"
        filepath = template_filepath('postinstall')
        ERB.new(File.read(filepath)).result(binding)
      end

      def pxelinuxbin
        "pxelinux.0"
      end 

      def pxelinux_path
        "boot/pxelinux/pxelinux.0"
      end

      def pxelinuxconfigfile_path
        "#{api_svc_uri}/policy/callback/#{@policy_uuid}/isolinux_cfg"
      end

      def generate_xenserverinstall_xml(policy_uuid)
        # TODO: Review hostname
        hostname = "#{@hostname_prefix}#{@counter.to_s}"
        filepath = template_filepath('xenserverinstall_xml')
        ERB.new(File.read(filepath)).result(binding)
      end

      def generate_isolinux_cfg(policy_uuid)
        # TODO: Review hostname
        hostname = "#{@hostname_prefix}#{@counter.to_s}"
        filepath = template_filepath('isolinux_cfg')
        ERB.new(File.read(filepath)).result(binding)
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/xenserver"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end

      # ERB.result(binding) is failing in Ruby 1.9.2 and 1.9.3 so template is processed in the def block.
      def template_filepath(filename)
        raise ProjectRazor::Error::Slice::InternalError, "must provide xenserver version." unless @osversion
        filepath = File.join(File.dirname(__FILE__), "xenserver/#{@osversion}/#{filename}.erb")
      end

    end
  end
end

