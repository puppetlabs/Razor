# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "erb"

# TODO - timing between state changes
# TODO - timeout values for a state

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class UbuntuOneiricMinimal < ProjectRazor::Model::Base
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
        @type = :linux_deploy
        @name = "ubuntu_oneiric_min"
        @description = "Ubuntu Oneiric 11.10 Minimal"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state = :init
        # Image UUID
        @image_uuid = true
        # Image prefix we can attach
        @image_prefix = "os"
        # Enable agent systems for this model
        @system_type = :agent
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
      end

      def req_metadata_hash
        {
            "@hostname_prefix" => {:default => "node",
                            :example => "node",
                            :validation => '^[\w]+$',
                            :required => true,
                            :description => "node hostname prefix (will append node number"},
            "@root_password" => {:default => "test123",
                            :example => "P@ssword!",
                            :validation => '^[\S]{8,}',
                            :required => true,
                            :description => "root password (> 8 characters)"},
        }
      end

      def callback
        {"preseed" => :preseed_call,
         "postinstall" => :postinstall_call,}
      end

      def system_agent_handoff
        # Ubuntu support agent-based systems that support Linux

        logger.debug "System agent called for: #{@system.name}"

        # We need to send username & password to system agent method
        # We also need to send our Node's metadata (attributes_hash).

        options = {}

        options[:username] = "root" # For this model it is root
        logger.debug "username: #{options[:username]}"
        options[:password] = @root_password
        logger.debug "password: #{options[:password]}"
        options[:metadata] = node_metadata
        options[:hostname] = hostname
        logger.debug "hostname: #{options[:hostname]}"
        unless @node_ip
          logger.error "Node IP address isn't known"
          @current_state = :system_fail
          fsm_log(:state => @current_state,
                  :old_state => :os_complete,
                  :action => :system_agent_handoff,
                  :method => :system,
                  :node_uuid => @node_bound.uuid,
                  :timestamp => Time.now.to_i)
        end
        options[:ipaddress] = @node_ip
        logger.debug "ip address: #{options[:ipaddress]}"
        @current_state = @system.agent_hand_off(options)
        fsm_log(:state => @current_state,
                :old_state => :os_complete,
                :action => :system_agent_handoff,
                :method => :system,
                :node_uuid => @node_bound.uuid,
                :timestamp => Time.now.to_i)
      end

      def preseed_call
        @node_bound = @node
        @arg = @args_array.shift
        case @arg
          when  "start"
            @result = "Acknowledged preseed read"
            fsm_action(:preseed_start, :preseed)
            return "ok"
          when "end"
            @result = "Acknowledged preseed end"
            fsm_action(:preseed_end, :preseed)
            return "ok"
          when "file"
            @result = "Replied with preseed file"
            fsm_action(:preseed_file, :preseed)
            return generate_preseed(@policy_uuid)
          else
            return "error"
        end
      end

      def postinstall_call
        @node_bound = @node
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



      def os_boot_script(policy_uuid)
        @result = "Replied with os boot script"
        os_boot = File.join(File.dirname(__FILE__), "ubuntu_oneiric_erb/os_boot.erb")
        ERB.new(File.read(os_boot)).result(binding)
      end

      def os_complete_script(node)
        @result = "Replied with os complete script"
        os_complete = File.join(File.dirname(__FILE__), "ubuntu_oneiric_erb/os_complete.erb")
        ERB.new(File.read(os_complete)).result(binding)
      end

      def nl(s)
        s + "\n"
      end

      # Defines our FSM for this model
      #  For state => {action => state, ..}
      def fsm_tree
        {
            :init => {:mk_call => :init,
                      :boot_call => :init,
                      :preseed_start => :preinstall,
                      :preseed_file => :init,
                      :preseed_end => :postinstall,
                      :timeout => :timeout_error,
                      :error => :error_catch,
                      :else => :init},
            :preinstall => {:mk_call => :preinstall,
                            :boot_call => :preinstall,
                            :preseed_start => :preinstall,
                            :preseed_file => :init,
                            :preseed_end => :postinstall,
                            :preseed_timeout => :timeout_error,
                            :error => :error_catch,
                            :else => :preinstall},
            :postinstall => {:mk_call => :postinstall,
                             :boot_call => :postinstall,
                             :preseed_end => :postinstall,
                             :source_fix => :postinstall,
                             :apt_get_update => :postinstall,
                             :apt_get_upgrade => :postinstall,
                             :apt_get_ruby => :postinstall,
                             :postinstall_inject => :postinstall,
                             :os_boot => :os_complete,
                             :post_error => :error_catch,
                             :post_timeout => :timeout_error,
                             :error => :error_catch,
                             :else => :postinstall},
            :os_complete => {:mk_call => :os_complete,
                             :boot_call => :os_complete,
                             :else => :os_complete,
                             :reset => :init},
            :timeout_error => {:mk_call => :timeout_error,
                               :boot_call => :timeout_error,
                               :else => :timeout_error,
                               :reset => :init},
            :error_catch => {:mk_call => :error_catch,
                             :boot_call => :error_catch,
                             :else => :error_catch,
                             :reset => :init},
        }
      end

      def mk_call(node, policy_uuid)
        @node_bound = node
        case @current_state
          # We need to reboot
          when :init, :preinstall, :postinstall, :os_validate, :os_complete, :system_check, :system_fail, :system_success
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
        @node_bound = node
        case @current_state
          when :init, :preinstall
            @result = "Starting Ubuntu model install"
            ret = start_install(node, policy_uuid)
          when :postinstall, :os_complete, :system_check, :system_fail, :system_success
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
        ip << "kernel #{image_svc_uri}/#{@image_uuid}/#{kernel_path} #{kernel_args(policy_uuid)}  || goto error\n"
        ip << "initrd #{image_svc_uri}/#{@image_uuid}/#{initrd_path} || goto error\n"
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

      def kernel_args(policy_uuid)
        ka = ""
        ka << "preseed/url=#{api_svc_uri}/policy/callback/#{policy_uuid}/preseed/file "
        ka << "debian-installer/locale=en_US "
        ka << "netcfg/choose_interface=auto "
        ka << "priority=critical "
        ka
      end

      def hostname
        "#{@hostname_prefix}#{@counter.to_s}"
      end

      def kernel_path
        "install/netboot/ubuntu-installer/amd64/linux"
      end

      def initrd_path
        "install/netboot/ubuntu-installer/amd64/initrd.gz"
      end

      def config
        $data.config
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/os"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end

      def generate_preseed(policy_uuid)
        preseed = File.join(File.dirname(__FILE__), "ubuntu_oneiric_erb/preseed.erb")
        ERB.new(File.read(preseed)).result(binding)
      end
    end
  end
end
