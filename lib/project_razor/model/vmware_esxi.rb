require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class VMwareESXi < ProjectRazor::ModelTemplate::Base
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
        @template                = :vmware_hypervisor
        @name                    = "vmware_esx_generic"
        @description             = "vmware esxi generic"
        # Metadata vars
        @hostname_prefix         = nil
        # State / must have a starting state
        @current_state           = :init
        # Image UUID
        @image_uuid              = true
        # Image prefix we can attach
        @image_prefix            = "esxi"
        # Enable agent brokers for this model
        @broker_plugin           = :proxy
        @final_state             = :os_complete
        # Metadata vars
        @esx_license             = nil
        @ip_range_network        = nil
        @ip_range_start          = nil
        @ip_range_end            = nil
        @gateway                 = nil
        @hostname_prefix         = nil
        @nameserver              = nil
        @ntpserver               = nil
        @vcenter_name            = nil
        @vcenter_datacenter_path = nil
        @vcenter_cluster_path    = nil
        # Metadata
        @req_metadata_hash       = {
            "@esx_license"             => { :default     => "",
                                            :example     => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
                                            :validation  => '^[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}$',
                                            :required    => true,
                                            :description => "ESX License Key" },
            "@root_password"           => { :default     => "test1234",
                                            :example     => "P@ssword!",
                                            :validation  => '^[\S]{8,}',
                                            :required    => true,
                                            :description => "root password (> 8 characters)"
            },
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
                                            :example     => "esxi-node",
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
                                            :description => "NTP server for node" },
            "@vcenter_name"            => { :default     => "",
                                            :example     => "vcenter01",
                                            :validation  => '^[\w.-]{3,}$',
                                            :required    => false,
                                            :description => "Optional for broker use: the vCenter to attach ESXi node to" },
            "@vcenter_datacenter_path" => { :default     => "",
                                            :example     => "Datacenter01",
                                            :validation  => '^[a-zA-Z\d-]{3,}$',
                                            :required    => false,
                                            :description => "Optional for broker use: the vCenter Datacenter path to place ESXi host in" },
            "@vcenter_cluster_path"    => { :default     => "",
                                            :example     => "Cluster01",
                                            :validation  => '^[a-zA-Z\d-]{3,}$',
                                            :required    => false,
                                            :description => "Optional for broker use: the vCenter Cluster to place ESXi node in" }


        }

        from_hash(hash) unless hash == nil
      end

      def node_ip_address
        "#{@ip_range_network}.#{(@ip_range_start..@ip_range_end).to_a[@counter - 1]}"
      end

      def node_hostname
        @hostname_prefix + @counter.to_s
      end

      def broker_proxy_handoff
        logger.debug "Broker proxy called for: #{@broker.name}"
        if node_ip_address
          options = {
              :username                => "root",
              :password                => @root_password,
              :metadata                => node_metadata,
              :hostname                => node_hostname,
              :uuid                    => @node.uuid,
              :ipaddress               => node_ip_address,
              :vcenter_name            => @vcenter_name,
              :vcenter_datacenter_path => @vcenter_datacenter_path,
              :vcenter_cluster_path    => @vcenter_cluster_path,
          }
          @current_state = @broker.proxy_hand_off(options)
        else
          logger.error "Node IP address isn't known"
          @current_state = :broker_fail
        end
        broker_fsm_log
      end

      def callback
        {
          "broker"      => :broker_agent_handoff,
          "boot_cfg"    => :boot_cfg,
          "kickstart"   => :kickstart,
          "postinstall" => :postinstall,
        }
      end

      def fsm_tree
        {
            :init          => { :mk_call         => :init,
                                :boot_call       => :init,
                                :kickstart_start => :preinstall,
                                :kickstart_file  => :init,
                                :kickstart_end   => :postinstall,
                                :timeout         => :timeout_error,
                                :error           => :error_catch,
                                :else            => :init },
            :preinstall    => { :mk_call           => :preinstall,
                                :boot_call         => :preinstall,
                                :kickstart_start   => :preinstall,
                                :kickstart_file    => :init,
                                :kickstart_end     => :postinstall,
                                :kickstart_timeout => :timeout_error,
                                :error             => :error_catch,
                                :else              => :preinstall },
            :postinstall   => { :mk_call           => :postinstall,
                                :boot_call         => :postinstall,
                                :postinstall_end   => :os_complete,
                                :kickstart_file    => :postinstall,
                                :kickstart_end     => :postinstall,
                                :kickstart_timeout => :postinstall,
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
        ip = "#!ipxe\n"
        ip << "echo Reached #{@label} model boot_call\n"
        ip << "echo Our image UUID is: #{@image_uuid}\n"
        ip << "echo Our state is: #{@current_state}\n"
        ip << "echo Our node UUID: #{node.uuid}\n"
        ip << "\n"
        ip << "echo We will be running an install now\n"
        ip << "sleep 3\n"
        ip << "\n"
        ip << "kernel --name mboot.c32 #{image_svc_uri}/#{@image_uuid}/mboot.c32\n"
        ip << "imgargs mboot.c32 -c #{api_svc_uri}/policy/callback/#{policy_uuid}/boot_cfg\n"
        ip << "boot\n"
        ip
      end

      def local_boot(node)
        ip = "#!ipxe\n"
        ip << "echo Reached #{@label} model boot_call\n"
        ip << "echo Our image UUID is: #{@image_uuid}\n"
        ip << "echo Our state is: #{@current_state}\n"
        ip << "echo Our node UUID: #{node.uuid}\n"
        ip << "\n"
        ip << "echo Continuing local boot\n"
        ip << "sleep 3\n"
        ip << "\n"
        ip << "sanboot --no-describe --drive 0x80\n"
        ip
      end


      def kickstart
        @arg = @args_array.shift
        case @arg
          when "start"
            fsm_action(:kickstart_start, :kickstart)
            return "ok"
          when "end"
            fsm_action(:kickstart_end, :kickstart)
            return "ok"
          when "file"
            fsm_action(:kickstart_file, :kickstart)
            return kickstart_file
          else
            return "error"
        end
      end

      def postinstall
        @arg = @args_array.shift
        case @arg
          when "end"
            fsm_action(:postinstall_end, :postinstall)
            return "ok"
          when "debug"
            ret = ""
            ret << "vcenter: #{@vcenter_name}\n"
            ret << "vcenter: #{@vcenter_datacenter_path}\n"
            ret << "vcenter: #{@vcenter_cluster_path}\n"
            return ret
          else
            return "error"
        end
      end

      def boot_cfg
        @image = get_data.fetch_object_by_uuid(:images, @image_uuid)
        if @node.dhcp_mac
          @image.boot_cfg.gsub("/",
                               "#{image_svc_uri}/#{@image_uuid}/").gsub("runweasel",
                                                                        "ks=#{api_svc_uri}/policy/callback/#{@policy_uuid}/kickstart/file BOOTIF=#{@node.dhcp_mac}")
        else
          @image.boot_cfg.gsub("/",
                               "#{image_svc_uri}/#{@image_uuid}/").gsub("runweasel",
                                                                        "ks=#{api_svc_uri}/policy/callback/#{@policy_uuid}/kickstart/file")
        end

      end

      # ERB.result(binding) is failing in Ruby 1.9.2 and 1.9.3 so template is processed in the def block.
      def template_filepath(filename)
        raise ProjectRazor::Error::Slice::InternalError, "must provide esxi version." unless @osversion
        filepath = File.join(File.dirname(__FILE__), "esxi/#{@osversion}/#{filename}.erb")
      end

      def kickstart_file
        filepath = template_filepath('kickstart')
        ERB.new(File.read(filepath)).result(binding)
      end
    end
  end
end
